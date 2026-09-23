# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Conventional Commits](https://www.conventionalcommits.org/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-09-23

### 🚀 Features

- *(voice)* Follow my words: on-device speech recognition keeps the line you are reading in view, follows skips and
  repeats, fades what you already read and marks the current word. Click a word to continue from there. Uses
  SpeechAnalyzer on macOS 26 (about 30 languages, downloaded once) and SFSpeechRecognizer before that
- *(app)* One app: the Scripts editor is now a window inside Notchy (⌘⇧R), no separate Notchy Scripts app
- *(settings)* New settings window in the PrimoDock / CameraMan / DailyNotch style, with search: Text (with a live
  preview), Scrolling, Voice, Notch, Editor, General, Shortcuts, About
- *(scripts)* Scripts window in the same style: full-height sidebar, script search, colored rows, new script and new
  folder at hand, export from the row menu
- *(app)* New app icon and menu bar icon
- *(app)* Signed with Developer ID and notarized; App Sandbox; hardened runtime; ready for the Mac App Store
- *(app)* DMG with an install background
- *(app)* GitHub update check in the menu bar and Settings → About (left out of the App Store build)
- *(app)* Open at login
- *(voice)* The chosen microphone is used by Notchy only; the Mac's default input is no longer changed
- *(prompter)* Shows over full-screen apps (Keynote, video calls)
- *(prompter)* Scripts button in the control bar

### 🐛 Bug Fixes

- *(prompter)* The text could be laid out above the visible area, so play jumped to the end and the text vanished
- *(prompter)* Scrolling by hand no longer fights the automatic scroll
- *(voice)* Turning voice off and on, or switching microphones, no longer crashes (the audio tap was installed twice)
- *(voice)* Voice scrolling picks up again after plugging or unplugging a microphone
- *(prompter)* Pasting into a script that already has text inserts it there instead of replacing the prompter with a
  new script that held only the pasted words
- *(prompter)* Typing with no script selected creates one instead of losing the text
- *(prompter)* Space and the arrow keys no longer get swallowed while you type in the prompter
- *(scripts)* Switching scripts right after typing no longer drops the last edits
- *(scripts)* Clearing a script's text no longer brings the old text back
- *(scripts)* Scripts are written atomically, and a file that can't be read is logged instead of silently skipped
- *(scripts)* Export all never deletes an earlier export, and scripts with the same title no longer overwrite each other
- *(settings)* Picking certain colors no longer crashes
- *(display)* "Screen with the menu bar" now means that screen, not the one with the key window
- *(app)* The "Open Scripts" menu item works in release builds
- *(l10n)* Every language has every string (English where a translation is missing)

## [0.1.0] - 2026-02-09

First release: voice-scrolled teleprompter in the notch, with the separate Notchy Scripts editor.
