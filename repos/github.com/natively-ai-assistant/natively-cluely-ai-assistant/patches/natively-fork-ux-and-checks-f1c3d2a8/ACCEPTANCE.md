# Acceptance Criteria — natively-fork-ux-and-checks-f1c3d2a8

## Must pass for promotion to APPLIED

1. **Calendar direct auth is real.** `createPkcePair` yields a 43–128 char
   verifier whose S256 challenge recomputes independently; exchange and
   refresh POST form-encoded to `oauth2.googleapis.com/token` with no
   `client_secret` sent (`CalendarPkce.test.mjs`).
2. **Stock paths unchanged.** Proxy exchange/refresh call sites intact;
   direct branches run only with a fork/baked id or explicit direct env;
   placeholder still refuses with a readable error
   (`ForkPatch2Sources.test.mjs`).
3. **Check is total.** Updater rejection and async check-errors fall back
   to the catalog compare exactly once; download errors still broadcast;
   unreachable feed broadcasts instead of hanging
   (`ForkPatch2Sources.test.mjs`).
4. **Fund + credit.** Support opens both the original and the sponsors
   URL; the maintainer card shows name, badge, bio, and both links
   (`ForkPatch2Sources.test.mjs`).
5. **Button honesty.** Connect failures render text instead of dying
   silently (`ForkPatch2Sources.test.mjs`).
6. **Focused suites pass**: `verify.sh` exits 0. No repo-wide checks.
7. **Applies after patch 1**: reference applies onto the update-track
   realization (manifest `apply_order`).

## How to verify

```bash
sh repos/github.com/natively-ai-assistant/natively-cluely-ai-assistant/patches/natively-fork-ux-and-checks-f1c3d2a8/verify.sh
```
