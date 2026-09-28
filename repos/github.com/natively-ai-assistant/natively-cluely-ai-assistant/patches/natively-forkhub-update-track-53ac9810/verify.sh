#!/bin/sh
# Verify gate for natively-forkhub-update-track.
# Runs in the patched Natively checkout (one simple command per line: the
# forkhub verify runner executes each line separately).
# Focused suites only — full CI stays upstream's job.
test -d node_modules || npm install --ignore-scripts
npm run build:electron
node --test electron/update/updateFeed.test.mjs electron/update/ReleaseNotesManager.test.mjs electron/services/__tests__/HardwareId.test.mjs
