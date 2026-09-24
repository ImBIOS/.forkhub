# Build triggers — github.com/pingdotgg/t3code

User-explicit choice (recorded 2026-09-24, ImBIOS):

- **On intent change (push to `repos/**`): build.** A changed intent must
  produce a fresh verified bundle immediately.
- **Daily upstream poll (06:00 UTC cron): build on new stable tags only.**
  `upstream.json:tag_ignore_pattern` keeps the shared clone step off the
  `-nightly`/`-preview` maintainer trains; a failed apply on drift is the
  signal to re-derive, not to hand-patch.
- **Manual (`workflow_dispatch`, optional `target` filter): build.**
  Used for rebuilds and for cutting a ForkHub release on demand.

To change the poll cadence, edit the cron in
`.github/workflows/forkhub-build.yml` (shared file — affects all targets).
