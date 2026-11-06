---
id: dsh-linux-support-placeholder
title: DeepSeek Harness Desktop Linux support (DRAFT — blocked on the with-fh channel patch)
target_repo: github.com/deepseek-ai/deepseek-harness
target_area: [apps/desktop/electron-builder.config.mjs, apps/desktop/scripts/package-target.ts, apps/desktop/scripts/desktop-build-paths.mjs, apps/desktop/packaging, package.json]
status: draft
applied_upstream_pr: none
version: 0.1.0
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-11-06
last_realized_against_commit: null
verifies_with: node --test (focused suites, see verify.sh)
upstream_stars: 274517
star_gate: ">=2000 PASS (274517 recorded 2026-11-06)"
depends_on_note: "Applies ONLY on top of the with-fh/.forkhub update-channel patch (see manifest depends_on) — never on stock. Ref is null until the with-fh dsh channel patch merges; then pin it like natively-linux-support pins ae111a3."
---

## Intent

Linux support for the ForkHub DeepSeek Harness Desktop build. Applies
ONLY on top of the `with-fh/.forkhub` update-channel patch — never on
stock. Together they reproduce the upstream mac/Windows behavior on
Linux, with one addition: per-publisher credit that follows the update
publisher dynamically.

Blocked today: the with-fh dsh channel patch has no release yet, so
this patch and its `dsh-linux` registry entry cannot resolve. This
placeholder records the verified shape so the work starts from facts.

1. **Linux desktop packaging.** New `linux-x64` target alongside the
   verified upstream `mac-arm64 | mac-x64 | win-x64`
   (`package-target.ts`, `desktop-build-paths.mjs` `SUPPORTED_TARGETS`,
   `upload:linux:x64` script): AppImage + deb, XDG desktop-entry +
   WM_CLASS contract, deb postinst hook, open-at-login entry.
2. **node-pty linux-x64 prebuilds.** Discussion #49 root cause:
   `Failed to load native module: pty.node, checked: ...,
   prebuilds/linux-x64`. Ship (or build in CI) the linux-x64 prebuilds
   so `dsh web` works on ArchLinux and friends; document the
   `base-devel` build fallback.
3. **Per-publisher credit (dynamic).** About/support links follow the
   update publisher (`{owner}/.forkhub` catalog) — never hardcoded.
4. **No channel drift.** This patch contains no feed/channel/updater
   changes; the `with-fh` feed default is untouched by this diff.

## Non-negotiables

1. Applies only on stock+channel checkout (channel patch pinned in
   manifest `depends_on` before realization).
2. Exactly one open-at-login entry; `~/.config/autostart` honored.
3. Credit derives from the live update feed, never hardcoded.
4. Secrets never committed.
5. Focused suites in `verify.sh` only (assumes the channel patch applied).

## Re-derivation instruction

Realize via `fh draft` only AFTER the with-fh dsh channel patch merges
and publishes its first release: pin its commit in manifest
`depends_on` (ref + `>=0.1.0 <1.0.0` range, enforced by the ImBIOS
pr-build range check), implement, write focused suites, `fh satisfied`.
Then add the `dsh-linux` entry to ImBIOS `registry.json`.
