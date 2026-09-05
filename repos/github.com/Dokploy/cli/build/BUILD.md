---
target_repo: github.com/Dokploy/cli
artifacts: [patched-source-tarball]
toolchain: ./build.sh (edit for your repo: bun build / npm pack / docker build / ...)
outputs: dist/*
---

## Build intent

How to turn upstream `github.com/Dokploy/cli` + the intent stack in `../patches/`
(applied in `manifest.json:apply_order`) into a working release.

## How (agent: fill this in, ask the user first)

1. Confirm the trigger with the user and record it in `triggers.md`
   (triggers affect LLM token + CI spend — never assume).
2. Replace `build.sh` with the repo-native build
   (e.g. `bun build --compile`, `npm pack`, `docker build`).
   Until `build.sh` writes artifacts to `dist/`, CI ships the verified
   patched source as a tarball, which works for ANY OSS type:
   CLI, GUI, AppImage/dmg/exe, Next.js, etc.
3. Describe every install vector in `CONSUME.md` (binary, npm, docker, brew, source).

## Reuse

This file is discoverable via `fh search --target github.com/Dokploy/cli`
alongside the patch INTENTS. Import it with:

```bash
fh import https://github.com/<user>/.forkhub/blob/main/repos/github.com/Dokploy/cli/build/BUILD.md
```
