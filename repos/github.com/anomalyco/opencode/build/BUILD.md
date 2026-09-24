# Build — github.com/anomalyco/opencode (ForkHub track)

Repo-native build for the ForkHub OpenCode channel. Runs on `ubuntu-latest`
after the intent stack is applied and `verify.sh` passes. Prod/latest base
only (see `upstream.json:tag_match_pattern`).

## What `build.sh` does

1. Refuses non-release tags (`vX.Y.Z` only — no `vscode-v*`, no
   prereleases). Uses `OPENCODE_VERSION=<ver>` so the build stamps the
   upstream version 1:1 (switching tracks at the same version needs one
   hand-install; later ForkHub releases then flow automatically).
2. Installs workspace deps (`bun install`, lockfile-pinned).
3. Builds the **CLI** (`packages/cli`) first and exports
   `OPENCODE_CLI_DIST` — v2 prod desktop builds bundle the locally built
   CLI (`prebuild.ts` refuses prod without it).
4. Builds the **Linux x64 AppImage, unsigned**, with:
   - `OPENCODE_CHANNEL=prod` (prod/latest base),
   - `OPENCODE_FORKHUB_BUILD=1` + `FORKHUB_OWNER=imbios` → app id
     `ai.opencode.desktop.forkhub.imbios.latest`, product name
     "OpenCode x ForkHub" (side-by-side with stock installs),
   - `OPENCODE_DESKTOP_UPDATE_REPOSITORY=$GITHUB_REPOSITORY` → the emitted
     `latest-linux.yml` points electron-updater at this catalog repo.
   - Linux target is AppImage-only (`--linux AppImage`): deb/rpm need
     `fpm` which is flaky on stock runners, and the ForkHub channel is
     AppImage-first like upstream's portable story.
4. Copies the produced artifacts (AppImage, `latest-linux.yml`, blockmap)
   plus CLI archives into `$GITHUB_WORKSPACE/dist`.
5. Tries `npm publish` of `@imbios/with-fh-opencode-ai` with tag `latest`
   when `NPM_TOKEN` is present; otherwise stages an `npm pack` tarball so
   the bundle release still carries the CLI.
6. Never fails the job: on any failure it packs a patched-source tarball
   and exits 0. Empty `dist/` falls back to the shared patched-source
   tarball; the updater release is skipped by `publish.sh` when no
   `latest-*.yml` manifests exist.

## What `publish.sh` does (updater-channel release)

Runs in the publish step with `GH_TOKEN`. If `dist/` contains
`latest-*.yml` manifests, it uploads the installer files to the
**`v<upstream-version>` release in this catalog repo** (creating it if
needed) — that release IS the electron-updater feed the ForkHub track
polls. The shared workflow step separately publishes the namespaced
`anomalyco-opencode-v<ver>-fh<N>` bundle release (human-facing, carries
`CONSUME.md`).

## Requirements / limits (v1)

- **Linux only from CI.** macOS needs Apple signing/notarization and
  Windows needs Azure Trusted Signing — both live in upstream secrets.
  macOS/Windows users build locally (same commands, `--mac`/`--win`).
- **`NPM_TOKEN` secret** (optional but wanted): an npm automation token
  with publish rights on `@imbios/with-fh-opencode-ai`. Without it the CLI
  ships only as release-asset tarballs and `npm i -g
  @imbios/with-fh-opencode-ai@latest` won't resolve until the first
  token-backed build.
- **Tag selection.** `upstream.json:tag_match_pattern` keeps the shared
  clone step on the `vX.Y.Z` prod train (upstream also tags `vscode-v*`).
  If upstream changes tagging, update the pattern.
- **Known drift risk.** `reference.diff` is verified against the base noted
  in `attempts.jsonl`. When upstream drifts, the apply step fails loudly —
  re-derive via `fh` (`drift-check` → `re-derive` → `apply`) and
  re-capture; do not hand-edit `reference.diff`.
