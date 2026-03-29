import SwiftUI
import SwiftData
import KeyboardShortcuts

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]

    let pasteEngine: PasteEngine
    let onShowHistory: () -> Void
    let onShowSettings: () -> Void
    let onShowAbout: () -> Void

    var body: some View {
        Button("About ClipMan") {
            onShowAbout()
        }

        Divider()

        Button("Show Clipboard History...") {
            onShowHistory()
        }
        .modifier(DynamicShortcutModifier(name: .showClipboardHistory))

        Button("Clear History") {
            clearHistory()
        }
        .disabled(items.isEmpty)

        Divider()

        Button("Settings...") {
            onShowSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit ClipMan") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private func clearHistory() {
        for item in items where !item.isPinned {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}

/// Reads the current KeyboardShortcuts shortcut and applies it as a native SwiftUI `.keyboardShortcut()`
private struct DynamicShortcutModifier: ViewModifier {
    let name: KeyboardShortcuts.Name

    func body(content: Content) -> some View {
        if let shortcut = KeyboardShortcuts.getShortcut(for: name),
           let equiv = shortcut.keyEquivalent,
           let mods = shortcut.eventModifiers {
            content.keyboardShortcut(equiv, modifiers: mods)
        } else {
            content
        }
    }
}

extension KeyboardShortcuts.Shortcut {
    /// Convert to SwiftUI KeyEquivalent
    @MainActor
    var keyEquivalent: KeyEquivalent? {
        if let keyString = nsMenuItemKeyEquivalent, let char = keyString.first {
            return KeyEquivalent(char)
        }
        return nil
    }

    /// Convert NSEvent.ModifierFlags to SwiftUI EventModifiers
    var eventModifiers: EventModifiers? {
        var result = EventModifiers()
        if modifiers.contains(.command) { result.insert(.command) }
        if modifiers.contains(.option) { result.insert(.option) }
        if modifiers.contains(.shift) { result.insert(.shift) }
        if modifiers.contains(.control) { result.insert(.control) }
        return result
    }
}
