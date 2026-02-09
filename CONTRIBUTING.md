# Contributing to Notchy

Guide for anyone building the app or contributing code.

---

## Build and run

1. Open **Notchy.xcodeproj** in Xcode.
2. Select the **Notchy** scheme and run (**Cmd+R**).

Build and run both **Notchy** and **Notchy Scripts** schemes when working on shared behavior (scripts, App Group).

---

## Development notes

### Microphone permission

When running from Xcode, macOS may ask for microphone access every time you open the teleprompter; the system often doesn’t persist the choice for debug builds. To avoid that:

- Allow Notchy in **System Settings → Privacy & Security → Microphone**, or  
- Run the built app from the Products folder instead of using Run.

The app only requests microphone permission when voice-controlled scroll is enabled.

### App Group / “access data from other apps”

Notchy and Notchy Scripts share data via an App Group (scripts and language). The system may show a permission dialog. In development this can appear every time you launch one or both apps.

- The main app only accesses the shared container after launch (not immediately) to reduce prompts.
- If the dialog keeps appearing, allow the apps in **System Settings → Privacy & Security**, or run the release build from the Products folder (the system tends to persist the choice there).

### Signing (no paid Apple account needed)

The project uses your Xcode **Team** (any Apple ID, including free) to form a macOS-style App Group so the system does not show the dialog.

- Set **Signing & Capabilities → Team** for **both targets** to your Apple ID.
- If you don’t set a Team, the app falls back to `group.com.notchy` and the permission prompt may appear.
- No developer.apple.com or paid account is required for local development.

---

## Creating a DMG (release build)

From the repo root:

```bash
./scripts/create-dmg.sh          # → Notchy.dmg
./scripts/create-dmg.sh 1.0.0    # → Notchy-1.0.0.dmg
```

The script builds both apps in Release, stages them with an Applications symlink, and creates a compressed DMG. Locally it also arranges the Finder icon layout; in CI that step is skipped.

---

## Contributing workflow

1. **Fork** the repository and clone it locally.
2. **Create a branch** for your change (e.g. `fix/scroll-speed` or `feature/new-shortcut`).
3. **Make your changes** and ensure the project builds (Notchy and Notchy Scripts schemes).
4. **Open a pull request** with a clear description of what you changed and why.

We’re happy to consider bug fixes, improvements to docs or localization, and small feature ideas. For larger features, open an issue first to discuss.

---

## Opening issues

Use [GitHub Issues](https://github.com/oprimodev/notchy/issues) to:

- **Report bugs** — Include macOS version, steps to reproduce, and what you expected.
- **Suggest features or improvements** — Describe the use case and why it would help.

Please search existing issues first to avoid duplicates. The more detail you provide, the easier it is to help.

---

## Code of conduct

This project expects respectful, constructive behavior. Be kind to others; no harassment, trolling, or spam. Maintainers may remove or lock content that violates this.

---

## Technical notes

- **Notch:** Uses `NSScreen.safeAreaInsets` (macOS 12+) to size and position the window in the notch strip; fallback height when there is no notch. Window level is status bar so it sits in the menu bar layer.
- **Audio:** `AVAudioEngine` tap on the input node; simple level threshold with silence timeout for start/stop.
- **Window:** `sharingType = .none`, high window level (assistive tech), all spaces, stationary.
