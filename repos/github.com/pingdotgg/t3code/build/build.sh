#!/bin/sh
# Repo-native build for the ForkHub T3 Code channel.
# Runs with cwd = patched upstream checkout. Best-effort: always exits 0;
# the shared workflow falls back to a patched-source tarball when dist/
# stays empty. See BUILD.md.
#
# The shared builder image only guarantees bun. This target brings its own
# toolchain (node ^24.13.1, pnpm 11, libsecret headers — same as upstream
# release.yml) because the desktop artifact build shells out to `vp` and
# packs native modules.
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
  tar --exclude=./node_modules --exclude=./dist --exclude=./.git \
    -czf "$DIST/pingdotgg-t3code-patched-source.tar.gz" . 2>/dev/null \
    && say "patched-source tarball packed" \
    || say "source tarball packing failed; bundle will carry the build log only"
  say "Continuing so the bundle release still publishes."
  exit 0
}

VER=$(printf '%s' "$TAG" | sed 's/^v//')
case "$VER" in
  *preview* | *pr.*)
    fail_soft "UPSTREAM_TAG=$TAG is a preview/PR train tag, not a shippable train; refusing to cut a ForkHub release from it."
    ;;
esac

# ForkHub provenance version: <upstream>.<suffix>.<owner>.<n>, e.g.
# 0.0.43-nightly.20260924.2187.fh.imbios.1. The prerelease extension keeps
# train ordering (nightly dates still compare) while advertising the fork;
# stock tracks refuse suffixed builds outright (see
# isVersionAllowedOnUpdateChannel). n counts existing updater releases for
# this base so force-rebuilds advance. The suffix rides in from
# upstream.json:version_suffix via FORKHUB_VERSION_SUFFIX.
SUFFIX="${FORKHUB_VERSION_SUFFIX:-fh}"
case "$SUFFIX" in
  "" | *[!a-z0-9-]*)
    fail_soft "bad FORKHUB_VERSION_SUFFIX '$SUFFIX'"
    ;;
esac
OWNER=$(printf '%s' "$REPO" | cut -d/ -f1 | tr '[:upper:]' '[:lower:]')
# Joiner keeps the version valid semver: a base that already has a
# prerelease part (nightly) extends it with a dot, a bare base (stable)
# needs the dash — electron-builder mangles invalid versions
# (0.0.42.fh.imbios.1 once shipped as 0.0.4-2.fh.imbios.1).
case "$VER" in
  *-*) JOINER="." ;;
  *) JOINER="-" ;;
esac
ESCAPED_BASE=$(printf '%s' "$VER" | sed 's/\./\\./g')
EXISTING_TAGS=$(gh api "repos/$REPO/releases?per_page=100" --jq '.[].tag_name' 2>/dev/null) \
  || fail_soft "could not list releases to number the ForkHub build (gh api failed)"
N=$(printf '%s\n' "$EXISTING_TAGS" | grep -cE "^v${ESCAPED_BASE}[-.]${SUFFIX}\\.${OWNER}\\.[0-9]+\$" || true)
FH_VERSION="${VER}${JOINER}${SUFFIX}.${OWNER}.$((N + 1))"
echo "FORKHUB_VERSION=$FH_VERSION" >> "${GITHUB_ENV:?}"
say "# ForkHub build: github.com/pingdotgg/t3code @ $TAG (as $FH_VERSION)"

# --- toolchain: node ^24.13.1 ---
HAVE_NODE=$(node --version 2>/dev/null | sed 's/^v//') || HAVE_NODE=""
if [ "${HAVE_NODE%%.*}" = "24" ] \
  && printf '%s\n%s\n' "24.13.1" "$HAVE_NODE" | sort -V -C 2>/dev/null; then
  say "node $HAVE_NODE ok"
else
  say "node ${HAVE_NODE:-missing} unsuitable; fetching latest node 24"
  command -v curl >/dev/null 2>&1 || fail_soft "no curl to fetch node"
  command -v jq >/dev/null 2>&1 || fail_soft "no jq to resolve node version"
  NODE_TAG=$(curl -fsSL https://nodejs.org/download/release/index.json | jq -r '[.[].version | select(startswith("v24."))][0]')
  [ -n "$NODE_TAG" ] && [ "$NODE_TAG" != "null" ] || fail_soft "could not resolve latest node 24"
  NODE_DIR="${RUNNER_TEMP:-/tmp}/forkhub-node24"
  mkdir -p "$NODE_DIR"
  curl -fsSL "https://nodejs.org/download/release/$NODE_TAG/node-$NODE_TAG-linux-x64.tar.xz" \
    | tar -xJ -C "$NODE_DIR" || fail_soft "node 24 download/extract failed"
  export PATH="$NODE_DIR/node-$NODE_TAG-linux-x64/bin:$PATH"
  say "node $(node --version) provisioned"
fi

# --- toolchain: pnpm 11 ---
if pnpm --version 2>/dev/null | grep -q '^11\.'; then
  say "pnpm $(pnpm --version) ok"
else
  say "installing pnpm 11"
  npm install -g pnpm@11.10.0 --no-fund --no-audit >>"$LOG" 2>&1 \
    || fail_soft "pnpm 11 install failed"
  say "pnpm $(pnpm --version) installed"
fi

# --- toolchain: native build headers (same as upstream release.yml) ---
if command -v apt-get >/dev/null 2>&1; then
  say "installing native build prerequisites"
  sudo apt-get update >>"$LOG" 2>&1 || say "apt-get update failed; continuing"
  sudo apt-get install -y libsecret-1-dev pkg-config build-essential imagemagick >>"$LOG" 2>&1 \
    || say "prerequisite install failed; the artifact build will say if it mattered"
fi

# --- deps (lockfile-pinned; skip lifecycle scripts like local dev does) ---
test -x node_modules/.bin/vp || pnpm install --ignore-scripts >>"$LOG" 2>&1 \
  || fail_soft "pnpm install failed"
# The artifact script shells out to `vp` and electron-builder.
export PATH="$PWD/node_modules/.bin:$PATH"
command -v vp >/dev/null 2>&1 || fail_soft "vp not found after install"

# --- stamp workspace versions (same as upstream release-desktop.yml) ---
# The web client's displayed version is baked from apps/web/package.json at
# vite build time, and upstream only bumps those files on stable releases —
# without this, a nightly build reports the last stable version everywhere.
node scripts/update-release-package-versions.ts "$FH_VERSION" >>"$LOG" 2>&1 \
  || fail_soft "package version stamping failed"

export T3CODE_FORKHUB_BUILD=1
export T3CODE_DESKTOP_UPDATE_REPOSITORY="$REPO"
say "product=T3 Code x ForkHub update_repo=$REPO"

mkdir -p "$DIST/forkhub"
if node scripts/build-desktop-artifact.ts --platform linux --target AppImage --arch x64 --build-version "$FH_VERSION" --output-dir "$DIST/forkhub" --verbose >>"$LOG" 2>&1; then
  say "artifact build ok"
else
  say "--- tail of failed artifact build ---"
  tail -n 60 "$LOG" || true
  fail_soft "build-desktop-artifact.ts failed (see BUILD_LOG.md in the bundle release)"
fi

MOVED=0
for f in "$DIST"/forkhub/*; do
  [ -e "$f" ] || continue
  mv "$f" "$DIST"/
  MOVED=$((MOVED + 1))
done
rm -rf "$DIST/forkhub" 2>/dev/null || true
[ "$MOVED" -gt 0 ] || fail_soft "artifact script produced no files"

# --- t3 CLI archive (linux-x64) ---
# Pinned installs (`t3 update`) fetch `t3-<version>-<platform>.tar.gz` plus
# SHA256SUMS from under the release tag, so shipping the archive keeps the
# standalone CLI (and T3 Connect hosts set up through it) version-pinned to
# the desktop. Other platforms need native runners (see BUILD.md), and a CLI
# failure must never fail the desktop build, so this is warn-and-continue.
build_cli_archive() {
  RMDIR="${RUNNER_TEMP:-/tmp}/cli-resource-monitor"
  mkdir -p "$RMDIR/linux-x64" "$DIST/cli-build"
  # Upstream builds with --target (triple-prefixed dir); a plain cargo build
  # lands in target/release instead. Accept either.
  RM_TRIPLE="native/resource-monitor/target/x86_64-unknown-linux-gnu/release/t3-resource-monitor"
  RM_PLAIN="native/resource-monitor/target/release/t3-resource-monitor"
  if [ ! -x "$RM_TRIPLE" ]; then
    (rustup target add x86_64-unknown-linux-gnu >>"$LOG" 2>&1 || true)
    (cargo build --locked --release --target x86_64-unknown-linux-gnu \
      --manifest-path native/resource-monitor/Cargo.toml >>"$LOG" 2>&1) || true
  fi
  if [ -x "$RM_TRIPLE" ]; then
    RM_BIN="$RM_TRIPLE"
  elif [ -x "$RM_PLAIN" ]; then
    RM_BIN="$RM_PLAIN"
  else
    (cargo build --locked --release --manifest-path native/resource-monitor/Cargo.toml >>"$LOG" 2>&1) || return 1
    RM_BIN="$RM_PLAIN"
    [ -x "$RM_BIN" ] || return 1
  fi
  cp "$RM_BIN" "$RMDIR/linux-x64/t3-resource-monitor" || return 1
  # The single-executable injects into its own Node, so it must run under
  # Node 25.7+ even though the repo stays on engines node 24 (same split as
  # upstream, whose setup-vp action provisions it; here we fetch the exact
  # build upstream pins).
  NODE26_DIR="${RUNNER_TEMP:-/tmp}/forkhub-node26"
  if [ ! -x "$NODE26_DIR/node-v26.8.2-linux-x64/bin/node" ]; then
    mkdir -p "$NODE26_DIR"
    curl -fsSL "https://nodejs.org/download/release/v26.8.2/node-v26.8.2-linux-x64.tar.xz" \
      | tar -xJ -C "$NODE26_DIR" >>"$LOG" 2>&1 || return 1
  fi
  OLD_PATH="$PATH"
  export PATH="$NODE26_DIR/node-v26.8.2-linux-x64/bin:$PATH"
  # VP_NODE_VERSION mirrors upstream (their setup-vp honors it); the PATH
  # above is what actually switches the runtime here.
  VP_NODE_VERSION="26.8.2" node apps/server/scripts/cli.ts build-exe --target linux-x64 --verbose >>"$LOG" 2>&1 || {
    export PATH="$OLD_PATH"
    return 1
  }
  export PATH="$OLD_PATH"
  node scripts/build-cli-archive.ts --platform linux --arch x64 --version "$FH_VERSION" \
    --resource-monitor-dir "$RMDIR" --output-dir "$DIST/cli-build" >>"$LOG" 2>&1 || return 1
  node scripts/smoke-cli-archive.ts --archive "$DIST"/cli-build/* --expect-version "$FH_VERSION" >>"$LOG" 2>&1 || return 1
  mv "$DIST"/cli-build/* "$DIST"/ || return 1
  rm -rf "$DIST/cli-build" 2>/dev/null || true
  # npm-installable tarball (@imbios/fh-t3, bin t3) so the CLI runs via
  # `pnpx <release-asset-URL>` or `fh run` with no registry involved. Same
  # tree as the archive, repacked with a package.json; the binary keeps its
  # `t3` name (fh run execs from cache and pnpx one-shots are ephemeral, so
  # nothing collides with a stable `t3` on PATH).
  PKGROOT="$(mktemp -d)"
  PKGDIR="$PKGROOT/package"
  mkdir -p "$PKGDIR"
  tar -xzf "$DIST"/t3-*.tar.gz -C "$PKGDIR" --strip-components=1 || { rm -rf "$PKGROOT"; return 1; }
  node -e "process.stdout.write(JSON.stringify({name:'@imbios/fh-t3',version:'$FH_VERSION',description:'T3 Code x ForkHub CLI',bin:{'t3':'./t3'}},null,2))" > "$PKGDIR/package.json" || { rm -rf "$PKGROOT"; return 1; }
  tar -czf "$DIST/imbios-fh-t3-$FH_VERSION.tgz" -C "$PKGROOT" package || { rm -rf "$PKGROOT"; return 1; }
  rm -rf "$PKGROOT"
  tar -tzf "$DIST/imbios-fh-t3-$FH_VERSION.tgz" | grep -qx 'package/package.json' || return 1
  return 0
}
if build_cli_archive; then
  say "t3 CLI archive ok: $(ls "$DIST"/t3-*.tar.gz 2>/dev/null)"
else
  # Never leave the staging dir behind: the shared checksum step chokes on
  # directories (same class of bug as dist/forkhub before it).
  rm -rf "$DIST/cli-build" 2>/dev/null || true
  say "BUILD-SOFT-WARN: t3 CLI archive failed (see log above); desktop artifacts unaffected"
fi
# electron-builder names updater manifests after the version's channel
# (latest-*.yml for stable, nightly-*.yml for nightly). The ForkHub track
# always polls the `latest` manifests, so alias whichever train was built
# under the other name. Manifest content is channel-agnostic
# (version/files/sha512), only the filename selects the feed.
for f in "$DIST"/nightly-*.yml; do
  [ -e "$f" ] || continue
  base=${f##*/}
  alias="$DIST/latest-${base#nightly-}"
  [ -e "$alias" ] || cp "$f" "$alias"
done
for f in "$DIST"/latest-*.yml; do
  [ -e "$f" ] || continue
  base=${f##*/}
  alias="$DIST/nightly-${base#latest-}"
  [ -e "$alias" ] || cp "$f" "$alias"
done
rm -rf "$DIST/forkhub" 2>/dev/null || true
say "artifacts moved to dist: $MOVED file(s)"
ls "$DIST" | tee -a "$LOG"
