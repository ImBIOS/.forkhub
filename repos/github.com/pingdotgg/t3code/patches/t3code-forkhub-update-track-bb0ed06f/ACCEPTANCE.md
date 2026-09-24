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
6. **Focused suites pass**: `verify.sh` exits 0. No repo-wide checks.

## How to verify

```bash
sh repos/github.com/pingdotgg/t3code/patches/t3code-forkhub-update-track-bb0ed06f/verify.sh
```
