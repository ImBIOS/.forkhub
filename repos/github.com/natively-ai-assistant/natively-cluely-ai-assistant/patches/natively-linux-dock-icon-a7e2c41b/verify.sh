#!/bin/sh
# Verify gate for natively-linux-dock-icon.
# Runs in the patched Natively checkout AFTER patches 1+2 (manifest
# apply_order) — one simple command per line: the forkhub verify runner
# executes each line separately.
# Focused suites only — full CI stays upstream's job.
test -d node_modules || npm install --ignore-scripts
node node_modules/electron/install.js
npm run build:electron
node --test electron/services/__tests__/LinuxDockAssociation.test.mjs
