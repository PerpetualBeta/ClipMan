import AppKit
import ApplicationServices

@Observable
final class PermissionsManager {
    private(set) var accessibilityGranted: Bool = false

    init() {
        checkAccessibility()
    }

    func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    /// Prompt the user to grant Accessibility permission.
    /// Opens System Settings to the relevant pane.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings → Privacy & Security → Accessibility
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
