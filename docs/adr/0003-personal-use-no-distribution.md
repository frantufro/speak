# Personal-use only: install via `bin/install`, no distribution infrastructure

speak is a personal tool for the author's own machine. There is no DMG, no code signing, no notarization, no Apple Developer Program membership, no GitHub Releases binary, and no auto-updater. Installation is a `bin/install` script that builds the `.app` from source (via `xcodebuild`) and copies it into `/Applications/`.

## Considered options

- **Personal-use install script (chosen)** — Zero distribution overhead. Locally-built apps aren't subject to Gatekeeper quarantine (the quarantine xattr is only set on downloaded files), so no signing dance. Re-running `bin/install` pulls the latest source and re-installs — that's the update mechanism.
- **Signed + notarized DMG on GitHub Releases** — The proper distribution path. Requires $99/yr Apple Developer membership and CI notarization pipeline. Rejected because there's no audience to distribute to yet.
- **Unsigned DMG on GitHub Releases** — Friend-distributable, but the first-launch warning ("speak can't be opened because Apple cannot check it") makes it user-hostile. Rejected.
- **Mac App Store** — Structurally impossible. App Store sandboxing blocks the Accessibility-based ⌘V synthesis and global hotkey monitoring speak requires. Same reason VoiceInk / MacWhisper / Superwhisper all ship outside the App Store.

## Consequences

- **No CI artifacts.** CI runs tests; it does not build a release binary. Saves time and complexity.
- **The update story is `git pull && bin/install`.** No Sparkle, no appcast, no in-app update prompt. Acceptable for a personal tool.
- **If this ever becomes a product, the missing distribution work is real.** Notarization pipeline, DMG creation, Sparkle integration, and signing infrastructure are all greenfield. Recorded here so future-me doesn't assume it was secretly done.
- **`/Applications/` requires admin on multi-user Macs.** The author's machine is single-user-admin, so this is fine. If the install ever needs to work for a non-admin user, fall back to `~/Applications/`.
