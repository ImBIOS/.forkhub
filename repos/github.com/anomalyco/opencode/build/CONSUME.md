## OpenCode x ForkHub — use this build

Patched OpenCode that updates from a ForkHub channel instead of upstream.
Base is the **Latest/Prod** release train.

1. **Desktop**: install the `opencode-desktop-*-x86_64.AppImage` below
   (Linux; macOS/Windows build locally — see `build/BUILD.md`). It installs
   side-by-side with stock OpenCode as **OpenCode x ForkHub**
   (`ai.opencode.desktop.forkhub.imbios.latest`).
2. Open **Settings → General → Updates → Update track**, pick **ForkHub**.
3. Type the channel owner's profile/org name (e.g. `ImBIOS`), press
   **Check**. A valid channel shows its latest release tag.
4. The titlebar reads **x ForkHub** while the track is active.
5. **CLI**: `npm i -g @imbios/with-fh-opencode-ai@latest` (once the first
   token-backed build publishes it; until then use the CLI tarballs
   attached to the bundle release).

No published `.forkhub` releases for your account yet? Publish this
target's catalog (`fh publish`) and cut a release with the
`forkhub build` workflow — then anyone can point their ForkHub track at
you.
