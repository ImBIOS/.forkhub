# Acceptance Criteria — t3code-forkhub-update-track-bb0ed06f

## Must pass for promotion to APPLIED

1. **Default behavior unchanged**: a fresh install reports channel `latest`
   with null ForkHub owner/repo; nightly versions still resolve to the
   nightly channel and nightly release-note grouping still drops preview
   cuts (`releaseNotes.test.ts`, `updateChannels.test.ts`).
2. **ForkHub track works**: setting a validated owner and switching to
   `forkhub` repoints the electron-updater feed to
   `{provider: "github", owner, repo: ".forkhub"}`; selecting ForkHub with
   no owner fails with a typed error naming the missing profile/org.
   Nightly-based builds install on ForkHub (prerelease flags on);
   preview cuts never do.
3. **Validation is real**: `checkForkHubOwner` accepts an owner with
   published public `.forkhub` releases and rejects invalid names
   (no network), missing catalogs, and empty catalogs
   (`forkHub.logic.test.ts`).
4. **Brand is visible**: top-left shows "x ForkHub" exactly when the
   ForkHub track is active; `T3CODE_FORKHUB_BUILD=1` builds are named
   "T3 Code x ForkHub".
5. **Update-all nudge**: the downloaded-update toast and the install
   confirmation both tell the user to bring connected servers to the same
   version with Update all.
6. **Provenance version**: built versions carry
   `<upstream>.fh.<owner>.<n>` (e.g.
   `0.0.43-nightly.20260924.2187.fh.imbios.1`); stock tracks refuse
   suffixed builds, ForkHub installs them.
7. **Focused suites pass**: `verify.sh` exits 0. No repo-wide checks.

## How to verify

```bash
sh repos/github.com/pingdotgg/t3code/patches/t3code-forkhub-update-track-bb0ed06f/verify.sh
```

8. **Side-by-side isolation**: a packaged ForkHub version resolves its
   backend home under `~/.t3-forkhub`, its Electron profile to
   `t3code-forkhub`, and its Linux identity to the ForkHub entry/wmClass
   while stock keeps `~/.t3`/`t3code`; a malformed
   `desktop-settings.json` under a ForkHub version boots on defaults and
   leaves a `.corrupt.bak` sidecar, while stock leaves no sidecar
   (`DesktopEnvironment.test.ts`, `DesktopEarlyElectronStartup.test.ts`,
   `DesktopAppSettings.test.ts`).

9. **First-boot import**: a packaged ForkHub version with a fresh implicit
   home copies the three state files from the stock home and leaves a
   marker; reruns, existing settings, deliberate resets, stock builds, and
   explicit `T3CODE_HOME` all skip (`DesktopForkHubStockImport.test.ts`).

10. **Publisher model**: no `forkhub` update track exists; a ForkHub build
    polls its publisher's catalog on the selected latest/nightly track;
    persisted `forkhub` values migrate to nightly keeping the publisher;
    Check reports stable/nightly/both/neither trains; fresh ForkHub homes
    default to publisher `with-fh`; `.fh` versions install on ForkHub
    builds only.
