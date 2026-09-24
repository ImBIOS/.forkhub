#!/bin/sh
# Verify gate for t3code-forkhub-update-track.
# Runs in the patched upstream checkout (one simple command per line: the
# forkhub verify runner executes each line separately).
# Focused suites only — full CI stays upstream's job.
command -v pnpm >/dev/null 2>&1 || corepack enable || true
test -x node_modules/.bin/vp || pnpm install --ignore-scripts
node_modules/.bin/vp test run apps/web/src/components/forkHub.logic.test.ts apps/web/src/components/desktopUpdate.logic.test.ts apps/web/src/components/desktopUpdate.toast.test.tsx apps/web/src/components/sidebar/SidebarUpdatePill.test.tsx apps/web/src/components/sidebar/SidebarUpdateReleaseNotes.test.tsx apps/web/src/state/desktopUpdate.test.ts
node_modules/.bin/vp test run apps/desktop/src/updates/updateChannels.test.ts apps/desktop/src/updates/remoteUpdateFlow.test.ts apps/desktop/src/updates/releaseNotes.test.ts apps/desktop/src/updates/DesktopUpdates.test.ts apps/desktop/src/updates/DesktopRemoteUpdates.test.ts apps/desktop/src/settings/DesktopAppSettings.test.ts
node_modules/.bin/vp test run apps/server/src/desktopUpdate/DesktopAppUpdate.test.ts
