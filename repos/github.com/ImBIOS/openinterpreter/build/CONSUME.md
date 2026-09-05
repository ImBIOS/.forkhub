---
target: github.com/ImBIOS/openinterpreter
tag_pattern: imbios-openinterpreter-<upstreamTag>-fh<N>
artifacts: [patched-source-tarball]
---

## Install

```bash
TAG=imbios-openinterpreter-vX.Y.Z-fh1  # pick a tag from Releases
curl -fsSL "https://github.com/<user>/.forkhub/releases/download/$TAG/imbios-openinterpreter-patched-source.tar.gz" -o app.tar.gz
sha256sum -c SHA256SUMS  # from the same Release
tar -xzf app.tar.gz
```

## Verify

Run the upstream's own checks plus each patch's `verify.sh` criteria
(see `../patches/*/ACCEPTANCE.md`).

## Run

Repo-specific — document the binary/container/page entrypoint here.
(Agent: fill this in when you write `build.sh`.)
