---
id: fix-sanitize-model-selections-on-creation-to-preve-gyydstcz
title: fix: sanitize model selections on creation to prevent re-pollution of DB
target_repo: github.com/pingdotgg/t3code
target_area: [apps/server/src/persistence/Migrations.ts, apps/server/src/persistence/Migrations/041_CleanOscPollution.ts, packages/shared/src/model.ts, packages/shared/src/stripTerminalEscapes.ts]
status: applied
applied_upstream_pr: none
version: 1
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-08-24
last_realized_against_commit: 30d9c19
verifies_with: bun test
---

## Intent

fix: sanitize model selections on creation to prevent re-pollution of DB

## Why

(Filled by user)

## Non-negotiables

(Filled by user)

## Implementation notes

(Filled by user — describe what was done)
