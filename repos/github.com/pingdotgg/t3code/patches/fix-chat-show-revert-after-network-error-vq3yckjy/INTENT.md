---
id: fix-chat-show-revert-after-network-error-vq3yckjy
title: fix(chat): show revert after network_error
target_repo: github.com/pingdotgg/t3code
target_area: [apps/web/src/components/ChatView.tsx]
status: applied
applied_upstream_pr: 7983
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

fix(chat): show revert button after Provider finish_reason network_error

## Why

When provider finishes with `finish_reason: network_error`, the last user message row shows only the copy button and no revert/undo affordance. The timeline still has a checkpoint (`status: error`) for the failed turn, but `ChatView.tsx:2620` derives `revertTurnCount` only via `turnDiffSummaryByAssistantMessageId` lookup on the *next* assistant message. Failed turns with `network_error` often have no `assistant_message` or a synthetic `assistant:${turnId}` id that never appears in `timelineEntries`, so the lookup misses and `canRevertAgentWork` stays false. Users cannot revert the failed turn to retry/cleanly remove it.

## Non-negotiables

- After any terminal turn (including `status: error`/`network_error`) the preceding user message must expose the revert button (up to `isRevertingCheckpoint`/`isWorking` disabled state).
- Existing revert semantics preserved: `turnCount = checkpointTurnCount - 1`, chronological ordering, `revertTurnCountRef` still drives `revertThreadCheckpoint`.
- No extra rows or checkpoints created; only the visibility derivation changes.
- No regression to `MessagesTimeline.logic` row stability / `deriveMessagesTimelineRows` folding.

## Implementation notes

- `apps/web/src/components/ChatView.tsx:2620` – keep existing assistant-message scan, add deterministic fallback: if no candidate found, map `nth` user message to `nth` checkpoint sorted by `completedAt` (1:1 user->turn). This covers synthetic `assistant:${turnId}` and zero-message failed turns.
- Checked that `CheckpointReactor.ts:355` still creates a checkpoint for `state: failed` (status `error`), so fallback has a candidate.
- Added `if(byUserMessageId.has(...)) continue` guard to not override direct hits.
