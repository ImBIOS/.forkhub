#!/bin/sh
# Updater-channel publish hook for the ForkHub OpenCode channel.
# Runs in the shared workflow's publish phase with GH_TOKEN, TARGET, DIST,
# UPSTREAM_TAG and GITHUB_REPOSITORY set. Publishes dist artifacts carrying
# electron-updater manifests to the `v<version>` release in this catalog
# repo — that release is the feed the desktop ForkHub track polls.
# The shared step separately publishes the namespaced *-fhN bundle.
set -eu

DIST="${DIST:?}"
REPO="${GITHUB_REPOSITORY:?}"
TAG="${UPSTREAM_TAG:?}"
VER=$(printf '%s' "$TAG" | sed 's/^v//')

case "$TAG" in
  v[0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "not a release train tag ($TAG); skipping updater publish"; exit 0 ;;
esac
case "$VER" in
  *-* | *+*) echo "not a plain release tag ($TAG); skipping updater publish"; exit 0 ;;
esac

if [ -z "$(ls "$DIST"/latest-*.yml 2>/dev/null)" ]; then
  echo "no latest-*.yml updater manifests in dist; skipping updater publish"
  exit 0
fi

FILES=""
for f in "$DIST"/*.AppImage "$DIST"/latest-*.yml "$DIST"/*.blockmap "$DIST"/*.tgz; do
  [ -e "$f" ] || continue
  FILES="$FILES $f"
done
[ -n "$FILES" ] || { echo "no uploadable updater files; skipping"; exit 0; }

if gh release view "v$VER" --repo "$REPO" >/dev/null 2>&1; then
  echo "updating updater release v$VER"
  # shellcheck disable=SC2086
  gh release upload "v$VER" $FILES --repo "$REPO" --clobber
else
  echo "creating updater release v$VER"
  # shellcheck disable=SC2086
  gh release create "v$VER" $FILES --repo "$REPO" --title "OpenCode x ForkHub v$VER" --notes "ForkHub (patched) build of upstream anomalyco/opencode v$VER on the prod/latest base. Desktop AppImage + latest-linux.yml form the electron-updater feed; the matching anomalyco-opencode-v$VER-fh* release carries the full bundle notes. CLI: @imbios/with-fh-opencode-ai@latest."
fi
