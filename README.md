# ClipMan

A lightweight macOS clipboard history manager that lives in the menu bar. Browse, search, pin, and paste from your clipboard history with keyboard shortcuts.

## Requirements

- macOS 14 (Sonoma) or later

## Installation

1. Double-click `ClipMan.app` to launch it
2. A clipboard icon appears in the menu bar


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
- **About** — version info
- **Quit**

## Permissions

- **Accessibility** — required for simulating paste keystrokes (⌘V) into the target application. macOS will prompt on first use.

## Architecture

| Component | Purpose |
|-----------|---------|
| `ClipManApp.swift` | Entry point, MenuBarExtra, AppDelegate with floating panel management |
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
./build.sh
open .build/ClipMan.app
```

### Dependencies

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus — global hotkey registration

---

ClipMan is provided by [Jorvik Software](https://jorviksoftware.cc/). If you find it useful, consider [buying me a coffee](https://jorviksoftware.cc/donate).
