# Acceptance Criteria — natively-linux-dock-icon-a7e2c41b

## Must pass for promotion to APPLIED

1. **Deterministic identity.** On Linux the app pins userData before
   renaming, renames before any window exists, and both are Linux-gated
   (`LinuxDockAssociation.test.mjs`).
2. **Contract on both sides.** Build config declares
   `StartupWMClass: "Natively"` and a `deb.afterInstall` hook whose
   script exists, refreshes caches, guards every command, and touches no
   session processes (`LinuxDockAssociation.test.mjs`).
3. **Stealth preserved.** Disguise renames still apply later; macOS and
   Windows code paths untouched (`LinuxDockAssociation.test.mjs`).
4. **No profile moves.** Historical lowercase location pinned; a
   pre-existing capitalized profile respected, never orphaned (by
   construction in code; assert order in tests).
5. **Focused suites pass**: `verify.sh` exits 0. No repo-wide checks.
6. **Applies after patches 1+2**: reference applies onto the
   update-track + ux-and-checks realization (manifest `apply_order`).
7. **Human check (post-install):** install the `.deb`, launch, confirm
   the Natively icon in the dock and "Add to Favorites"/pin offered;
   AppImage-run-directly remains unpinnable by design (documented).

## How to verify

```bash
sh repos/github.com/natively-ai-assistant/natively-cluely-ai-assistant/patches/natively-linux-dock-icon-a7e2c41b/verify.sh
```
