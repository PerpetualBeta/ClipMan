import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    @AppStorage("maxClipboardItems") private var maxItems: Int = 50
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    @State private var permissionsManager = PermissionsManager()

    var body: some View {
        Form {
            Section("General") {
                HStack {
                    Text("Clipboard buffer size")
                    Spacer()
                    Stepper(value: $maxItems, in: 10...500, step: 10) {
                        Text("\(maxItems) items")
                            .monospacedDigit()
                            .frame(width: 80, alignment: .trailing)
                    }
                }

                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section("Keyboard Shortcut") {
                HStack {
                    Text("Show clipboard history")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .showClipboardHistory)
                }
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

            Section("About") {
                HStack {
                    Text("ClipMan")
                    Spacer()
                    Text("Version 1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 340)
        .onAppear {
            permissionsManager.checkAccessibility()
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail — user can toggle again
            launchAtLogin = !enabled
        }
    }
}
