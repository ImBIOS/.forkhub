# Acceptance Criteria — dsh-linux-support-placeholder (DRAFT, blocked)

The ImBIOS Linux fork-support patch for DeepSeek Harness Desktop.
Applies on top of `with-fh` `dsh-forkhub-support` (see `depends_on` in
`manifest.json`) — realization starts only after that patch merges.

## Must pass for promotion to APPLIED

1. **Deterministic Linux dock identity.** WM_CLASS / desktop-entry
   contract; postinst hook guarded.
2. **Linux desktop launches.** `dsh web` works on ArchLinux-class
   distros: `pty.node` resolves from `prebuilds/linux-x64` (no
   `Failed to load native module`), with a documented `base-devel`
   build fallback.
3. **Linux open-at-login round-trips.** Enabling writes exactly one
   autostart entry; disabling deletes it.
4. **Per-publisher credit.** About card shows the feed owner with
   working links; no hardcoded maintainer strings.
5. **No channel drift.** No feed/channel/updater defaults touched.
6. **Focused suites pass**: `verify.sh` exits 0. No repo-wide checks.

## How to verify

```sh
sh repos/github.com/deepseek-ai/deepseek-harness/patches/dsh-linux-support-00000000/verify.sh
```
