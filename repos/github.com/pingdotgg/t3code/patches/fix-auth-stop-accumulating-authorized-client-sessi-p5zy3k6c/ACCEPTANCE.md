# Acceptance Criteria — fix-auth-stop-accumulating-authorized-client-sessi-p5zy3k6c

## Must pass for promotion to APPLIED

1. **Default behavior unchanged**: clients that never send `client_instance_id`
   still get one new session per exchange (old behavior preserved).

2. **Patch works**: relaunching the desktop app reuses a single
   "T3 Code Desktop" authorized-client session; expiry slides forward.

3. **Existing tests pass**: focused suites below exit 0.

4. **No unintended file changes**: only the files listed in `target_area` /
   `reference.diff` are modified.

## How to verify

```bash
pnpm exec vp test run apps/server/src/auth/SessionStore.test.ts \
  apps/server/src/persistence/RepositoryErrorCorrelation.test.ts apps/server/src/auth/utils.test.ts
pnpm exec vp test run apps/server/src/server.test.ts -t "collapses repeated token exchanges"
pnpm exec vp test run apps/desktop/src/backend/DesktopLocalEnvironmentAuth.test.ts
pnpm exec vp test run apps/mobile/src/features/cloud/linkEnvironment.test.ts
```

Manual: pair once, restart the desktop app several times — exactly one
"T3 Code Desktop" entry remains in Settings → Authorized clients.

