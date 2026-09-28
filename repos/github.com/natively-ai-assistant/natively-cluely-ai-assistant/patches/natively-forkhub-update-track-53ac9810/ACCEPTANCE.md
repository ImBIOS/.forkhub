# Acceptance Criteria — natively-forkhub-update-track-53ac9810

## Must pass for promotion to APPLIED

1. **Feed is the catalog.** `getUpdateFeed()` returns
   `{owner:'ImBIOS', repo:'.forkhub'}` by default and honors
   `NATIVELY_UPDATE_OWNER` / `NATIVELY_UPDATE_REPO`; `package.json`
   `build.publish` points at the same repo; `setupAutoUpdater()` calls
   `setFeedURL` with it, keeps `channel='latest'`, and sets
   `allowPrerelease=true` (`updateFeed.test.mjs`).
2. **Fork rebuilds pass the gate.** `isForkCounterUpgrade` orders
   same-owner `-fh.<owner>.<n>` counters and refuses stock↔fork and
   cross-owner pairs; `isRealUpgrade` / `isVersionNewer` fall through to
   it on numeric ties, with stock-version behavior unchanged
   (`updateFeed.test.mjs`).
2. **Catalog version handling.** `extractVersionFromTag` handles plain
   (`v2.8.1`), suffixed (`2.8.1-fh.imbios.1`), and namespaced
   (`<slug>--v2.8.1-fh1`) tags; `apiReleaseUrl('latest')` throws;
   `ReleaseNotesManager` resolves `latest` via list+prefix-filter and exact
   versions via tag lookups with suffix-tolerant fallback
   (`updateFeed.test.mjs`, existing parser test still green).
3. **No placeholder HWID.** `getStableHardwareId()` returns stable 64-hex,
   never `''`/`'unavailable'`/`'hardware_id_unavailable'`/`'unknown*'` on a
   submodule-less checkout; `trial:start` returns `invalid_hwid` without
   POSTing when no stable id exists; `license:get-hardware-id` falls back
   gracefully (`HardwareId.test.mjs`).
4. **No raw codes in UI.** Starting a trial with an unreadable device id
   shows "Could not read device ID. Restart the app and try again." (both
   launcher promo and API settings paths), never a raw code.
5. **Fallback links never 404.** Unsigned-macOS manual path opens the
   catalog latest-release page on fork feeds; upstream feed keeps the
   direct DMG asset link.
6. **Linux builds in CI.** `build/build.sh` produces AppImage + deb +
   `latest-linux.yml` (version-stamped, soft-fail to source tarball);
   `build/publish.sh` publishes the updater-channel release the app polls.
   Verified by the `forkhub build` run carrying Linux artifacts.
7. **Focused suites pass**: `verify.sh` exits 0. No repo-wide checks.

## How to verify

```bash
sh repos/github.com/natively-ai-assistant/natively-cluely-ai-assistant/patches/natively-forkhub-update-track-53ac9810/verify.sh
```

(run from the `ImBIOS/.forkhub` checkout; `TARGET_CHECKOUT` env can point
at the Natively fork checkout, default `../../natively-cluely-ai-assistant`
— i.e. a sibling of the `.forkhub` checkout — or an absolute path)
