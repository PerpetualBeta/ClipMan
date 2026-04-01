import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
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
                Stepper(value: $maxItems, in: 10...500, step: 10) {
                    Text("\(maxItems) items")
                        .monospacedDigit()
                        .frame(width: 80, alignment: .trailing)
                }
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

    private static func currentKeyCode() -> UInt16 {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .showClipboardHistory) {
            return UInt16(shortcut.carbonKeyCode)
        }
        return 9 // V
    }

    private static func currentModifiers() -> NSEvent.ModifierFlags {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .showClipboardHistory) {
            return shortcut.modifiers
        }
        return [.option, .command]
    }
}
