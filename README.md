# ForkHub personal intents

Personal intent-patches managed with [forkhub](https://github.com/ImBIOS/forkhub) (`fh`).

Unlike the shared [`with-fh/.forkhub`](https://github.com/with-fh/.forkhub)
catalog (exactly one ForkHub-support patch per OSS), this repo holds
**upstream-bound personal patches**: fixes meant to be merged upstream,
each with a retirement path. They may `depends_on` shared-catalog
patches (pinned by repo commit + semver range) for full local builds.

Current entries:

| patch | tracks | retires when |
|---|---|---|
| `natively-pkg-no-maps-8dedeb5a` | [upstream PR #661](https://github.com/Natively-AI-assistant/natively-cluely-ai-assistant/pull/661) | upstream merges an equivalent maps exclusion |

Builds: `.github/workflows/forkhub-pr-build.yml` produces `pr-only`
(intent on stock) and `full` (shared support + personal intents)
try-builds and maintains one rolling comment on the tracked upstream
PR. Needs repo secret `UPSTREAM_COMMENT_TOKEN` (PAT, `public_repo`)
for the comment step.
