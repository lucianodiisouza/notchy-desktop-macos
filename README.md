# Notchy

A minimal teleprompter for Mac that lives in the notch. Your script scrolls when you speak and pauses when you stop—no buttons, no fuss.

**Free and open source.** No subscriptions, no accounts, no backend. Use it forever.

---

## What is Notchy?

Notchy is a menu-bar teleprompter for macOS. The text window sits in the **notch strip** (or in a thin strip at the top on Macs without a notch), so your script stays visible while you present. Scroll is **voice-activated**: the text moves while you talk and stops when you pause.

It comes as two apps:

- **Notchy** — The teleprompter (voice-controlled scroll, paste, settings).
- **Notchy Scripts** — Edit and manage scripts; they sync with the main app.

---

## Download & install

1. Go to **[Releases](https://github.com/oprimodev/notchy/releases)** and download the latest **Notchy-&lt;version&gt;.dmg**.
2. Open the DMG and drag **Notchy** and **Notchy Scripts** into **Applications**.
3. Launch **Notchy** from Applications (or Spotlight).

**Requirements:** macOS 13.0 or later. Microphone access is requested on first use (for voice-controlled scroll).

---

## How to use

1. **Launch Notchy** — The teleprompter window appears in the notch area.
2. **Paste your script** — Use **Cmd+V** or type directly in the window.
3. **Speak** — Text scrolls while you talk and pauses when you stop.
4. **Adjust** — Change scroll speed, font size, and color in **Notchy → Settings**, or use the shortcuts below.

### Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| **Cmd+V** | Paste |
| **Shift+Up / Shift+Down** | Decrease / increase scroll speed |
| **Cmd+0** | Reset scroll to top |

---

## Features

- **Voice-activated scroll** — Microphone level drives scrolling; short silence pauses.
- **Notch strip** — Window lives in the menu bar layer; on Macs without a notch, a thin top strip is used. Stays on all spaces.
- **Paste & edit** — Paste with Cmd+V or edit the script in the window.
- **Screen sharing** — Legacy capture APIs may show a black area instead of the window. Modern tools (Zoom, Meet, Teams, QuickTime, OBS) capture the full display, so the window may still be visible; for full invisibility, use a separate display (e.g. iPad or second monitor) for the script.

---

## Build from source

1. Open **Notchy.xcodeproj** in Xcode.
2. Select the **Notchy** scheme and run (**Cmd+R**).

**For developers:** build instructions, permissions, signing, DMG creation, and technical notes are in **[CONTRIBUTING.md](CONTRIBUTING.md)**.

---

## Contributing

Contributions are welcome. See **[CONTRIBUTING.md](CONTRIBUTING.md)** for the full workflow (fork, branch, PR) and for opening issues.

---

## License

This project is open source. See [LICENSE](LICENSE) for the exact terms.
