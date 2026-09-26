---
id: t3code-forkhub-update-track-bb0ed06f
title: T3 Code "ForkHub" update track with per-owner channel, x ForkHub brand, and update-all nudge
target_repo: github.com/pingdotgg/t3code
target_area: [packages/contracts/src/ipc.ts, apps/desktop/src/updates/updateChannels.ts, apps/desktop/src/updates/updateMachine.ts, apps/desktop/src/updates/DesktopUpdates.ts, apps/desktop/src/updates/releaseNotes.ts, apps/desktop/src/settings/DesktopAppSettings.ts, apps/desktop/src/ipc/channels.ts, apps/desktop/src/ipc/methods/updates.ts, apps/desktop/src/ipc/DesktopIpcHandlers.ts, apps/desktop/src/preload.ts, apps/web/src/components/forkHub.logic.ts, apps/web/src/components/settings/SettingsPanels.tsx, apps/web/src/components/sidebar/SidebarChrome.tsx, apps/web/src/components/desktopUpdate.logic.ts, apps/web/src/components/desktopUpdate.toast.tsx, apps/mobile/src/components/BrandMark.tsx, scripts/build-desktop-artifact.ts]
status: applied
applied_upstream_pr: none
version: 5
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-09-24
last_realized_against_commit: 78af372
verifies_with: node_modules/.bin/vp test run (focused suites, see verify.sh)
---

## Intent

Give T3 Code desktop a third update track called **ForkHub** so patched
forks can ship their own releases without forking the updater: the user picks
"ForkHub" in Settings → Version → Update track, types the GitHub profile or
org whose `.forkhub` releases form the channel, presses **Check** to validate
that account, and the app's electron-updater feed is repointed at that
account's catalog repo at runtime.

## Why

Upstream only ships `latest` (stable) and `nightly`. Anyone running a patched
fork (e.g. via forkhub intent-patches) is stuck: stable/nightly feeds serve
stock builds, so the fork either freezes or hand-installs every release.
A per-owner ForkHub track lets each `.forkhub` publisher be an update channel
for their users, validated before use, with the fork visibly badged so a
patched install is never mistaken for stock.

## Non-negotiables

1. **Default behavior unchanged.** Fresh installs default to `latest`;
   nightly train semantics (prerelease filtering, release-note grouping) are
   byte-for-byte the old behavior. ForkHub code paths only run when the user
   selects the track.
2. **No owner, no feed.** Selecting ForkHub without a validated owner fails
   with `DesktopForkHubOwnerMissingError` ("Set a ForkHub profile or org
   before switching to the ForkHub track."); the updater feed is never
   pointed at an empty or invalid owner. The Check button is the happy
   path: it persists the owner and switches the track in one go.
3. **Validation is releases, not just the account.** Check passes only if
   the public `{owner}/.forkhub` repo exists AND has at least one published,
   non-draft release. A bare account or an empty catalog is rejected with a
   message saying so. Private catalogs are not supported: the check is
   unauthenticated, so only discoverable public releases count.
4. **Side-by-side installs.** ForkHub builds (`T3CODE_FORKHUB_BUILD=1`) are
   named "T3 Code x ForkHub" and the running app badges "x ForkHub" in the
   top-left brand whenever the ForkHub track is active — web sidebar and
   mobile brand mark.
5. **Servers follow the desktop.** After a desktop update downloads and
   before it installs, the UI reminds the user to bring connected T3 Code
   servers to the same version with Update all.
6. **No repo-wide test/typecheck runs.** Verify with the focused suites in
   `verify.sh` only.

## Implementation notes

- `DesktopUpdateChannel` gains `"forkhub"` (contract schema + TS union).
  Update state carries `forkhubOwner` / `forkhubRepo` (null when unset);
  the repo is always `.forkhub`.
- Owner normalization (`normalizeForkHubOwner`, 1–39 chars, GitHub login
  shape) lives in `apps/desktop/src/updates/updateChannels.ts` (main) and is
  mirrored in `apps/web/src/components/forkHub.logic.ts` (renderer); the
  renderer also owns `checkForkHubOwner`, which requires public `.forkhub`
  releases with at least one published release.
- Feed switch is runtime `setFeedURL({provider: "github", owner, repo})`
  plus `channel: "latest"` with prerelease, downgrade, and full-changelog
  enabled (a ForkHub catalog may follow the nightly train, and prerelease
  versions need the flags to install). Switching the owner while on the
  track repoints immediately and drops any staged download from the old feed.
- `isVersionAllowedOnUpdateChannel` keeps nightly on the nightly train and
  stable on release builds; ForkHub allows both stable and nightly-based
  builds and blocks only preview cuts (which ship without a feed).
  Release-note grouping uses the same test, and the release-notes popover
  covers ForkHub like nightly.
- `build.sh` aliases updater manifests across both channel names
  (`latest-*.yml` ↔ `nightly-*.yml`, content is channel-agnostic) because
  the ForkHub track polls `latest` while nightly builds emit `nightly`.
  ForkHub builds always wear production icons, never upstream nightly's.
- New `desktop:update-set-forkhub-owner` IPC (channels, method, handler,
  preload, `DesktopBridge.setForkHubOwner`).
- Settings UI: "ForkHub" select item + owner `Input` with Check button,
  inline valid/invalid status, releases link, success toast that also
  switches the track to ForkHub.
- Release links (toast, notes) resolve to the channel owner's repo on the
  ForkHub track, upstream otherwise.
- `resolveGitHubPublishConfig` accepts `"forkhub"` (release-type publish);
  `resolveDesktopProductName` returns "T3 Code x ForkHub" under
  `T3CODE_FORKHUB_BUILD=1` so CI builds (`build/build.sh`) brand correctly.
- Built versions are `<upstream>.fh.<owner>.<n>` (see `build/BUILD.md`):
  the app's channel patterns treat suffixed nightlies as nightly for
  manifests/icons/defaults, while `isVersionAllowedOnUpdateChannel`
  installs suffixed builds only on ForkHub — stock tracks never touch them.
  The running app brands itself from the same suffix
  (`resolveDesktopAppBranding` → "T3 Code x ForkHub" display name), so no
  build-time flag can get lost between CI and the user's machine.
- CLI (`t3 update`) is intentionally untouched: custom CLI origins already
  work via `T3CODE_RELEASE_BASE_URL`; a ForkHub CLI channel needs standard
  `v<version>` tags with CLI archives in the catalog repo (see `build/BUILD.md`).
