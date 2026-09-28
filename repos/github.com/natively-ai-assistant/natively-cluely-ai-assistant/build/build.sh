#!/bin/sh
# Repo-native Linux build for the ForkHub Natively channel.
# Runs with cwd = patched upstream checkout. Best-effort: always exits 0;
# the shared workflow falls back to a patched-source tarball when dist/
# stays empty. See BUILD.md.
#
# The shared builder image only guarantees bun. This target brings its own
# toolchain (node 22 to match upstream release-macos.yml, Rust stable for
# the native module, keytar system headers) because the desktop build
# compiles native addons and packs installers.
set -eu

DIST="${GITHUB_WORKSPACE:?}/dist"
REPO="${GITHUB_REPOSITORY:?}"
TAG="${UPSTREAM_TAG:?}"
LOG="$DIST/BUILD_LOG.md"

say() {
  printf '%s\n' "$*" | tee -a "$LOG"
}

fail_soft() {
  say "BUILD-SOFT-FAIL: $*"
  # Never leave an empty staging dir behind: the shared checksum step
  # (`sha256sum *`) chokes on directories and would fail the whole job.
  rm -rf "$DIST/forkhub" 2>/dev/null || true
  # Still ship something useful: the verified patched source (the shared
  # fallback only fires on an empty dist, and BUILD_LOG.md already makes
  # it non-empty).
  tar --exclude=./node_modules --exclude=./dist --exclude=./.git --exclude=./release \
    -czf "$DIST/natively-ai-assistant-natively-cluely-ai-assistant-patched-source.tar.gz" . 2>/dev/null \
    && say "patched-source tarball packed" \
    || say "source tarball packing failed; bundle will carry the build log only"
  say "Continuing so the bundle release still publishes."
  exit 0
}

# Upstream tags are stable-only in practice, but old `-beta` tags exist and a
# future `-beta`/`-rc` cut must never ship as a ForkHub release.
case "$TAG" in
  *-beta* | *-alpha* | *-rc* | *-preview* | *-pr.*)
    fail_soft "UPSTREAM_TAG=$TAG is a pre-release train tag, not a shippable stable tag; refusing to cut a ForkHub release from it."
    ;;
esac

# ForkHub provenance version: <upstream>.fh.<owner>.<n>, e.g.
# 2.8.1.fh.imbios.1. The suffix rides in from upstream.json:version_suffix
# via FORKHUB_VERSION_SUFFIX; n counts existing updater releases for this
# base so force-rebuilds advance. The `-fh.<owner>.<n>` shape is what the
# in-app updater matches on the shared catalog atom feed (prerelease
# channel `fh`) and what isRealUpgrade/isForkCounterUpgrade order in-app.
SUFFIX="${FORKHUB_VERSION_SUFFIX:-fh}"
case "$SUFFIX" in
  "" | *[!a-z0-9-]*)
    fail_soft "bad FORKHUB_VERSION_SUFFIX '$SUFFIX'"
    ;;
esac
OWNER=$(printf '%s' "$REPO" | cut -d/ -f1 | tr '[:upper:]' '[:lower:]')
VER=$(printf '%s' "$TAG" | sed 's/^v//')
ESCAPED_BASE=$(printf '%s' "$VER" | sed 's/\./\\./g')
EXISTING_TAGS=$(gh api "repos/$REPO/releases?per_page=100" --jq '.[].tag_name' 2>/dev/null) \
  || fail_soft "could not list releases to number the ForkHub build (gh api failed)"
N=$(printf '%s\n' "$EXISTING_TAGS" | grep -cE "^v${ESCAPED_BASE}[-.]${SUFFIX}\\.${OWNER}\\.[0-9]+\$" || true)
FH_VERSION="${VER}-${SUFFIX}.${OWNER}.$((N + 1))"
echo "FORKHUB_VERSION=$FH_VERSION" >> "${GITHUB_ENV:?}"
say "# ForkHub build: github.com/natively-ai-assistant/natively-cluely-ai-assistant @ $TAG (as $FH_VERSION)"

# --- toolchain: node 22 (matches upstream release-macos.yml) ---
HAVE_NODE=$(node --version 2>/dev/null | sed 's/^v//') || HAVE_NODE=""
if [ "${HAVE_NODE%%.*}" = "22" ]; then
  say "node $HAVE_NODE ok"
else
  say "node ${HAVE_NODE:-missing} unsuitable; fetching latest node 22"
  command -v curl >/dev/null 2>&1 || fail_soft "no curl to fetch node"
  command -v jq >/dev/null 2>&1 || fail_soft "no jq to resolve node version"
  NODE_TAG=$(curl -fsSL https://nodejs.org/download/release/index.json | jq -r '[.[].version | select(startswith("v22."))][0]')
  [ -n "$NODE_TAG" ] && [ "$NODE_TAG" != "null" ] || fail_soft "could not resolve latest node 22"
  NODE_DIR="${RUNNER_TEMP:-/tmp}/forkhub-node22"
  mkdir -p "$NODE_DIR"
  curl -fsSL "https://nodejs.org/download/release/$NODE_TAG/node-$NODE_TAG-linux-x64.tar.xz" \
    | tar -xJ -C "$NODE_DIR" || fail_soft "node 22 download/extract failed"
  export PATH="$NODE_DIR/node-$NODE_TAG-linux-x64/bin:$PATH"
  say "node $(node --version) provisioned"
fi

# --- toolchain: Rust stable (native-module via napi) ---
if command -v cargo >/dev/null 2>&1; then
  say "cargo $(cargo --version) ok"
else
  say "installing Rust stable via rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile minimal >>"$LOG" 2>&1 \
    || fail_soft "rustup install failed"
  export PATH="$HOME/.cargo/bin:$PATH"
  say "cargo $(cargo --version) installed"
fi

# --- toolchain: native build headers (keytar links libsecret on Linux) ---
if command -v apt-get >/dev/null 2>&1; then
  say "installing native build prerequisites"
  sudo apt-get update >>"$LOG" 2>&1 || say "apt-get update failed; continuing"
  sudo apt-get install -y build-essential python3 pkg-config libsecret-1-dev >>"$LOG" 2>&1 \
    || say "prerequisite install failed; the build will say if it mattered"
fi

# --- deps (lockfile-pinned). postinstall rebuilds sharp/native addons,
# verifies vendored models, and checks the native arch — same as local dev.
#
# onnxruntime-node is dev-only (electron-builder `files` excludes it from
# the packaged app), and its postinstall downloads a GPU NuGet package
# whose contents are broken for linux (it hunts a win-x64 CUDA lib and
# throws). Skip its native download; CPU inference is unaffected and the
# shipped app never contains it.
export ONNXRUNTIME_NODE_INSTALL=skip
export ONNXRUNTIME_NODE_INSTALL_CUDA=skip
say "npm ci"
npm ci >>"$LOG" 2>&1 || fail_soft "npm ci failed (see BUILD_LOG.md)"
export PATH="$PWD/node_modules/.bin:$PATH"

# --- stamp the ForkHub provenance version (app + updater manifests) ---
say "stamping version $FH_VERSION"
npm pkg set "version=$FH_VERSION" >>"$LOG" 2>&1 || fail_soft "version stamp failed"

# --- build (mirrors package.json app:build, Linux subset) ---
say "vite build"
npm run build >>"$LOG" 2>&1 || fail_soft "vite build failed"
say "electron typecheck"
npm run typecheck:electron >>"$LOG" 2>&1 || fail_soft "electron typecheck failed"
say "electron bundle"
npm run build:electron >>"$LOG" 2>&1 || fail_soft "electron bundle failed"
say "native module"
npm run build:native >>"$LOG" 2>&1 || fail_soft "native module build failed"
say "sharp mac deps (no-op on linux)"
node scripts/ensure-sharp-mac-deps.js >>"$LOG" 2>&1 || say "ensure-sharp-mac-deps failed; continuing (linux)"

# --- pack Linux installers only (mac needs signing, win needs its own runner) ---
say "electron-builder (linux AppImage + deb)"
./node_modules/.bin/electron-builder --linux AppImage deb --publish never >>"$LOG" 2>&1 \
  || fail_soft "electron-builder failed (see BUILD_LOG.md)"

# --- collect updater-relevant artifacts ---
mkdir -p "$DIST/forkhub"
MOVED=0
for f in release/*.AppImage release/*.deb release/latest-linux.yml release/*.blockmap; do
  [ -e "$f" ] || continue
  mv "$f" "$DIST/forkhub"/
  MOVED=$((MOVED + 1))
done
[ "$MOVED" -gt 0 ] || fail_soft "electron-builder produced no artifacts in release/"
# The updater feed resolves `latest-linux.yml` on linux: it must exist and
# must carry the stamped ForkHub version, or in-app updates can never fire.
grep -q "version: $FH_VERSION" "$DIST"/forkhub/latest-linux.yml 2>/dev/null \
  || fail_soft "latest-linux.yml missing or version mismatch (expected $FH_VERSION)"
for f in "$DIST"/forkhub/*; do
  [ -e "$f" ] || continue
  mv "$f" "$DIST"/
done
rm -rf "$DIST/forkhub" 2>/dev/null || true
say "artifacts moved to dist"
ls "$DIST" | tee -a "$LOG"
