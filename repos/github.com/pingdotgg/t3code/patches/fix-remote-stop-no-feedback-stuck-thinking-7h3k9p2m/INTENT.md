---
id: fix-remote-stop-no-feedback-stuck-thinking-7h3k9p2m
title: fix(remote): stop button gives immediate feedback and prevents stuck thinking on remote server
target_repo: github.com/pingdotgg/t3code
target_area: [apps/web/src/components/ChatView.tsx, apps/web/src/components/ChatView.logic.ts, apps/web/src/components/chat/ComposerPrimaryActions.tsx, apps/web/src/components/chat/MessagesTimeline.tsx, apps/web/src/session-logic.ts, apps/mobile/src/features/threads/ThreadRouteScreen.tsx, packages/client-runtime/src/state/threadCommands.ts, packages/client-runtime/src/state/threadReducer.ts, packages/client-runtime/src/state/threads.ts, apps/server/src/orchestration/Layers/ProjectionPipeline.ts, apps/server/src/orchestration/decider.ts, apps/server/src/provider/Layers/OpenCodeAdapter.ts, apps/server/src/provider/Layers/ClaudeAdapter.ts, packages/client-runtime/src/state/runtime.ts]
status: applied
applied_upstream_pr:
  number: 8619
  url: https://github.com/pingdotgg/t3code/pull/8619
  issue: https://github.com/pingdotgg/t3code/issues/8618
  issue_number: 8618
  state: open
version: 1
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-08-29
last_realized_against_commit: 6a9d9f9
verifies_with: bun test
---

## Intent

fix(remote): stop button gives immediate feedback and prevents stuck thinking on remote server

## Why

Using a remote T3 Code server (relay/tunnel — e.g. `myrehat-dev.asia-southeast1-a.c.myrehat...` with Local checkout), clicking the red Stop button (`■`) in the composer gives **zero UI feedback** and the thread appears stuck in `Thinking` / `Working for 6m 26s` indefinitely (screenshot: `Working for 6m 26s` / `Thinking` with red Stop still showing, model `Muse Spark 1.2 Contrib...`, `Xhigh · Build`, `Full access`).

Root cause is a tripod — remote just amplifies it because RTT 100–400ms + `SHELL_COALESCE_WINDOW 50ms` makes the dead window visible, while local 10–20ms masks it:

1. **No optimistic `stopping` state for the main turn.** `apps/web/src/components/ChatView.tsx:5487-5510` `onInterrupt` fires `interruptThreadTurn({input: buildThreadTurnInterruptInput(activeThread)})` with `reportFailure:false` and no local pending flag. The button has no `disabled`/`isStopping` prop (`ComposerPrimaryActions.tsx:88-106`). Background-stop (`handleStopBackgroundWork` `4677-4740`) is the counter-example: it tracks `isStoppingBackgroundWork`, disables the button and shows `Stopping...` until `activeBackgroundLiveness===null`. Main stop should mirror it but doesn't.

2. **Stale `turnId` guard drops the interrupt.** `buildThreadTurnInterruptInput` (`ChatView.logic.ts:141-150`) only includes `turnId` when `session.status==="running" && activeTurnId!==null`. On a remote snapshot `activeTurnId` is often `null` (still `starting` or lagged `THREAD_RESUME_MAX_GAP 1000`), so the persisted `thread.turn-interrupt-requested` omits `turnId`. Both client reducer (`packages/client-runtime/src/state/threadReducer.ts:271-292`) and server projection (`ProjectionPipeline.ts:1441-1476`) early-return `unchanged`/no-op when `turnId===undefined` or mismatched. The RPC succeeds (`sequence` returned) but `latestTurn.state` stays `running`, so no visual flip and no error.

3. **Session hang: successful interrupt can still leave `session.status===running`.** `ProviderCommandReactor.ts:1228-1321` only tears down on *failure* (`recoverInterruptFailure` → `stopSession` → `session-set stopped`). On *success* it does nothing, relying on the provider to emit `thread.session-set`. When the CLI ignores the signal (Claude `query.interrupt()` never settles, Codex `runtime.interruptTurn` no-ops, OpenCode 10s abort timeout `OpenCodeAdapter.ts:2932`), `derivePhase` (`session-logic.ts:1894-1905`) stays `running` → `isWorking` true → `MessagesTimeline.tsx:1313-1322` keeps `Working for ...` forever. Serial queue (`threadCommands.ts:177-182` `concurrency:{mode:"serial"}` per `(env,thread)`) then queues further Stop clicks behind the hung first one.

4. **No feedback on transport failure.** `createEnvironmentCommand` (`runtime.ts:577-591` + `444-455`) + `reportFailure:false` (`ChatView.tsx:1246`) swallows `EnvironmentRpcUnavailableError` while `phase==="available"|"offline"`, so relay blips produce silent no-ops.

Evidence: screenshot `~/dev/projects/` `~/.dev/projects/*` stuck `Working for 6m 26s` + `Thinking` with local checkout pinned to `myrehat-dev...` remote. Matches family `pingdotgg/t3code#4713` (session stuck `running` after interrupt, 40+ accepted interrupts no effect), `#4589` (threads stop updating), `#7820`, `#2644`. Detection query from #4713 still hits: `SELECT ... WHERE s.status='running' AND tu.state IN ('interrupted','completed','error')`.

Why won't maintainer merge immediately? `vouch:unvouched` gating and high-risk stop/session path; needs focused fix with tests for remote relay path.

## Non-negotiables

- **Immediate feedback on click (both surfaces):** Stop shows `Stopping...` (disabled) within one frame on web and mobile, even on remote relay, until server confirms terminal session or failure. Mirrors `isStoppingBackgroundWork` pattern (`ChatView.tsx:4677-4710`). No spinner that lies after `isWorking===false`.
- **Optimistic turn flip even without `turnId`:** `thread.turn-interrupt-requested` without `turnId` must still optimistically mark `latestTurn.state→interrupted` when it matches `session.activeTurnId` or the latest unsettled turn, so the UI does not depend on a stale snapshot. Guard in `threadReducer.ts:271` and `ProjectionPipeline.ts:1442` relaxed to allow fallback match.
- **Session fallback when provider hangs:** If provider interrupt succeeds but session stays `running` for >5s, server escalates to `stopSession`/`session-set` `stopped`+`interrupted` internally (same as failure path), so `derivePhase` converges and `Working` clears. Bounded similarly to `ClaudeAdapter.ts:4608` 10s `query.interrupt` +1s `getContextUsage` fix in #7349, but here for the success-still-running case.
- **Serial queue does not freeze:** Either client `request` timeout or `singleFlight: latest` semantics for `interruptTurn` so rapid Stop clicks don't enqueue behind a hung first one; or at minimum disable-while-pending prevents queue build-up.
- **Transport failures surface:** When `reportFailure:false` would swallow a relay error, surface a toast/visible error only for the integerity-critical Stop (not all commands), so remote blips aren't silent.
- **No regression:** `MessagesTimeline.logic` row stability, `deriveMessagesTimelineRows`, and existing `interruptTurn` failure-then-stopSession behaviour preserved; `ProviderCommandReactor` test updated to assert fallback.

## Implementation notes

- **Web (`apps/web/src/components/ChatView.tsx`):** Add `isStoppingTurn` state mirror of `isStoppingBackgroundWork`. `onInterrupt` sets `true` before `await interruptThreadTurn(...)`, clears on receipt of `session.status!=="running"` or `latestTurn.state==="interrupted"` or failure (`setThreadError`). Pass `isStoppingTurn` to `ComposerPrimaryActions`/`ChatComposer` to render `Stopping...` + disabled. Same for `handleStopThread` path `4501`.
- **Mobile (`apps/mobile/src/features/threads/ThreadRouteScreen.tsx:481-498`):** Same flag, block double-tap.
- **Client reducer (`packages/client-runtime/src/state/threadReducer.ts:271` + `ProjectionPipeline.ts:1441`):** Change guard `if(turnId===undefined) return unchanged` to fallback: if `turnId===undefined` use `state.session?.activeTurnId ?? latestTurn.turnId` provided latestTurn is unsettled; only no-op if truly no candidate. Keeps idempotency but fixes stale snapshot.
- **Server (`apps/server/src/orchestration/Layers/ProviderCommandReactor.ts`):** After successful `providerService.interruptTurn`, schedule 5s timer; if thread still `running` with same `activeTurnId`, emit `thread.session-set` `stopped` + turn `interrupted` (reuse `recoverInterruptFailure` logic). Add bounded `queryCurrentContextUsage` already done for failure path.
- **Client command (`packages/client-runtime/src/state/threadCommands.ts:177`):** Change `interruptTurn` scheduler to include timeout (e.g. 10s) or `mode:"singleFlight"` so relay stall doesn't hang promise forever; atom reports `Failure` to toast.
- **Tests:** Add ChatView logic test for `buildThreadTurnInterruptInput` without `turnId` still flipping; add threadReducer test for undefined turnId fallback; add ProviderCommandReactor test that hangs `interruptTurn` resolves to terminal session via timeout; update `use-thread-outbox-drain` guard check.
- Verified via `vp test run apps/web/src/components/ChatView.logic.test.ts` + `packages/client-runtime/src/state/threadReducer.test.ts` + `apps/server/src/orchestration/Layers/ProviderCommandReactor.test.ts`; manual: connect via `npx t3 --share` to remote, start long turn, hit Stop → immediate `Stopping...`, within ~5s `Thinking` clears even if provider wedged.

## How to verify

```bash
# Unit
vp test run apps/web/src/components/ChatView.logic.test.ts packages/client-runtime/src/state/threadReducer.test.ts apps/server/src/orchestration/Layers/ProviderCommandReactor.test.ts

# Manual (remote)
npx t3 --share # or --tunnel
# connect from app.t3.codes / mobile via pairingUrl, open thread, start agent job (e.g. list ~/dev/projects/*), quickly click Stop
# expect: button → Stopping... disabled instantly, toast only on transport failure, Thinking/Working clears within 5s even if provider still alive
# check DB: SELECT s.status, tu.state FROM projection_thread_sessions s JOIN projection_turns tu ... should be stopped/interrupted not running
```

Related: pingdotgg/t3code#4713, #4589, #7820, #2644, #7349, #7987, #7589.

