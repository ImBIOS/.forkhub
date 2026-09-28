---
id: natively-forkhub-update-track-53ac9810
title: Natively ForkHub update track (ImBIOS catalog feed) + stable hardware ID without premium submodule
target_repo: github.com/natively-ai-assistant/natively-cluely-ai-assistant
target_area: [electron/update/updateFeed.ts, electron/update/ReleaseNotesManager.ts, electron/main.ts, electron/ipcHandlers.ts, electron/preload.ts, electron/services/HardwareId.ts, src/components/UpdateBanner.tsx, src/components/onboarding/OrchestratedToasterHost.tsx, src/types/electron.d.ts, package.json]
status: draft
applied_upstream_pr: none
version: 2
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-09-27
last_realized_against_commit: 4a06f12
verifies_with: node --test (focused suites, see verify.sh)
---

## Intent

Make the ImBIOS fork of Natively buildable and self-updating through
forkhub: the app's electron-updater feed, release-notes lookup, and
manual-download links all follow the ForkHub catalog (GitHub Releases of
`ImBIOS/.forkhub`) instead of the upstream author's repo, and the free-trial
device binding works in open-source / fork builds that ship WITHOUT the
private `premium/` submodule.

## Why

Upstream hardcodes `Natively-AI-assistant/natively-cluely-ai-assistant` as
the update feed (electron-builder `publish`, `ReleaseNotesManager`,
`UpdateBanner` DMG links). A patched fork that keeps that feed is stuck:
it is either offered stock builds over its own patches, or its users
hand-install every release. Repointing the feed at the fork's own catalog
lets `fh`-built releases update in place, visibly separated from stock.

Separately, `trial:start` and `license:get-hardware-id` depended solely on
the private `premium/` submodule's `LicenseManager`. Fork builds omit that
submodule (by design — see `electron/premium/featureGate.ts`), so every
HWID lookup fell through to the literal string `'unavailable'`, which was
POSTed to `/v1/trial/start` and rejected (`invalid_hwid`) — the free trial
was unclaimable and the UI showed a raw `hardware_id_unavailable`
placeholder.

## Non-negotiables

1. **Single source of truth for the feed.** Owner/repo live in exactly one
   module (`electron/update/updateFeed.ts`), env-overridable via
   `NATIVELY_UPDATE_OWNER` / `NATIVELY_UPDATE_REPO`, defaulting to
   `ImBIOS/.forkhub`. The updater (`setFeedURL`), the builder
   (`package.json` `publish`), release notes, and renderer links all read
   from it — no second hardcoded copy.
2. **No stock/fork cross-talk.** Fork builds never poll upstream releases
   and stock builds never see fork builds. Fork app versions carry a
   `-fh.<owner>.<n>` suffix; the updater runs with `allowPrerelease = true`
   on this feed (the feed contains ONLY fork builds, so no stock
   prerelease can leak in).
3. **Fork rebuilds must pass the upgrade gate.** Upstream's `isRealUpgrade`
   strips `-.*` suffixes, so `2.8.1-fh.imbios.1` → `2.8.1-fh.imbios.2`
   compares equal and would be refused as a "non-upgrade" (same for the
   dev `isVersionNewer`). The tiebreak `isForkCounterUpgrade()` orders
   same-owner rebuild counters; stock↔fork and cross-owner pairs stay
   refused, and stock-version behavior is byte-for-byte unchanged.
3. **Shared-catalog discipline.** The per-owner `.forkhub` catalog hosts
   many targets, so there is no single `/releases/latest`: the "latest"
   lookup lists releases and filters by the Natively tag prefix
   (`natively-ai-assistant-natively-cluely-ai-assistant--`), and
   `apiReleaseUrl('latest')` throws instead of guessing. Installer releases
   in the catalog MUST carry electron-updater manifests (`latest.yml` /
   `latest-mac.yml` / `latest-linux.yml`) — plain patched-source tarballs
   are invisible to the updater.
4. **HWID never a placeholder.** `getStableHardwareId()` resolves
   native module → premium `LicenseManager` → OS machine id → persisted
   install id (all SHA-256 hex shaped, native-first so existing activated
   installs keep their bound id). It throws rather than returning
   `'unavailable'`/`'hardware_id_unavailable'`; `trial:start` maps that to
   `invalid_hwid` WITHOUT burning a rate-limit slot, and no raw error code
   ever reaches the UI (friendly copy in `App.tsx` / `NativelyApiSettings`).
5. **Manual-download fallback never 404s.** Unsigned-macOS fallback links
   the catalog's latest release page on fork feeds (asset naming is owned
   by the fork's release workflow); the direct DMG asset link is kept ONLY
   for the upstream feed where the name is predictable.
6. **No repo-wide test/typecheck runs.** Verify with the focused suites in
   `verify.sh` only.

## Implementation notes

- Realized against upstream `v2.8.1` (commit `4a06f12`) — the tag the
  shared workflow's picker selects. v1 was captured against the fork's
  `main` and did not apply upstream (trial promo had moved to
  `OrchestratedToasterHost`, `docs/RELEASE.md` is fork-only).
- New `electron/update/updateFeed.ts`: feed constants, `getUpdateFeed()`,
  `extractVersionFromTag()` (handles `<slug>--vX-fhN` catalog tags),
  `isForkCounterUpgrade()` (same-owner rebuild ordering), URL builders;
  `apiReleaseUrl('latest')` throws by design.
- `electron/main.ts` `setupAutoUpdater()`: `setFeedURL({provider:'github',
  owner, repo})`, `channel='latest'`, `allowPrerelease=true`;
  `checkForUpdatesManual()` extracts the version from catalog tags before
  comparing; `isRealUpgrade()` / `isVersionNewer()` fall through to the
  fork-counter tiebreak on numeric ties.
- `electron/update/ReleaseNotesManager.ts`: catalog-aware — `latest` via
  list+prefix-filter, exact versions via tag lookups then suffix-tolerant
  list search; `repoOwner`/`repoName` stay public readonly for compat.
- `electron/services/HardwareId.ts` (new): ordered HWID resolution, never
  a placeholder (see module docblock for the full rationale).
- `electron/ipcHandlers.ts`: `trial:start` + `license:get-hardware-id`
  use it; new `get-update-feed` handler.
- `electron/preload.ts` + `src/types/electron.d.ts`: `getUpdateFeed`
  bridge.
- `src/components/UpdateBanner.tsx`: feed-driven fallback links.
- `src/components/onboarding/OrchestratedToasterHost.tsx`: `invalid_hwid`
  → friendly copy in trial promo.
- `package.json` `build.publish`: `ImBIOS/.forkhub`.
- Linux CI lives beside the patch (`../build/build.sh`, `publish.sh`,
  `BUILD.md`, `CONSUME.md`, `triggers.md`, `../upstream.json`): AppImage +
  deb + `latest-linux.yml` to the catalog; updater-channel release
  `v<upstream>-fh.imbios.<n>` is what the app polls.
- Tests: `electron/update/updateFeed.test.mjs` (new, incl. fork-counter
  ordering), `electron/services/__tests__/HardwareId.test.mjs` (new),
  `ReleaseNotesManager.test.mjs` feed assertions updated.
