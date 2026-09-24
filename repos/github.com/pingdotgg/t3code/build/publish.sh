#!/bin/sh
# Updater-channel publish hook for the ForkHub T3 Code channel.
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

case "$VER" in
  *nightly* | *preview* | *pr.*)
    echo "not a release train tag ($TAG); skipping updater publish"
    exit 0
    ;;
esac

if [ -z "$(ls "$DIST"/latest-*.yml 2>/dev/null)" ]; then
  echo "no latest-*.yml updater manifests in dist; skipping updater publish"
  exit 0
fi

FILES=""
for f in "$DIST"/*.AppImage "$DIST"/*.yml "$DIST"/*.blockmap; do
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
  gh release create "v$VER" $FILES --repo "$REPO" --title "T3 Code x ForkHub v$VER" --notes "ForkHub (patched) build of upstream pingdotgg/t3code v$VER. The matching pingdotgg-t3code-v$VER-fh* release carries the full bundle notes."
fi
