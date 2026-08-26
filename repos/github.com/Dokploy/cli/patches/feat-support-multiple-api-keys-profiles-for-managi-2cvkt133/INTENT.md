---
id: feat-support-multiple-api-keys-profiles-for-managi-2cvkt133
title: feat: support multiple API keys (profiles) for managing multiple Dokploy organizations - resolve Dokploy/cli#44
target_repo: github.com/Dokploy/cli
target_area: [readme.md, src/client.ts, src/commands/auth.ts, src/commands/profile.ts, src/index.ts, tests/cli.test.ts, tests/client.test.ts]
status: applied
applied_upstream_pr: none
version: 1
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-08-26
last_realized_against_commit: 4f8b1e5
verifies_with: bun test
---

## Intent

feat: support multiple API keys (profiles) for managing multiple Dokploy organizations - resolve Dokploy/cli#44

## Why

The upstream `Dokploy/cli` stores a single `config.json` next to the package and has no profile concept. Users managing multiple organizations used the external `dokploy-account` bash wrapper (`~/.local/bin/dokploy-account`) which kept per-account env files in `~/.dokploy-accounts/*.env` and `exec`d `dokploy` with `DOKPLOY_URL`/`DOKPLOY_API_KEY`. This requires a second binary, duplicates auth logic, and is not managed by `fh update` (wrapper lives outside the repo). Maintainers have not merged profile support, so we keep it as an intent-patch.

## Non-negotiables

- `DOKPLOY_URL`/`DOKPLOY_API_KEY` (and `DOKPLOY_AUTH_TOKEN`) env vars always win over stored profiles (CI backward compat).
- `DOKPLOY_PROFILE` env var and global `--profile <name>` flag override active profile per-command.
- Credentials stored in `~/.dokploy/config.json` (override with `DOKPLOY_CONFIG_DIR` for tests) with `0700` dir / `0600` file perms; legacy `config.json` next to package auto-migrates to `default` profile and is renamed to `.bak`.
- `dokploy --help` still shows top-level help; `--profile` is global via `program.option` + `preAction` hook.
- Single-profile users see no behavior change; `readAuthConfig()` resolution order: `env > active profile > default`.

## Implementation notes

- `src/client.ts`: add `StoredProfile`/`StoredConfig` (`currentProfile` + `profiles` map), `getConfigPath()`, `migrateLegacyConfig()`, `getCurrentProfile()`, `listProfiles()`, `setCurrentProfile()`, `removeProfile()`, rework `readAuthConfig(profile?)` and `saveAuthConfig(url,token,profile)`. Config dir via `os.homedir()` + `DOKPLOY_CONFIG_DIR` env.
- `src/commands/auth.ts`: add `--profile <name>` option.
- `src/commands/profile.ts` (new): `registerProfileCommands` for `dokploy profiles list|use|current|remove`.
- `src/index.ts`: add `.option("--profile <name>")` and `program.hook("preAction")` setting `process.env.DOKPLOY_PROFILE`.
- `tests/client.test.ts` + `tests/cli.test.ts`: add isolated tests using temp `DOKPLOY_CONFIG_DIR`.
- `readme.md`: document `dokploy auth --profile`, `profiles` commands, and `--profile`/`DOKPLOY_PROFILE` overrides.
