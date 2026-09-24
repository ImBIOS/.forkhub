## T3 Code x ForkHub — use this build

Patched T3 Code that updates from a ForkHub channel instead of upstream.

1. **Install** the `T3-Code-*-x64.AppImage` below (Linux; macOS/Windows
   build locally — see `build/BUILD.md`). It installs side-by-side with
   stock T3 Code as **T3 Code x ForkHub**.
2. Open **Settings → Version → Update track**, pick **ForkHub**.
3. Type the channel owner's profile/org name (e.g. `ImBIOS`), press
   **Check**. A valid channel shows its latest release tag.
4. The top-left brand reads **T3 Code x ForkHub** while the track is
   active. After each desktop update, run **Update all** to bring your
   connected T3 Code servers to the same version.

No published `.forkhub` releases for your account yet? Publish this
target's catalog (`fh publish`) and cut a release with the
`forkhub build` workflow — then anyone can point their ForkHub track at
you.
