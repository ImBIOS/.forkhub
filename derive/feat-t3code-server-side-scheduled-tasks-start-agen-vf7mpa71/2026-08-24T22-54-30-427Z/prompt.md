# Re-derivation Task

You are re-deriving the patch `feat-t3code-server-side-scheduled-tasks-start-agen-vf7mpa71` against new upstream code.

## Your task

1. Read `INTENT.md` (source of truth — what to implement)
2. Read `ACCEPTANCE.md` (verification criteria)
3. Read `drift-summary.txt` (what changed in upstream)
4. Read `reference.diff` (previous realization — HINT only, do NOT apply mechanically)
5. Read `attempts.jsonl` (past failures to avoid)
6. Read `siblings/*.md` (other patches already applied — preserve their code)
7. Compare `upstream/` and `fork/` (to understand current state)
8. Implement the patch against `fork/`
9. Save the diff to `REALIZATION/realization.diff` (must be valid `git apply` format)
10. Write a self-evaluation to `REALIZATION/report.md`

## Constraints

- DO NOT modify files the INTENT says are off-limits
- DO NOT apply reference.diff mechanically — re-derive from intent
- DO preserve sibling patches' code verbatim
- DO write a clean unified diff (only the lines that change)

## Output

When done, the `forkhub apply` command will validate and finalize. Make sure:
- `REALIZATION/realization.diff` exists and is non-empty
- `REALIZATION/report.md` describes what you did

Begin.
