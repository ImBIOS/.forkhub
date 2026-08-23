---
id: fix-t3code-strip-osc-ansi-escapes-from-opencode-cl-y7shx01y
title: fix(t3code): strip OSC/ANSI escapes from OpenCode CLI inventory and stored agent selections (UnknownError / timeout)
target_repo: github.com/pingdotgg/t3code
target_area: [apps/server/src/provider/Layers/OpenCodeAdapter.ts, apps/server/src/provider/Layers/OpenCodeProvider.ts, apps/server/src/provider/opencodeRuntime.cliParsers.test.ts, apps/server/src/provider/opencodeRuntime.ts, apps/server/src/textGeneration/OpenCodeTextGeneration.ts, packages/shared/package.json, packages/shared/src/model.ts, packages/shared/src/stripTerminalEscapes.ts]
status: applied
applied_upstream_pr:
  number: 7755
  url: https://github.com/pingdotgg/t3code/pull/7755
  issue: https://github.com/pingdotgg/t3code/issues/7754
version: 1
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-08-21
last_realized_against_commit: 45a2c4b
verifies_with: bun test --filter opencodeRuntime.cliParsers
---

## Intent

fix(t3code): strip OSC/ANSI escapes from OpenCode CLI inventory and stored agent selections (UnknownError / timeout)

## Why

OpenCode CLI <=1.18.19 leaks OSC window-title sequences `ESC ]0;<cwd>: ready BEL` (`\x1b]0;... \x07`, `^[]0;...^G`) to stdout even when piped (`opencode agent list 2>&1 | cat -v` shows polluted). T3's `ChildProcessSpawner` captures stdout via `collectStreamAsString` in `apps/server/src/provider/opencodeRuntime.ts:208,270` and parses with `SLUG_LINE_RE`/`AGENT_HEADER_RE`, storing polluted agent id `"\u001b]0;...build"` in `model_selection_json` / `orchestration_events` (20 events, 3 threads) and `~/.t3/userdata/settings.json`. Later `SessionPrompt.createUserMessage` / `SessionHttpApi.promptAsync` in `apps/server/src/provider/Layers/OpenCodeAdapter.ts:1475` sends polluted `agent` → `Agent not found: "\u001b]0;...build". Available: build, explore, general, plan` wrapped as `UnknownError`. Wrapper `~/.local/bin/opencode-clean` buffering stdout until exit also caused `Timed out waiting for OpenCode server start after 30000ms` at `ensureSessionForThread`.

Why won't maintainer merge it immediately? They are `vouch:unvouched` gating (`CONTRIBUTING.md:15`, `.github/VOUCHED.td`, `pr-vouch.yml:78` mitchellh/vouch) and need small focused fix. This patch is self-patched build via `forkhub/main` `v0.0.34-nightly.20260821.1148-fh1` until upstream merges #7755.

## Non-negotiables

- `opencode agent list` / `models --verbose` / `skills` stdout must be stripped of OSC (`\x1b\].*?(?:\x07|\x1b\\)`), CSI (`\x1b\[[0-9;?]*[ -\/]*[@-~]`), charset (`\x1b[()][A-Za-z0-9]`) before parsing.
- Persisted selections (`ProviderOptionSelection` `agent`/`variant`, `model.ts:getProviderOptionStringSelectionValue`, `normalizeCustomModelSlug`, `trimOrNull`) must be sanitized via `sanitizeTerminalValue` so polluted DB values self-heal.
- Inventory must show clean `build (primary)`, `explore`, `general`, `plan` not polluted ids.
- `opencode serve` passthrough must remain streaming (no buffer-until-close) to avoid 30s timeout.
- New file `packages/shared/src/stripTerminalEscapes.ts` exports `stripTerminalEscapes`/`sanitizeTerminalValue` and is re-exported via `packages/shared/package.json:./stripTerminalEscapes`.

## Implementation notes

- New `packages/shared/src/stripTerminalEscapes.ts` with OSC_RE, CSI_RE, CHARSET_RE, SINGLE_ESC_RE and helpers.
- Updated `packages/shared/src/model.ts:43-71,256,313` to sanitize.
- Updated `apps/server/src/provider/opencodeRuntime.ts` parsers to `stripTerminalEscapes(stdout).split("\n")`.
- Updated `apps/server/src/provider/Layers/OpenCodeProvider.ts:164,188,393` (variantValues, agents, version).
- Updated `apps/server/src/provider/Layers/OpenCodeAdapter.ts:27,1476` and `apps/server/src/textGeneration/OpenCodeTextGeneration.ts:16,411` to sanitize `agent`/`variant` before `session.promptAsync`.
- Added tests `apps/server/src/provider/opencodeRuntime.cliParsers.test.ts` for OSC/ANSI cases.
- Local workaround `~/.local/bin/opencode-clean` (bun, serve passthrough) + cleaned DB (`/tmp/clean-db3.mjs` VACUUM) + `settings.json` for desktop 0.0.33 until rebuild.
