---
id: fix-auth-stop-accumulating-authorized-client-sessi-p5zy3k6c
title: fix(auth): stop accumulating authorized-client sessions per relaunch
target_repo: github.com/pingdotgg/t3code
target_area: [apps/server/src/auth, apps/server/src/persistence, packages/contracts/src/auth.ts, packages/client-runtime/src/authorization, apps/web/src/connection/platform.ts, apps/desktop/src/backend/DesktopLocalEnvironmentAuth.ts, apps/mobile]
status: applied
applied_upstream_pr: none
version: 1
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: https://github.com/ImBIOS/t3code/tree/fix/auth-client-session-rotation
imported_at: null
created: 2026-08-23
last_realized_against_commit: 30d9c19
verifies_with: bun test
---

## Intent

Every bearer bootstrap exchange minted a brand-new auth session row and sessions live
for 30 days, so Settings → Authorized clients fills with duplicate "T3 Code Desktop"
entries from repeated desktop launches, window reloads, and dev restarts — all from a
single machine. Clients should collapse onto one session per install instead, and the
session table should stop growing unbounded.

## Why

The server keys nothing on client identity: `exchangeBootstrapCredentialForAccessToken`
calls `sessions.issue()` unconditionally, and `DesktopLocalEnvironmentAuth` caches its
bearer token in memory only, so every app relaunch adds a row that then lingers for the
30-day TTL. Heavy users see dozens of stale "authorized clients". Nothing prunes expired
or revoked rows either, so `auth_sessions` grows forever.

## Non-negotiables

- Clients present a stable per-install id (`client_instance_id`) on `/oauth/token`
  exchanges; persistence per surface: desktop main process file in state dir, web /
  desktop renderer localStorage, mobile secure storage.
- Server reuses the existing compatible session (same subject + method + instance id):
  extend expiry, re-sign token against the same row. No new row on relaunch.
- Scope-widening issues a replacement and revokes the stale session.
- DPoP exchanges are exempt from reuse (key thumbprint not persisted → cannot safely
  re-sign); their short-TTL rows still get pruned.
- Issuance prunes expired and revoked rows.
- Wire format is additive: clients that never send `client_instance_id` behave exactly
  as before.

## Implementation notes

- contracts: optional `instanceId` on `AuthClientPresentationMetadata` / `AuthClientMetadata`,
  optional `client_instance_id` on `AuthTokenExchangeRequest`.
- server: migration `041_AuthSessionClientInstanceId` adds `auth_sessions.client_instance_id`;
  repo gains `listActiveForIdentity`, `updateExpiration`, `prune`; `SessionStore.issue`
  implements reuse-or-rotate plus piggyback pruning; presented metadata flows through
  `deriveAuthClientMetadata` and the auth http handler.
- clients: shared helper `readOrCreateClientInstanceId` in client-runtime authorization;
  web `clientMetadata()` reads localStorage; desktop persists `<stateDir>/client-instance-id`;
  mobile adds `loadOrCreateClientInstanceId` and threads it through cloud link + platform
  presentation metadata.
- docs/internals/environment-auth.md documents the new parameter and semantics.

## How to verify

```bash
pnpm exec vp test run apps/server/src/auth/SessionStore.test.ts \
  apps/server/src/persistence/RepositoryErrorCorrelation.test.ts apps/server/src/auth/utils.test.ts
pnpm exec vp test run apps/server/src/server.test.ts -t "collapses repeated token exchanges"
pnpm exec vp test run apps/desktop/src/backend/DesktopLocalEnvironmentAuth.test.ts
pnpm exec vp test run apps/mobile/src/features/cloud/linkEnvironment.test.ts
```

Manual: pair once, restart the desktop app repeatedly — Settings → Authorized clients
shows exactly one "T3 Code Desktop" row instead of one per launch.
