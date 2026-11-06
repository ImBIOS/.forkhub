# ImBIOS ForkHub intents

Intent-patches managed with [forkhub](https://github.com/ImBIOS/forkhub) (`fh`).

Unlike the shared [`with-fh/.forkhub`](https://github.com/with-fh/.forkhub)
catalog (exactly one ForkHub update-channel patch per OSS), this repo
holds the **Linux support patch** for Natively: dock identity,
system-audio capture, open-at-login, deb packaging, and dynamic
per-publisher credit. It `depends_on` the shared-catalog channel patch
(pinned by repo commit + semver range), so the combined ImBIOS build
carries the full channel + Linux stack.

Current entries:

| patch | depends on | notes |
|---|---|---|
| `natively-linux-support-9d3f7a21` | `with-fh/.forkhub` `natively-forkhub-support-f276ae13` >=2.0.0 <3.0.0 | Linux support; combined build = channel + Linux |

Builds: `.github/workflows/forkhub-pr-build.yml` builds stock upstream
+ channel + linux-support (stamped `NATIVELY_UPDATE_OWNER=ImBIOS`),
packs AppImage + deb, and publishes to this repo's releases (the ImBIOS
update catalog). Needs repo secrets `NATIVELY_GOOGLE_CLIENT_ID` /
`NATIVELY_GOOGLE_CLIENT_SECRET` for working fork calendar.
