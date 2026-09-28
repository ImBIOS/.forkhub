# Build triggers — github.com/pingdotgg/t3code

User-explicit choice (recorded 2026-09-24, ImBIOS; night train confirmed later same day):

- **Nightly check at 00:00 UTC+7 (17:00 UTC cron): build only untagged.**
  The shared workflow resolves the newest tag per configured train
  (`upstream.json:trains`: nightly only for now — stable building is
  disabled while the channel focuses on nightly + intent-patches) and
  the skip gate no-ops when that tag already has an updater or bundle
  release. No new tags = quiet green run, no noise, no compute beyond
  the check.
- **On intent change (push to `repos/**`): build** (same skip gate
  applies — a push with no new upstream tag only rebuilds with force).
- **Manual (`workflow_dispatch`, optional `target` filter, `force`
  flag): build.** Rebuilds and on-demand ForkHub releases; `force=true`
  rebuilds even an already-built tag.

To change the poll cadence, edit the cron in
`.github/workflows/forkhub-build.yml` (shared file — affects all targets).

Drift (apply or verify fails on a new tag) auto-dispatches ONE
`forkhub reimplement` run for that target+patch+tag, then fails the
build so the fresh realization rebuilds on promote. While a
`needs-human-decision` issue is open for the patch, no new runs
dispatch (no daily agent spend while a human decision is pending).
See `build/reimplement.md` for the flow and the human-decision protocol.
