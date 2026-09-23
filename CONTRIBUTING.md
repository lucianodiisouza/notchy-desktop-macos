# Contributing to Notchy

Guide for anyone building the app or contributing code.

---

## Build and run

1. Open **Notchy.xcodeproj** in Xcode.
2. Select the **Notchy** scheme and run (⌘R).

Or `./scripts/run.sh`. The project uses a synchronized folder, so new files under `Notchy/` are picked up without
editing the project.

---

## Development notes

### Sandbox and data

Notchy runs in the App Sandbox (required by the Mac App Store).

- **Settings** live in `~/Library/Containers/dev.oprimo.notchyPrompter`. On the first sandboxed launch, macOS moves
  the settings of versions before 1.0 there (`Notchy/Resources/container-migration.plist`).
- **Scripts** live in the App Group container `~/Library/Group Containers/TJ7XUV6VQ9.com.notchy/Scripts`, one JSON
  file per script, where earlier versions (and the old Notchy Scripts app) kept them.

`./scripts/wipe.sh` removes both, plus the microphone and speech recognition permissions.

### Microphone and speech recognition

The app asks for the microphone when voice is on and the prompter is open, and for speech recognition the first time
"Follow my words" starts. Debug builds are signed with your Apple Development certificate, so macOS remembers the
answers between runs.

"Follow my words" (`Features/Teleprompter/SpeechFollower.swift`) uses SpeechAnalyzer + SpeechTranscriber on macOS 26
and SFSpeechRecognizer (on-device only) before that. The matching lines up the last few recognized words with a
window of the script around the current position.

A Debug-only launch argument opens a window on launch, handy for screenshots:

```bash
open Notchy.app --args -NotchyDebugOpen settings.voice   # or settings.<page>, or scripts
```

### Icon and DMG artwork

Both are drawn in code; change the Swift and run again from the repo root:

```bash
swift scripts/generate-icon.swift             # app icon, menu bar icon, docs/icon.png
swift scripts/generate-dmg-background.swift   # scripts/dmg/background.tiff
```

---

## Releasing

### Direct download (Developer ID, notarized)

One-time setup:

```bash
brew install create-dmg
xcrun notarytool store-credentials <profile-name>   # Apple ID, team, app-specific password
```

Then create `.env.local` at the repo root (git-ignored):

```bash
NOTCHY_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
NOTCHY_NOTARY_PROFILE="<profile-name>"
```

and run:

```bash
./scripts/create-dmg.sh
```

It builds Release, signs with the hardened runtime and `Notchy.entitlements`, notarizes and staples the app, wraps it
in a DMG with the install background, then notarizes and staples the DMG. Output: `build/Notchy-<version>.dmg`.
Without the two variables it still produces a DMG, ad-hoc signed, for local tests only.

The version comes from `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in the project. Tag the release `vX.Y.Z` and
upload the DMG to GitHub Releases; the update check reads the latest release.

### Mac App Store

```bash
./scripts/appstore.sh            # archive and export a signed .pkg into build/appstore (nothing is uploaded)
./scripts/appstore.sh --upload   # archive and upload to App Store Connect
```

The App Store build compiles with `APPSTORE` (no GitHub update check) and uses `Notchy-AppStore.entitlements` (no
network). Store listing text and review notes are in [appstore/LISTING.md](appstore/LISTING.md).

---

## Contributing workflow

1. **Fork** the repository and clone it locally.
2. **Create a branch** for your change (e.g. `fix/scroll-speed` or `feature/new-shortcut`).
3. **Make your changes** and make sure the project builds.
4. **Open a pull request** with a clear description of what you changed and why.

Bug fixes, docs, translations and small features are welcome. For larger features, open an issue first.

### Translations

Strings are in `Notchy/Resources/<language>.lproj/Localizable.strings`. English and Brazilian Portuguese are
complete. The other languages have a block at the end marked "Not translated yet" with English text; translating
those lines is an easy first contribution.

---

## Opening issues

Use [GitHub Issues](https://github.com/lucianodiisouza/notchy-desktop-macos/issues) to report bugs (macOS version,
steps to reproduce, what you expected) or suggest features. Please search existing issues first.

---

## Code of conduct

Be kind and constructive; no harassment, trolling or spam. Maintainers may remove or lock content that breaks this.
