---
id: feat-t3code-server-side-scheduled-tasks-start-agen-vf7mpa71
title: feat(t3code): server-side scheduled tasks — start agent runs automatically (one-shot + recurring)
target_repo: github.com/pingdotgg/t3code
target_area: [apps/server/integration/OrchestrationEngineHarness.integration.ts, apps/server/integration/orphanedProviderSessionStartup.integration.test.ts, apps/server/src/auth/RpcAuthorization.ts, apps/server/src/checkpointing/CheckpointDiffQuery.test.ts, apps/server/src/environment/ServerEnvironment.ts, apps/server/src/orchestration/Layers/OrchestrationEngine.test.ts, apps/server/src/orchestration/Layers/OrchestrationEngine.ts, apps/server/src/orchestration/Layers/OrchestrationReactor.test.ts, apps/server/src/orchestration/Layers/OrchestrationReactor.ts, apps/server/src/orchestration/Layers/ProjectionPipeline.ts, apps/server/src/orchestration/Layers/ProjectionSnapshotQuery.ts, apps/server/src/orchestration/Layers/TaskFireReactor.ts, apps/server/src/orchestration/Layers/TaskScheduler.test.ts, apps/server/src/orchestration/Layers/TaskScheduler.ts, apps/server/src/orchestration/Schemas.ts, apps/server/src/orchestration/Services/ProjectionSnapshotQuery.ts, apps/server/src/orchestration/Services/TaskFireReactor.ts, apps/server/src/orchestration/Services/TaskScheduler.ts, apps/server/src/orchestration/commandInvariants.test.ts, apps/server/src/orchestration/commandInvariants.ts, apps/server/src/orchestration/decider.pinned.test.ts, apps/server/src/orchestration/decider.scheduled-tasks.test.ts, apps/server/src/orchestration/decider.settled.test.ts, apps/server/src/orchestration/decider.snoozed.test.ts, apps/server/src/orchestration/decider.titleRegeneration.test.ts, apps/server/src/orchestration/decider.ts, apps/server/src/orchestration/projector.ts, apps/server/src/persistence/Layers/OrchestrationEventStore.ts, apps/server/src/persistence/Layers/ProjectionTasks.ts, apps/server/src/persistence/Migrations.ts, apps/server/src/persistence/Migrations/041_ProjectionTasks.ts, apps/server/src/persistence/Services/OrchestrationCommandReceipts.ts, apps/server/src/persistence/Services/ProjectionTasks.ts, apps/server/src/project/ProjectSetupScriptRunner.test.ts, apps/server/src/provider/Layers/ProviderSessionReaper.test.ts, apps/server/src/server.test.ts, apps/server/src/server.ts, apps/server/src/serverRuntimeStartup.test.ts, apps/server/src/serverRuntimeStartup.ts, apps/server/src/ws.ts, apps/web/src/components/settings/ProjectSettingsPanel.tsx, apps/web/src/components/settings/ScheduledTasksSection.tsx, apps/web/src/state/entities.ts, apps/web/src/state/orchestration.ts, docs/internals/glossary.md, docs/user/scheduled-tasks.md, packages/client-runtime/package.json, packages/client-runtime/src/operations/commands.ts, packages/client-runtime/src/state/orchestration.ts, packages/contracts/src/environment.ts, packages/contracts/src/orchestration.ts, packages/contracts/src/rpc.ts, pnpm-lock.yaml, packages/contracts/src/settings.ts, apps/server/src/serverSettings.test.ts, apps/web/src/components/settings/IntegrationsSettings.tsx, apps/web/src/components/settings/SettingsPanels.tsx, apps/web/src/components/settings/settingsSearch.ts]
status: applied
applied_upstream_pr: 7986
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

T3 Code only starts agent runs when user sends a message. Real work is time-shaped: nightly maintenance, delayed follow-ups, recurring chores per project. Thread snooze is visibility-only and client-derived (local timeout) — nothing happens if no client open or server restarts. Need server-authoritative time→turn wiring.

Fixes pingdotgg/t3code#7966.

## Non-negotiables

- Event-sourced: task.schedule / task.cancel (client) + internal task.fire, events task.scheduled / task.fired / task.cancelled on `task` aggregate. Schedule v1: one-shot `at` OR interval `everyMs` anchored at creation (≥1min), no cron yet.
- Decider validates future first-fire times; deterministic commandIds `server:task-fire:<taskId>:<dueAt>` for idempotent retry; interval slots never drift (advance from previous due slot), downtime coalesces to one fire on first future slot.
- Scheduler layer modeled on ProviderSessionReaper (15s tick, manual-tick seam) finds due tasks in projection and fires; reactor turns task.fired into normal thread.turn.start on anchor thread.
- Read model: projection_tasks table + listTasks/listDueTasks + orchestration.listTasks RPC, taskScheduling capability gate.
- Web UI under Settings → Projects (create/cancel/list); mobile inherits via client-runtime.
- Feature switch: `enableScheduledTasks` ServerSettings flag (default on), Settings → Integrations → Automation toggle; TaskScheduler tick reads it per cycle and skips due-scan when off; per-project schedule UI hides while off; stored tasks resume untouched on re-enable.

## Implementation notes

Implemented as 52-file patch: contracts (orchestration.ts/rpc.ts/environment.ts), decider + projector + migrations (041_ProjectionTasks), TaskScheduler + TaskFireReactor layers, ProjectionTasks persistence, ws + serverRuntimeStartup wiring, client-runtime commands, and ScheduledTasksSection web component. See PR pingdotgg/t3code#7986 for full details. Verified via decider.scheduled-tasks.test.ts (11 tests) + TaskScheduler.test.ts, full decider/commandInvariants/reactor/pipeline scope passes.
