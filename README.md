# ClipMan

A lightweight macOS clipboard history manager that lives in the menu bar. Browse, search, pin, and paste from your clipboard history with keyboard shortcuts.

## Requirements

- macOS 14 (Sonoma) or later

## Installation

Two formats on every release — both signed and notarised, pick whichever suits:

- **[Installer (`.pkg`)](https://github.com/PerpetualBeta/ClipMan/releases/latest/download/ClipMan.pkg)** — recommended for first-time installs. Double-click to run; macOS Installer places the app in `/Applications` without quarantine or App Translocation.
- **[Download (`.zip`)](https://github.com/PerpetualBeta/ClipMan/releases/latest)** — unzip and drag `ClipMan.app` to your Applications folder.

After installation, launch ClipMan — a clipboard icon appears in the menu bar.


## How It Works

ClipMan monitors the system pasteboard every 0.5 seconds. When it detects a change, it captures the content — text, rich text, images, or file references — and stores it using SwiftData for persistence across sessions.

### Browsing History

Press **⌥⌘V** (Option-Command-V) to open the clipboard browser, a floating panel that shows your history. Navigate with:

| Key | Action |
|-----|--------|
| **←** / **→** | Browse older / newer items |
| **Return** | Paste selected item |
| **Shift+Return** | Paste and match style |
| **Escape** | Dismiss browser |

The browser also has on-screen controls for navigation, pinning, and deleting items.

### Content Types

ClipMan captures:
- **Plain text** — standard clipboard text
- **Rich text** — preserves RTF formatting, with paste-and-match-style option
- **Images** — TIFF and PNG data from screenshots, copied images, etc.
- **Files** — file URLs from Finder copies, displayed by filename

### Pinning

Pin important items to keep them at the top of your history. Pinned items are never trimmed by the history limit.

### History Limit

By default, ClipMan keeps the most recent 50 items (configurable from 10 to 500 in Settings). Older unpinned items are trimmed automatically.

### Deduplication

If you copy the same content twice in a row, ClipMan won't create a duplicate entry.

## Menu Bar

Click the clipboard icon in the menu bar for quick access to:
- **Browse History** — opens the floating browser panel
- **Settings** — configure history limit and keyboard shortcut
- **Check for Updates…** — Sparkle-driven update check
- **About** — version info
- **Quit**

## Settings

Right-click the clipboard icon in the menu bar and choose **Settings…** to configure:

- **Clipboard buffer size** — keep between 10 and 500 items (default 50)
- **Keyboard shortcut** — customise the global hotkey for opening the clipboard browser
- **Accessibility permission** — status display and grant button (required for paste simulation)
- **Show icon in menu bar** — hide the menu-bar icon while ClipMan keeps running (still reachable via its keyboard shortcut). Your choice persists across launches, including login auto-start. *Shown only on macOS 14–15 — on macOS 26 (Tahoe) and later, use System Settings → Menu Bar, which provides this natively.*
- **Menu bar icon pill** — optional grey background for stronger contrast on busy or wallpaper-tinted menu bars (off by default)
- **Launch at Login** — start ClipMan automatically when you log in

If you've hidden the status icon and want it back, simply re-open ClipMan from your Applications folder — it reappears immediately.

Auto-updates are handled by Sparkle. Use the **Check for Updates…** entry in the menu to check on demand; Sparkle's prompt offers an "Automatically download and install updates in the future" checkbox the first time an update is available.

## Quitting

Right-click the clipboard icon in the menu bar and choose **Quit ClipMan**. If you've hidden that icon, re-open ClipMan from your Applications folder first to bring it back, then quit from the menu.

## Permissions

- **Accessibility** — required for simulating paste keystrokes (⌘V) into the target application. macOS will prompt on first use.

## Architecture

| Component | Purpose |
|-----------|---------|
| `ClipManApp.swift` | Entry point; AppDelegate owning the menu-bar `NSStatusItem`, dynamic NSMenu, and floating panel management |
| `ClipboardMonitor.swift` | Polls NSPasteboard, captures content, deduplicates, trims history |
| `PasteEngine.swift` | Places items on pasteboard and simulates ⌘V / ⌥⇧⌘V keystrokes |
| `ClipboardBrowserView.swift` | SwiftUI floating browser with navigation, pin, delete |
| `ClipboardItemPreview.swift` | Renders text, image, and file previews |
| `ClipboardItem.swift` | SwiftData model — content, RTF, image data, file URLs, pin state |
| `SettingsView.swift` | History limit and hotkey configuration |
| `KeyboardShortcutConfig.swift` | Global hotkey registration via KeyboardShortcuts package |

## Building from Source

ClipMan uses Swift Package Manager. No Xcode project is required.

```bash
git clone https://github.com/PerpetualBeta/ClipMan.git
cd ClipMan
gmake build
open .build/ClipMan.app
```

Requires GNU Make 4.x — `brew install make` installs it as `gmake`.

### Dependencies

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus — global hotkey registration

---

ClipMan is provided by [Jorvik Software](https://jorviksoftware.cc/). If you find it useful, consider [buying me a coffee](https://jorviksoftware.cc/donate).
