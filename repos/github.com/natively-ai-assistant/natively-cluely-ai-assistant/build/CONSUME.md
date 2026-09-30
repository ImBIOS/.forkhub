# Natively ForkHub — use this build (Linux)

Patched Natively that updates from the ForkHub catalog instead of upstream.
Same app, same data — installing it replaces a stock install and keeps
everything, then it self-updates from here.

1. **Install** the `natively_*_amd64.deb` below (recommended — registers
   with the desktop so the dock shows the icon and offers pin-to-dock),
   or the `Natively-*-x86_64.AppImage` (`chmod +x`, then run; an AppImage
   run directly has no registered desktop entry, so durable pinning needs
   the `.deb`).
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
