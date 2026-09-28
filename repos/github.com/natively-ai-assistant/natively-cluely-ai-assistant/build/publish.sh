#!/bin/sh
# Updater-channel publish hook for the ForkHub Natively channel.
# Runs in the shared workflow's publish phase with GH_TOKEN, TARGET, DIST,
# UPSTREAM_TAG and GITHUB_REPOSITORY set. Publishes dist artifacts carrying
# electron-updater manifests to the `v<version>` release in this catalog
# repo — that release is the feed the patched app polls (see
# electron/update/updateFeed.ts). The fork version `-fh.<owner>.<n>` is a
# semver prerelease whose channel (`fh`) is what the updater matches on the
# shared catalog atom feed, skipping every other target's releases.
# The shared step separately publishes the namespaced *-fhN bundle (which
# also carries the .deb).
set -eu

DIST="${DIST:?}"
REPO="${GITHUB_REPOSITORY:?}"
TAG="${UPSTREAM_TAG:?}"
# build.sh exports FORKHUB_VERSION (<upstream>-fh.<owner>.<n>); fall back to
# the bare upstream version when publishing by hand.
if [ -n "${FORKHUB_VERSION:-}" ]; then
  VER="$FORKHUB_VERSION"
else
  VER=$(printf '%s' "$TAG" | sed 's/^v//')
fi

case "$VER" in
  *-beta* | *-alpha* | *-rc* | *-preview* | *-pr.*)
    echo "not a shippable stable tag ($VER); skipping updater publish"
    exit 0
    ;;
esac

if [ -z "$(ls "$DIST"/latest-linux.yml 2>/dev/null)" ]; then
  echo "no latest-linux.yml updater manifest in dist; skipping updater publish"
  exit 0
fi

FILES=""
for f in "$DIST"/*.AppImage "$DIST"/latest-linux.yml "$DIST"/*.blockmap; do
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
  gh release create "v$VER" $FILES --repo "$REPO" --title "Natively ForkHub v$VER" --notes "ForkHub (patched) Linux build of upstream natively-ai-assistant/natively-cluely-ai-assistant $TAG. The matching natively-ai-assistant-natively-cluely-ai-assistant-$TAG-fh* release carries the full bundle notes."
fi
