#!/bin/sh
# Repo-native build for the ForkHub OpenCode channel.
# Runs with cwd = patched upstream checkout. Best-effort: always exits 0;
# the shared workflow falls back to a patched-source tarball when dist/
# stays empty. See BUILD.md.
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
  rm -rf "$DIST/forkhub" 2>/dev/null || true
  tar --exclude=./node_modules --exclude=./dist --exclude=./.git \
    -czf "$DIST/anomalyco-opencode-patched-source.tar.gz" . 2>/dev/null \
    && say "patched-source tarball packed" \
    || say "source tarball packing failed; bundle will carry the build log only"
  say "Continuing so the bundle release still publishes."
  exit 0
}

VER=$(printf '%s' "$TAG" | sed 's/^v//')
case "$TAG" in
  v[0-9]*.[0-9]*.[0-9]*)
    case "$VER" in
      *-* | *+*) fail_soft "UPSTREAM_TAG=$TAG is not a plain release tag; refusing to cut a ForkHub release from it." ;;
    esac
    ;;
  *) fail_soft "UPSTREAM_TAG=$TAG is not a vX.Y.Z release tag; refusing to cut a ForkHub release from it." ;;
esac

say "# ForkHub build: github.com/anomalyco/opencode @ $TAG (as $VER, prod base)"

command -v bun >/dev/null 2>&1 || fail_soft "bun not on PATH (shared builder guarantees it)"
say "bun $(bun --version) ok"

say "installing workspace deps"
bun install >>"$LOG" 2>&1 || fail_soft "bun install failed"

mkdir -p "$DIST/forkhub"

say "building CLI first (prod desktop bundles it via OPENCODE_CLI_DIST)"
(cd packages/cli && bun run build >>"$LOG" 2>&1) \
  && say "cli build ok" \
  || fail_soft "cli build failed"
export OPENCODE_CLI_DIST="$PWD/packages/cli/dist"

say "building desktop AppImage (forkhub variant)"
(cd packages/desktop && \
  OPENCODE_VERSION="$VER" OPENCODE_CHANNEL=prod OPENCODE_FORKHUB_BUILD=1 FORKHUB_OWNER=imbios \
  OPENCODE_DESKTOP_UPDATE_REPOSITORY="$REPO" bun ./scripts/prepare.ts >>"$LOG" 2>&1) \
  || fail_soft "desktop prepare failed"
(cd packages/desktop && \
  OPENCODE_VERSION="$VER" OPENCODE_CHANNEL=prod OPENCODE_FORKHUB_BUILD=1 FORKHUB_OWNER=imbios \
  NODE_OPTIONS=--max-old-space-size=4096 bun run build >>"$LOG" 2>&1) \
  || fail_soft "desktop build failed"
(cd packages/desktop && \
  OPENCODE_CHANNEL=prod OPENCODE_FORKHUB_BUILD=1 FORKHUB_OWNER=imbios \
  OPENCODE_DESKTOP_UPDATE_REPOSITORY="$REPO" \
  npx electron-builder --linux AppImage --publish never --config electron-builder.config.ts >>"$LOG" 2>&1) \
  || fail_soft "electron-builder packaging failed"

say "collecting updater artifacts"
FOUND=""
for f in packages/desktop/dist/*.AppImage packages/desktop/dist/latest-*.yml packages/desktop/dist/*.blockmap; do
  [ -e "$f" ] || continue
  cp "$f" "$DIST/" && FOUND="$FOUND $(basename "$f")"
done
[ -n "$FOUND" ] || fail_soft "no AppImage/latest-*.yml artifacts produced"
say "updater artifacts:$FOUND"

say "staging ForkHub CLI npm package"
if [ -f packages/cli/package.json ]; then
  rm -rf "$DIST/forkhub/cli-pkg" && mkdir -p "$DIST/forkhub/cli-pkg"
  cp -r packages/cli/dist "$DIST/forkhub/cli-pkg/dist" 2>/dev/null || true
  cp packages/cli/package.json "$DIST/forkhub/cli-pkg/package.json"
  (cd "$DIST/forkhub/cli-pkg" && node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.name = '@imbios/with-fh-opencode-ai';
delete pkg.private;
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
") >>"$LOG" 2>&1 || say "cli package rename failed; continuing"
  if [ -n "${NPM_TOKEN:-}" ]; then
    say "publishing @imbios/with-fh-opencode-ai@latest to npm"
    (cd "$DIST/forkhub/cli-pkg" && \
      NPM_CONFIG_PROVENANCE=false npm publish --tag latest >>"$LOG" 2>&1) \
      && say "npm publish ok" \
      || say "npm publish failed; staging tarball instead"
  else
    say "NPM_TOKEN absent; skipping npm publish (tarball fallback)"
  fi
  (cd "$DIST/forkhub/cli-pkg" && npm pack >>"$LOG" 2>&1) || say "npm pack failed"
  cp "$DIST"/forkhub/cli-pkg/*.tgz "$DIST/" 2>/dev/null || true
fi

say "ForkHub build done"
