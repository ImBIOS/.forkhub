---
id: feat-t3code-server-side-scheduled-tasks-start-agen-vf7mpa71
title: feat(t3code): server-side scheduled tasks — start agent runs automatically (one-shot + recurring)
target_repo: github.com/pingdotgg/t3code
target_area: [apps/server/integration/OrchestrationEngineHarness.integration.ts, apps/server/integration/orphanedProviderSessionStartup.integration.test.ts, apps/server/src/auth/RpcAuthorization.ts, apps/server/src/checkpointing/CheckpointDiffQuery.test.ts, apps/server/src/environment/ServerEnvironment.ts, apps/server/src/orchestration/Layers/OrchestrationEngine.test.ts, apps/server/src/orchestration/Layers/OrchestrationEngine.ts, apps/server/src/orchestration/Layers/OrchestrationReactor.test.ts, apps/server/src/orchestration/Layers/OrchestrationReactor.ts, apps/server/src/orchestration/Layers/ProjectionPipeline.ts, apps/server/src/orchestration/Layers/ProjectionSnapshotQuery.ts, apps/server/src/orchestration/Layers/TaskFireReactor.ts, apps/server/src/orchestration/Layers/TaskScheduler.test.ts, apps/server/src/orchestration/Layers/TaskScheduler.ts, apps/server/src/orchestration/Schemas.ts, apps/server/src/orchestration/Services/ProjectionSnapshotQuery.ts, apps/server/src/orchestration/Services/TaskFireReactor.ts, apps/server/src/orchestration/Services/TaskScheduler.ts, apps/server/src/orchestration/commandInvariants.test.ts, apps/server/src/orchestration/commandInvariants.ts, apps/server/src/orchestration/decider.pinned.test.ts, apps/server/src/orchestration/decider.scheduled-tasks.test.ts, apps/server/src/orchestration/decider.settled.test.ts, apps/server/src/orchestration/decider.snoozed.test.ts, apps/server/src/orchestration/decider.titleRegeneration.test.ts, apps/server/src/orchestration/decider.ts, apps/server/src/orchestration/projector.ts, apps/server/src/persistence/Layers/OrchestrationEventStore.ts, apps/server/src/persistence/Layers/ProjectionTasks.ts, apps/server/src/persistence/Migrations.ts, apps/server/src/persistence/Migrations/041_ProjectionTasks.ts, apps/server/src/persistence/Services/OrchestrationCommandReceipts.ts, apps/server/src/persistence/Services/ProjectionTasks.ts, apps/server/src/project/ProjectSetupScriptRunner.test.ts, apps/server/src/provider/Layers/ProviderSessionReaper.test.ts, apps/server/src/server.test.ts, apps/server/src/server.ts, apps/server/src/serverRuntimeStartup.test.ts, apps/server/src/serverRuntimeStartup.ts, apps/server/src/ws.ts, apps/web/src/components/settings/ProjectSettingsPanel.tsx, apps/web/src/components/settings/ScheduledTasksSection.tsx, apps/web/src/state/entities.ts, apps/web/src/state/orchestration.ts, docs/internals/glossary.md, docs/user/scheduled-tasks.md, packages/client-runtime/package.json, packages/client-runtime/src/operations/commands.ts, packages/client-runtime/src/state/orchestration.ts, packages/contracts/src/environment.ts, packages/contracts/src/orchestration.ts, packages/contracts/src/rpc.ts, pnpm-lock.yaml]
status: applied
applied_upstream_pr: none
version: 1
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-08-23
last_realized_against_commit: 30d9c19
verifies_with: bun test
---

## Intent

feat(t3code): server-side scheduled tasks — start agent runs automatically (one-shot + recurring)

## Why

(Filled by user)

## Non-negotiables

(Filled by user)

## Implementation notes

(Filled by user — describe what was done)
