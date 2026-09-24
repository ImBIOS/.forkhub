---
id: opencode-forkhub-update-track-ddcd8fe1
title: OpenCode "ForkHub" update track with per-owner channel, x ForkHub brand, and ForkHub CLI package
target_repo: github.com/anomalyco/opencode
target_area: [packages/desktop/src/main/updater/forkhub.ts, packages/desktop/src/main/updater/index.ts, packages/desktop/src/main/updater/live.ts, packages/desktop/src/main/updater/platform.ts, packages/desktop/src/main/updater/index.test.ts, packages/desktop/src/main/ipc-handlers/updater.ts, packages/desktop/src/main/constants.ts, packages/desktop/src/main/env.d.ts, packages/desktop/src/shared/ipc-rpc/updater.ts, packages/desktop/src/renderer/api.ts, packages/desktop/src/renderer/api-types.ts, packages/desktop/src/renderer/platform/updater.ts, packages/desktop/electron-builder.config.ts, packages/desktop/electron.vite.config.ts, packages/app/src/shell/updates/forkhub.ts, packages/app/src/shell/updates/types.ts, packages/app/src/settings/general/general.tsx, packages/app/src/shell/titlebar/titlebar.tsx, packages/app/src/runtime/i18n/en.ts]
status: applied
applied_upstream_pr: none
version: 6
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-09-24
last_realized_against_commit: 3a103fe
last_realized_against_tag: v2.0.16
verifies_with: focused suites, see verify.sh
---

## Intent

Give OpenCode desktop a third update track called **ForkHub** so patched
forks can ship their own releases without forking the updater: the user picks
"ForkHub" in Settings → General → Updates → Update track, types the GitHub
profile or org whose `.forkhub` releases form the channel, presses **Check**
to validate that account, and the app's electron-updater feed is repointed at
that account's catalog repo at runtime.

This track rides the **Beta base**: both Desktop and CLI are built with
`OPENCODE_CHANNEL=beta` from the same upstream `vX.Y.Z` tags (upstream has no
live beta branch or beta tags — the beta *build channel* is what rides here).
`allowPrerelease` stays off and the version comparison is 1:1 with upstream.
Switching tracks at the same version needs one hand-install; later ForkHub
releases then flow automatically.

## Why

Upstream only ships `latest` (stable). Anyone running a patched fork (e.g.
via forkhub intent-patches) is stuck: the stable feed serves stock builds, so
the fork either freezes or hand-installs every release. A per-owner ForkHub
track lets each `.forkhub` publisher be an update channel for their users,
validated before use, with the fork visibly badged so a patched install is
never mistaken for stock.

## Non-negotiables

1. **Default behavior unchanged.** Fresh installs default to `latest`;
   the updater still polls `channel: "latest"` with `allowPrerelease: false`.
   ForkHub code paths only run when the user selects the track. All 22
   pre-existing updater service tests pass untouched.
2. **No owner, no feed.** Selecting ForkHub without a validated owner fails
   with an error telling the user to set the profile/org first; the updater
   feed is never pointed at an empty or invalid owner. The startup path only
   repoints the feed on the ForkHub track — latest keeps its baked-in feed.
3. **Validation is releases, not just the account.** Check passes only if
   the public `{owner}/.forkhub` repo exists AND has at least one published,
   non-draft release. A bare account or an empty catalog is rejected with a
   message saying so. Private catalogs are not supported: the check is
   unauthenticated, so only discoverable public releases count.
4. **Side-by-side installs.** ForkHub builds (`OPENCODE_FORKHUB_BUILD=1`)
   use app id `ai.opencode.desktop.forkhub.<owner>.<base>` (e.g.
   `ai.opencode.desktop.forkhub.imbios.beta` via `FORKHUB_BASE=beta`) and product name
   "OpenCode x ForkHub", and the running app badges "x ForkHub" in the
   titlebar whenever the ForkHub track is active.
5. **Beta-base only.** Both Desktop and CLI build with `OPENCODE_CHANNEL=beta`. The catalog tracks `vX.Y.Z` release tags
   (`upstream.json:tag_match_pattern`); `vscode-v*` and any prerelease
   trains are ignored. `allowPrerelease` stays false on ForkHub.
6. **No repo-wide test/typecheck runs.** Verify with the focused suites in
   `verify.sh` only.

## Implementation notes

- New `packages/desktop/src/main/updater/forkhub.ts` (pure, no electron
  import so unit tests stay dependency-free): `UpdateTrack`
  (`"latest" | "forkhub"`), `normalizeForkHubOwner` (1–39 chars, GitHub
  login shape), `resolveForkHubFeedConfig` (always repo `.forkhub`),
  feed/release URL helpers.
- `packages/desktop/src/main/updater/platform.ts` (Effect): `FeedConfig`
  union (github | generic), `defaultFeed()` mirrors the baked-in generic
  `opencode.ai/update/api/...` feed per channel, `setFeedURL` /
  `resetFeed` effects; `Platform` gains both.
- `packages/desktop/src/main/updater/index.ts` (Effect service): new
  `trackStore` dependency (backed by the `opencode.updater` electron-store
  in `live.ts`); `getTrack` / `setTrack` / `setForkHubOwner`. Track
  switches reset staged state to idle and re-check; owner changes on the
  ForkHub track repoint immediately. Feed logic lives here (not in
  `platform.ts`) so `index.ts` keeps zero electron imports and its test
  suite runs without mocks.
- New RPCs `UpdaterGetTrack` / `UpdaterSetTrack` /
  `UpdaterSetForkHubOwner` (`shared/ipc-rpc/updater.ts`, Schema.Literals),
  handlers (`ipc-handlers/updater.ts`, failures via `Effect.orDie` like
  `install`), renderer bridge (`api.ts`, `api-types.ts`,
  `platform/updater.ts`).
- `packages/app/src/shell/updates/forkhub.ts` mirrors the owner helpers
  plus `checkForkHubOwner` (requires public `.forkhub` releases with at
  least one published release); `UpdaterPlatform` gains optional
  `getTrack/setTrack/setForkHubOwner`.
- Settings UI (`settings/general/general.tsx` UpdatesSection): "Update
  track" select (Latest/ForkHub) + owner `TextInput` with Check button,
  inline valid/invalid status with releases link, success toast that also
  switches the track to ForkHub. All copy behind i18n keys
  (`settings.updates.row.track.*`, `settings.updates.row.forkhubOwner.*`,
  `settings.updates.forkhub.*`, `settings.updates.toast.forkhub.*`).
- `ChannelIndicator` (`shell/titlebar/titlebar.tsx`) renders an "x
  ForkHub" badge whenever the ForkHub track is active, including on prod
  builds where the stock channel badge is hidden. The badge re-polls the
  track every 15s so it appears without an app restart after switching
  tracks in Settings.
- `electron-builder.config.ts`: `OPENCODE_FORKHUB_BUILD=1` with
  `FORKHUB_OWNER` (default `imbios`) overrides app id / product name /
  publish (`owner/.forkhub`, overridable via
  `OPENCODE_DESKTOP_UPDATE_REPOSITORY=owner/repo`).
  `electron.vite.config.ts` bakes `OPENCODE_FORKHUB_BUILD` /
  `OPENCODE_FORKHUB_APP_ID`; `src/main/constants.ts` uses them for
  `APP_NAME`/`APP_ID` so the install is side-by-side with stock.
- CLI (`opencode upgrade`) is intentionally untouched: the ForkHub CLI
  channel is the npm package `@imbios/with-fh-opencode-ai` published with
  tag `beta` from the same build (see `build/BUILD.md`).

## History

- v1 realized against the v1-era `dev` tree — superseded: its
  `reference.diff` does not apply to the v2 prod train (v2 restructured
  the desktop updater to Effect services and moved settings/titlebar).
- v2 re-derived against `v2.0.16` (`3a103fe`); `reference.diff` applies
  clean to pristine `v2.0.16` (`git apply --check`).

- v3 switches the base to beta (`OPENCODE_CHANNEL=beta`, `FORKHUB_BASE=beta`, npm tag `beta`).

- v4 makes the titlebar badge re-poll the track (15s) so it appears without restart.

- v5 re-polls the Settings track select on the same cadence.

- v6 renders the ForkHub badge on all channels (beta builds fell through to the stock badge).
