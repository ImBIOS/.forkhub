---
id: fix-wayland-gc-sweep-crash-by-deferring-clipboard--7agfxbdk
title: Fix Wayland GC sweep crash by deferring clipboard initialization and disconnecting destroy handlers before disposal
target_repo: github.com/Tudmotu/gnome-shell-extension-clipboard-indicator
target_area: [.gitignore, extension.js]
status: applied
applied_upstream_pr: none
version: 1
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-08-24
last_realized_against_commit: c880c7f
verifies_with: bun test
---

## Intent

Fix Wayland GC sweep crash by deferring clipboard initialization and disconnecting destroy handlers before disposal

## Why

(Filled by user)

## Non-negotiables

(Filled by user)

## Implementation notes

(Filled by user — describe what was done)
