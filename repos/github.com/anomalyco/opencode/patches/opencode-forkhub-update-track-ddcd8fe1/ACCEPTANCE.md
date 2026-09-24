# Acceptance Criteria — opencode-forkhub-update-track-ddcd8fe1

## Must pass for promotion to APPLIED

1. **Default behavior unchanged**: a fresh install reports track `latest`
   with null ForkHub owner; the updater still configures `channel: "latest"`
   with `allowPrerelease: false`, and startup on `latest` never touches the
   feed. All pre-existing updater service tests pass
   (`index.test.ts`, 22 tests).
2. **ForkHub track works**: setting a validated owner and switching to
   `forkhub` repoints the electron-updater feed to
   `{provider: "github", owner, repo: ".forkhub"}`; selecting ForkHub with
   no owner fails with an error naming the missing profile/org.
   Switching back to `latest` restores the baked-in generic feed.
   The service interface stays electron-free so its tests run without
   mocks (`index.test.ts` ForkHub cases).
3. **Validation is real**: `checkForkHubOwner` accepts an owner with
   published public `.forkhub` releases and rejects invalid names
   (no network), missing catalogs (404), and empty catalogs
   (`forkhub.test.ts` main + app).
4. **Brand is visible**: titlebar shows "x ForkHub" exactly when the
   ForkHub track is active (including prod builds);
   `OPENCODE_FORKHUB_BUILD=1` builds use app id
   `ai.opencode.desktop.forkhub.<owner>.latest` and product name
   "OpenCode x ForkHub".
5. **Patch applies to prod**: `reference.diff` applies clean to pristine
   upstream `v2.0.16` (`git apply --check`).
6. **Focused suites pass**: `verify.sh` exits 0. No repo-wide checks.

## How to verify

```bash
sh repos/github.com/anomalyco/opencode/patches/opencode-forkhub-update-track-ddcd8fe1/verify.sh
```
