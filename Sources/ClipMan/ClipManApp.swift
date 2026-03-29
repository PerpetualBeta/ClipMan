import SwiftUI
import SwiftData
import KeyboardShortcuts

@main
struct ClipManApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("ClipMan", systemImage: "clipboard") {
            MenuBarView(
                pasteEngine: appDelegate.pasteEngine,
                onShowHistory: { appDelegate.toggleBrowser() },
                onShowSettings: { appDelegate.openSettings() },
                onShowAbout: { appDelegate.openAbout() }
            )
            .modelContainer(appDelegate.modelContainer)
        }
    }
}

// MARK: - Floating Panel (can become key even when borderless)

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 123: // left arrow
            NotificationCenter.default.post(name: .browserNavigate, object: "left")
        case 124: // right arrow
            NotificationCenter.default.post(name: .browserNavigate, object: "right")
        case 53: // escape
            NotificationCenter.default.post(name: .dismissClipboardBrowser, object: nil)
        case 36: // return
            let matchStyle = event.modifierFlags.contains(.shift)
            NotificationCenter.default.post(name: .browserPaste, object: matchStyle)
        default:
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        NotificationCenter.default.post(name: .dismissClipboardBrowser, object: nil)
    }
}

extension Notification.Name {
    static let dismissClipboardBrowser = Notification.Name("dismissClipboardBrowser")
    static let browserNavigate = Notification.Name("browserNavigate")
    static let browserPaste = Notification.Name("browserPaste")
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let clipboardMonitor = ClipboardMonitor()
    private(set) lazy var pasteEngine = PasteEngine(monitor: clipboardMonitor)
    private var browserPanel: FloatingPanel?
    private var isBrowserVisible = false
    private var clickOutsideMonitor: Any?
    private var previousApp: NSRunningApplication?

    let modelContainer: ModelContainer = {
        let schema = Schema([ClipboardItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let context = ModelContext(modelContainer)
        clipboardMonitor.start(modelContext: context)

        let permissions = PermissionsManager()
        if !permissions.accessibilityGranted {
            permissions.requestAccessibility()
        }

        KeyboardShortcuts.onKeyUp(for: .showClipboardHistory) { [weak self] in
            Task { @MainActor in
                self?.toggleBrowser()
            }
        }

        // Listen for escape key dismissal from the panel
        NotificationCenter.default.addObserver(
            forName: .dismissClipboardBrowser,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dismissBrowser()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
    }

    // MARK: - Browser Panel

    func toggleBrowser() {
        if isBrowserVisible {
            dismissBrowser()
        } else {
            presentBrowser()
        }
    }

    // MARK: - Settings Window

    private var settingsWindow: NSWindow?

    func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .frame(width: 420, height: 340)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "ClipMan Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    // MARK: - About Window

    private var aboutWindow: NSWindow?

    func openAbout() {
        if let existing = aboutWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutView = AboutView()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "About ClipMan"
        window.contentView = NSHostingView(rootView: aboutView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow = window
    }

    // MARK: - Browser Presentation

    private func presentBrowser() {
        isBrowserVisible = true

        // Remember the frontmost app so we can re-activate it after paste
        previousApp = NSWorkspace.shared.frontmostApplication

        let browserView = ClipboardBrowserView(
            onDismiss: { [weak self] in self?.dismissBrowser() },
            onPaste: { [weak self] item, matchStyle in self?.pasteItem(item, matchStyle: matchStyle) },
            pasteEngine: pasteEngine
        )
        .modelContainer(modelContainer)

        let hostingView = NSHostingView(rootView: browserView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 12
        hostingView.layer?.masksToBounds = true

        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = hostingView
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Click outside → dismiss (verify click is truly outside the panel)
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self, let panel = self.browserPanel else { return }
                let clickLocation = NSEvent.mouseLocation
                if !panel.frame.contains(clickLocation) {
                    self.dismissBrowser()
                }
            }
        }

        browserPanel = panel
    }

    func dismissBrowser() {
        guard isBrowserVisible else { return }
        isBrowserVisible = false

        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }

        browserPanel?.orderOut(nil)
        browserPanel = nil
    }

    private func pasteItem(_ item: ClipboardItem, matchStyle: Bool) {
        dismissBrowser()

        // Re-activate the previous app, then paste after a short delay
        if let app = previousApp {
            app.activate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            if matchStyle {
                self.pasteEngine.pasteAndMatchStyle(item)
            } else {
                self.pasteEngine.paste(item)
            }
        }
    }
}
