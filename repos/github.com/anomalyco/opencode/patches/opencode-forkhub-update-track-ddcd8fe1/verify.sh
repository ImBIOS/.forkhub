#!/bin/sh
# Verify gate for opencode-forkhub-update-track.
# Runs in the patched upstream checkout (one simple command per line: the
# forkhub verify runner executes each line separately).
# Focused suites only — full CI stays upstream's job.
(cd packages/desktop && bun test src/main/updater/forkhub.test.ts src/main/updater/index.test.ts)
(cd packages/desktop && bun typecheck)
(cd packages/app && bun test --conditions=solid --preload ./happydom.ts ./src/shell/updates/forkhub.test.ts)
(cd packages/app && bun typecheck)
