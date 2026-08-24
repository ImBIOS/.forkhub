# Acceptance Criteria — feat-t3code-server-side-scheduled-tasks-start-agen-vf7mpa71

## Must pass for promotion to APPLIED

1. **Default behavior unchanged**: running the code without any patch-specific flags
   produces identical output to upstream.

2. **Patch works**: the feature/fix described in INTENT.md functions correctly.

3. **Existing tests pass**: `bun test` exits 0.

4. **No unintended file changes**: only the files listed in target_area are modified.

## How to verify

```bash
bun test
```
