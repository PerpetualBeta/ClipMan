import SwiftUI
import KeyboardShortcuts

struct ClipManSettingsContent: View {
    @AppStorage("maxClipboardItems") private var maxItems: Int = 50
    @State private var permissionsManager = PermissionsManager()

    // Bridge: raw key code/modifiers for JorvikShortcutRecorder
    @State private var keyCode: UInt16 = Self.currentKeyCode()
    @State private var modifiers: NSEvent.ModifierFlags = Self.currentModifiers()

    var body: some View {
        Section("Clipboard") {
            HStack {
                Text("Buffer size")
                Spacer()
                Text("\(maxItems) items")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Stepper("", value: $maxItems, in: 10...500, step: 10)
                    .labelsHidden()
            }
        }

        Section("Keyboard Shortcut") {
            JorvikShortcutRecorder(
                label: "Show clipboard history",
                keyCode: $keyCode,
                modifiers: $modifiers,
                displayString: { Self.currentShortcutDescription() },
                onChanged: {
                    // Bridge back to KeyboardShortcuts package
                    var carbonMods = 0
                    if modifiers.contains(.command) { carbonMods |= 256 }
                    if modifiers.contains(.option) { carbonMods |= 2048 }
                    if modifiers.contains(.control) { carbonMods |= 4096 }
                    if modifiers.contains(.shift) { carbonMods |= 512 }

                    let shortcut = KeyboardShortcuts.Shortcut(
                        carbonKeyCode: Int(keyCode),
                        carbonModifiers: carbonMods
                    )
                    KeyboardShortcuts.setShortcut(shortcut, for: .showClipboardHistory)
                },
                onClear: {
                    // nil is how the KeyboardShortcuts package unregisters a
                    // Carbon hotkey. Zeroing the local state alongside it keeps
                    // the recorder's own view of "is anything set" honest, so
                    // the Clear button goes away with the shortcut.
                    KeyboardShortcuts.setShortcut(nil, for: .showClipboardHistory)
                    keyCode = 0
                    modifiers = []
                },
                onRecordingChanged: { recording in
                    // The shortcut is registered as a Carbon hotkey by the
                    // KeyboardShortcuts package, which consumes the keystroke
                    // before the recorder sees it — so pressing the shortcut
                    // already set would open the history window instead of
                    // being recorded, and could never be changed.
                    if recording {
                        KeyboardShortcuts.disable(.showClipboardHistory)
                    } else {
                        KeyboardShortcuts.enable(.showClipboardHistory)
                    }
                }
            )
        }

        Section("Permissions") {
            HStack {
                VStack(alignment: .leading) {
                    Text("Accessibility")
                        .font(.body)
                    Text("Required to paste items into other apps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if permissionsManager.accessibilityGranted {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Grant Access") {
                        permissionsManager.requestAccessibility()
                    }
                }
            }
        }
        .onAppear {
            permissionsManager.checkAccessibility()
        }
    }

    private static func currentShortcutDescription() -> String {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .showClipboardHistory) {
            return "\(shortcut)"
        }
        return "Not set"
    }

    /// Zero when nothing is bound, not a plausible-looking default.
    ///
    /// These two seed the recorder's bindings, and the recorder decides whether
    /// to offer Clear from them. Returning ⌥⌘V for an unset shortcut put a
    /// Clear button next to the words "Not set", which is the same contradiction
    /// Save Cannes had.
    private static func currentKeyCode() -> UInt16 {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .showClipboardHistory) {
            return UInt16(shortcut.carbonKeyCode)
        }
        return 0
    }

    private static func currentModifiers() -> NSEvent.ModifierFlags {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .showClipboardHistory) {
            return shortcut.modifiers
        }
        return []
    }
}
