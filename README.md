# Notchy

**Free and open source.** A minimal teleprompter for Mac that lives in the notch (menu bar strip). Text scrolls when you speak and pauses when you stop. On Macs without a notch, it uses a thin strip at the top.

No subscriptions, no accounts, no backend—Notchy is free to use, forever.

## Features

- **Voice-activated scroll** — Microphone level controls scrolling; pauses after a short silence.
- **Paste text** — Use Cmd+V or edit directly in the window.
- **Position** — Window lives in the notch strip (same layer as the menu bar); on Macs without a notch, a thin strip at the top is used. Stays on all spaces and is repositioned when the screen layout changes.
- **Screen sharing** — The app sets `NSWindow.sharingType = .none` so that **legacy** screen capture APIs (e.g. some browser-based sharing) may show a black rectangle instead of the window. **Important:** Modern capture (Zoom, Meet, Teams, QuickTime, OBS, ScreenCaptureKit) captures the composited display, so there is **no public API** to hide this window in those apps; it may still be visible. For guaranteed invisibility, use a separate display (e.g. iPad or second monitor) for the script.

## Requirements

- macOS 13.0 or later
- Microphone permission (requested on first run)

## Build and run

1. Open `Notchy.xcodeproj` in Xcode.
2. Select the Notchy scheme and run (Cmd+R).

**Development:** When running from Xcode, macOS may ask for microphone access every time you open the teleprompter (the system often doesn’t persist the choice for debug builds). To avoid that, either allow Notchy in **System Settings → Privacy & Security → Microphone**, or run the built app from the Products folder instead of using Run. The app only requests microphone permission when voice-controlled scroll is enabled.

When you use both **Notchy** and **Notchy Scripts**, the system may show a permission dialog like “access data from other apps” (they share data via an App Group for scripts and language). In development this can appear every time you launch one or both apps. To reduce prompts, the main app only accesses the shared container after launch (not in the first line of code). If the dialog keeps appearing, allow the apps in **System Settings → Privacy & Security** (or run the release build from the Products folder, where the system tends to persist the choice).

**No paid Apple account needed.** The project uses your Xcode **Team** (any Apple ID, including free) to form a "macOS-style" App Group so the system does not show the dialog. Set **Signing & Capabilities → Team** for both targets to your Apple ID. If you don't set a Team, the app falls back to `group.com.notchy` and the prompt may appear. There is no dedicated toggle in System Settings; this setup avoids the dialog without developer.apple.com or a paid account.

## Usage

1. Launch Notchy. The window appears in the notch (top strip).
2. Paste or type your script (Cmd+V).
3. Speak; the text scrolls while you talk and stops when you pause.
4. Adjust scroll speed, font size, and color in **Notchy > Settings** (or via keyboard shortcuts).

## Keyboard shortcuts

- **Cmd+V** — Paste
- **Shift+Up / Shift+Down** — Decrease / increase scroll speed
- **Cmd+0** — Reset scroll to top

## Contributing

Contributions are welcome. To contribute:

1. **Fork** the repository and clone it locally.
2. **Create a branch** for your change (e.g. `fix/scroll-speed` or `feature/new-shortcut`).
3. **Make your changes** and ensure the project builds (Xcode, Notchy + Notchy Scripts schemes).
4. **Open a pull request** with a clear description of what you changed and why.

We’re happy to consider bug fixes, improvements to docs or localization, and small feature ideas. For larger features, open an issue first to discuss.

## Opening issues

Use [GitHub Issues](https://github.com/oprimodev/notchy/issues) to:

- **Report bugs** — Include macOS version, steps to reproduce, and what you expected.
- **Suggest features or improvements** — Describe the use case and why it would help.

Please search existing issues first to avoid duplicates. The more detail you provide, the easier it is to help.

## Code of conduct

This project expects respectful, constructive behavior. Be kind to others; no harassment, trolling, or spam. Maintainers may remove or lock content that violates this.

## License

This project is open source. See the [LICENSE](LICENSE) file in the repository for the exact terms.

## Technical notes

- **Notch:** Uses `NSScreen.safeAreaInsets` (macOS 12+) to size and position the window in the notch strip; fallback height when there is no notch. Window level is status bar so it sits in the menu bar layer.
- **Audio:** `AVAudioEngine` tap on the input node; simple level threshold with silence timeout for start/stop.
- **Window:** `sharingType = .none`, high window level (assistive tech), all spaces, stationary.
