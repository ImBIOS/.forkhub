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
# build.sh exports FORKHUB_VERSION (<upstream>.fh.<owner>.<n>); fall back to
# the bare upstream version when publishing by hand.
if [ -n "${FORKHUB_VERSION:-}" ]; then
  VER="$FORKHUB_VERSION"
else
  VER=$(printf '%s' "$TAG" | sed 's/^v//')
fi

case "$VER" in
  *preview* | *pr.*)
    echo "not a shippable train tag ($VER); skipping updater publish"
    exit 0
    ;;
esac

if [ -z "$(ls "$DIST"/latest-*.yml "$DIST"/nightly-*.yml 2>/dev/null)" ]; then
  echo "no latest-*/nightly-*.yml updater manifests in dist; skipping updater publish"
  exit 0
fi

FILES=""
for f in "$DIST"/*.AppImage "$DIST"/latest-*.yml "$DIST"/nightly-*.yml "$DIST"/*.blockmap; do
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
  # shellcheck disable=SC2086
  gh release create "v$VER" $FILES --repo "$REPO" --title "T3 Code x ForkHub v$VER" --notes "ForkHub (patched) build of upstream pingdotgg/t3code $TAG. The matching pingdotgg-t3code-$TAG-fh* release carries the full bundle notes."
fi
