#!/bin/bash
# Verification script for fix-auth-stop-accumulating-authorized-client-sessi-p5zy3k6c
set -e

# Focused tests for the auth session reuse/rotation behavior
pnpm exec vp test run apps/server/src/auth/SessionStore.test.ts \
  apps/server/src/persistence/RepositoryErrorCorrelation.test.ts \
  apps/server/src/auth/utils.test.ts
pnpm exec vp test run apps/server/src/server.test.ts -t "collapses repeated token exchanges"
pnpm exec vp test run apps/desktop/src/backend/DesktopLocalEnvironmentAuth.test.ts
pnpm exec vp test run apps/mobile/src/features/cloud/linkEnvironment.test.ts

# Schema migration applies cleanly on an existing database (idempotent column add)
