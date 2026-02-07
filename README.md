# Notchy

A minimal teleprompter for Mac that lives in the notch (menu bar strip). Text scrolls when you speak and pauses when you stop. On Macs without a notch, it uses a thin strip at the top.

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

## Usage

1. Launch Notchy. The window appears in the notch (top strip).
2. Paste or type your script (Cmd+V).
3. Speak; the text scrolls while you talk and stops when you pause.
4. Adjust scroll speed, font size, and color in **Notchy > Settings** (or via keyboard shortcuts).

## Keyboard shortcuts

- **Cmd+V** — Paste
- **Shift+Up / Shift+Down** — Decrease / increase scroll speed
- **Cmd+0** — Reset scroll to top

## Technical notes

- **Notch:** Uses `NSScreen.safeAreaInsets` (macOS 12+) to size and position the window in the notch strip; fallback height when there is no notch. Window level is status bar so it sits in the menu bar layer.
- **Audio:** `AVAudioEngine` tap on the input node; simple level threshold with silence timeout for start/stop.
- **Window:** `sharingType = .none`, high window level (assistive tech), all spaces, stationary.
