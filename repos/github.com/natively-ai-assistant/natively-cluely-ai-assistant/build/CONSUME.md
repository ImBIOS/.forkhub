# Natively ForkHub — use this build (Linux)

Patched Natively that updates from the ForkHub catalog instead of upstream.
Same app, same data — installing it replaces a stock install and keeps
everything, then it self-updates from here.

1. **Install** the `Natively-*-x86_64.AppImage` below (or the `.deb`).
   First run: `chmod +x Natively-*.AppImage && ./Natively-*.AppImage`.
2. **Trial works out of the box** — no sign-in; the free trial binds to
   this device via the open-source hardware-ID fallback.
3. **Updates are automatic**: Settings → Version → Check. New ForkHub
   builds install in place and relaunch (Linux needs no signing).

System audio capture on Linux follows upstream requirements (PipeWire);
if the source tarball is all you need, the matching
`natively-ai-assistant-natively-cluely-ai-assistant-*-fh*` bundle release
carries the verified patched source + build log.

No published `.forkhub` releases for your account yet? Publish this
target's catalog (`fh publish`) and cut a release with the
`forkhub build` workflow — then anyone can install the ForkHub build.
