#!/bin/sh
# Repo-native build for github.com/Dokploy/cli.
# Runs with CWD = clean upstream checkout AFTER the intent stack was applied
# and every verify.sh passed. Place artifacts in ../dist/.
# Agent: replace the body with the upstream's own build. Examples:
#   bun build --compile --target=bun-linux-x64 --outfile=../dist/app ./src/main.ts
#   npm pack --pack-destination ../dist
#   docker build -t "app:$(cat ../upstream_tag.txt)" .
# Until then this is a deliberate no-op (exit 0, empty dist/) and CI falls
# back to shipping the verified patched source as a tarball.
set -eu
mkdir -p ../dist
echo "(build.sh placeholder for github.com/Dokploy/cli — fill in the repo-native build)" >&2
