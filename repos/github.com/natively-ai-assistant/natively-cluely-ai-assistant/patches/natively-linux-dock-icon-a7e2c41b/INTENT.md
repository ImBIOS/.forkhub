---
id: natively-linux-dock-icon-a7e2c41b
title: Linux dock icon + pin-to-dock via deterministic WM_CLASS
target_repo: github.com/natively-ai-assistant/natively-cluely-ai-assistant
target_area: [electron/main.ts, package.json, scripts/deb-after-install.sh, electron/services/__tests__/LinuxDockAssociation.test.mjs]
status: draft
applied_upstream_pr: none
version: 1
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-09-30
last_realized_against_commit: a2485e4
verifies_with: node --test (focused suites, see verify.sh)
---

## Intent

Fix Linux dock integration: the app shows a generic icon and cannot be
pinned to dock because GNOME matches windows to `.desktop` files by
WM_CLASS, and the runtime class never deterministically equals the
shipped `StartupWMClass=Natively`.

## Why

Electron derives the X11 WM_CLASS from the app name, which defaults to
package.json `name` (`natively`), while the packaged desktop file
declares `Natively`. The disguise system renames the app later via
`app.setName()` (skipped entirely in undetectable mode), so depending on
settings and startup order the window presents `natively`, `Natively`, or
a disguise name — the desktop entry matches none of them reliably.

## Non-negotiables

1. **Never move existing profiles.** `getPath('userData')` derives from
   the app name, and the first resolution happens pre-disguise under the
   package name (`~/.config/natively`). The fix pins that exact location
   (respecting a pre-existing capitalized profile instead of orphaning
   it) BEFORE renaming, so no install loses settings, trial, or meetings.
2. **Stealth intact, other platforms untouched.** The early rename is
   Linux-only; disguise modes still rename later; macOS/Windows
   sequencing (which their dock behavior depends on) is not reordered.
3. **Contractual, not coincidental.** The WM_CLASS both sides agree on is
   written into the build config (`linux.desktop.entry.StartupWMClass`),
   not left to electron-builder defaults.
4. **Install-time robustness without session meddling.** The deb postinst
   hook only refreshes desktop/icon caches, every command guarded, and
   never touches running session processes.
5. **No repo-wide test/typecheck runs.** Verify with the focused suites in
   `verify.sh` only.

## Implementation notes

- `electron/main.ts`: right after `app.whenReady()`, Linux-only —
  pin userData, then `app.setName('Natively')`, both try/caught, both
  before any window exists.
- `package.json`: `linux.desktop.entry.StartupWMClass: "Natively"`;
  top-level `deb.afterInstall: "./scripts/deb-after-install.sh"`.
- `scripts/deb-after-install.sh` (new): `update-desktop-database`,
  `gtk-update-icon-cache`, `update-icon-caches`, all `|| true`, exit 0.
- `build.sh`: `chmod +x` the hook (patches are text-only and don't carry
  modes).
- Known limit: an AppImage run directly has no registered desktop file,
  so durable pinning needs the `.deb` (documented in CONSUME.md).
  Disguise modes intentionally break association while active (stealth).
- Tests: `LinuxDockAssociation.test.mjs` (pin-before-rename order,
  config contract, hook guards).
