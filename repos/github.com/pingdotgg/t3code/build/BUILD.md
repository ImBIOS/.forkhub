# Build — github.com/pingdotgg/t3code (ForkHub track, stable + nightly)

Repo-native build for the ForkHub T3 Code channel. Runs on `ubuntu-latest`
after the intent stack is applied and `verify.sh` passes. This catalog
follows upstream **stable and nightly** (`upstream.json:trains`); each
build carries its train's upstream version plus provenance (e.g.
`0.0.42.fh.imbios.1`, `0.0.43-nightly.20260924.2187.fh.imbios.1`). The app's
ForkHub track installs both trains, so one channel serves cautious and
bleeding-edge users alike.

## What `build.sh` does

1. Bootstraps its own toolchain (the shared builder only has bun):
   latest node 24 (if the runner's node fails `^24.13.1`), pnpm 11 via
   npm, and `libsecret-1-dev pkg-config build-essential imagemagick`
   via apt — mirroring upstream `release.yml` plus the AppImage
   prerequisites (`docs/operations/development.md#linux-appimage-prerequisites`).
2. Installs workspace deps (`pnpm install --ignore-scripts`).
3. Builds the **Linux x64 AppImage, unsigned**, with:
   - `T3CODE_FORKHUB_BUILD=1` → product name "T3 Code x ForkHub"
     (side-by-side with stock installs),
   - `T3CODE_DESKTOP_UPDATE_REPOSITORY=$GITHUB_REPOSITORY` → the emitted
     `latest-linux.yml` points electron-updater at this catalog repo.
3. Copies the produced artifacts (AppImage, `latest-linux.yml`, blockmap)
   plus `BUILD_LOG.md` into `$GITHUB_WORKSPACE/dist`.
4. Never fails the job: on any failure it packs a patched-source
   tarball (patched tree minus `node_modules`/`dist`/`.git`), logs, and
   exits 0. Empty `dist/` falls back to the shared patched-source
   tarball; either way the updater release is skipped by `publish.sh`
   when no `latest-*.yml` manifests exist.

## What `publish.sh` does (updater-channel release)

Runs in the publish step with `GH_TOKEN`. If `dist/` contains
`latest-*.yml` manifests, it uploads the installer files to the
**`v<upstream-version>` release in this catalog repo** (creating it if
needed) — that release IS the electron-updater feed the ForkHub track
polls. The shared workflow step separately publishes the namespaced
`pingdotgg-t3code-v<ver>-fh<N>` bundle release (human-facing, carries
`CONSUME.md`).

Versions are `<upstream>.fh.<owner>.<n>` (suffix from
`upstream.json:version_suffix`, owner from the catalog repo, `n` counting
existing updater releases so force-rebuilds advance). The prerelease
extension keeps train ordering (nightly dates still compare) while
advertising the fork — and it reads as an upgrade over the same-base
upstream build, so switching tracks offers the ForkHub build.
Nightly-based ForkHub builds install on the ForkHub track because the app
allows prereleases there (`allowPrerelease`, like the nightly track);
stock tracks refuse suffixed builds outright.

electron-builder names updater manifests after the version's channel, so a
nightly build emits `nightly-*.yml` only — but the ForkHub track polls the
`latest` manifests. `build.sh` therefore aliases whichever train was built
under the other manifest name (content is channel-agnostic). Both names
upload to the updater release; `publish.sh` requires at least one of them
before creating it. ForkHub builds always wear production icons
(`T3CODE_FORKHUB_BUILD=1`), never upstream nightly's, whatever the train.

## Requirements / limits (v1)

- **Linux only from CI.** macOS needs Apple signing/notarization and
  Windows needs Azure Trusted Signing — both live in upstream secrets.
  macOS/Windows users build locally (same commands, `--platform mac|win`).
- **CLI (`t3 update`) untouched by the patch.** A ForkHub CLI channel works
  when the catalog repo publishes standard `v<version>` tags carrying
  `t3-<version>-<platformKey>.tar.gz` + `SHA256SUMS` (see
  `packages/shared/src/cliRelease.ts` for keys) and users set
  `T3CODE_RELEASE_BASE_URL=https://github.com/<owner>/.forkhub/releases/download`.
  Wiring the CLI archive matrix into `build.sh` is a follow-up.
- **Tag selection.** `upstream.json:tag_ignore_pattern` keeps the shared
  clone step on the stable train (upstream tags are mostly `-preview`
  maintainer cuts). If upstream changes tagging, update the pattern.
- **Known drift risk.** `reference.diff` is verified against the latest
  stable tag at capture time. When upstream drifts, the apply step fails
  loudly — re-derive via `fh` (`drift-check` → `re-derive` → `apply`) and
  re-capture; do not hand-edit `reference.diff`.
