# Re-derivation Context Bundle

**Patch**: `feat-t3code-server-side-scheduled-tasks-start-agen-vf7mpa71`
**Generated**: 2026-08-24T22:54:30.553Z
**Upstream**: 30d9c19 → 9996038

## What this is

This is a context bundle for re-deriving the patch against new upstream code.
The AI agent should read everything in this directory and produce a new realization
saved to `REALIZATION/`.

## Files in this bundle

- `INTENT.md` — the source of truth (what to implement)
- `ACCEPTANCE.md` — verification criteria
- `reference.diff` — previous realization (HINT only, do NOT apply mechanically)
- `attempts.jsonl` — past attempt history (learn from failures)
- `drift-summary.txt` — what changed in upstream's target_area
- `siblings/` — other patches already applied (preserve their code)
- `upstream/` — clean upstream code (no patches)
- `fork/` — current fork state (upstream + siblings)
- `REALIZATION/` — YOUR OUTPUT GOES HERE

## Steps for the AI

1. Read `INTENT.md` (source of truth for what to implement)
2. Read `ACCEPTANCE.md` (how to verify the result)
3. Read `drift-summary.txt` (what changed in upstream)
4. Read `reference.diff` (what worked last time — HINT only, not literal)
5. Read `attempts.jsonl` (past failures to avoid)
6. Read `siblings/*.md` (what other patches added — must coexist)
7. Compare `upstream/` vs `fork/` (to understand current state)
8. Implement the patch against `fork/`
9. Save your diff to `REALIZATION/realization.diff`
10. Write your self-evaluation to `REALIZATION/report.md`

## Constraints

- DO NOT modify files the INTENT says are off-limits
- DO NOT apply reference.diff mechanically — re-derive from intent
- DO preserve sibling patches' code verbatim
- DO write a clean unified diff (only the lines that change)
- The realization must be a valid `git diff` that can be applied with `git apply`

## After the AI finishes

Run `forkhub apply /home/imbios/dev/projects/.forkhub/derive/feat-t3code-server-side-scheduled-tasks-start-agen-vf7mpa71/2026-08-24T22-54-30-427Z` to validate and finalize.
