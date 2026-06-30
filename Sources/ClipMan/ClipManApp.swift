import SwiftUI
import SwiftData
import KeyboardShortcuts
import Sparkle

@main
struct ClipManApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // The status-bar icon, menu, popover, and click handling all live in
    // AppDelegate. SwiftUI's App protocol still requires a Scene, so an
    // empty Settings scene satisfies it without creating any window —
    // ClipMan's settings UI is presented manually from AppDelegate.
    var body: some Scene {
        Settings { EmptyView() }
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
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, ObservableObject {
    let clipboardMonitor = ClipboardMonitor()
    private(set) lazy var pasteEngine = PasteEngine(monitor: clipboardMonitor)
    private var browserPanel: FloatingPanel?
    private var isBrowserVisible = false
    private var clickOutsideMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var statusItem: NSStatusItem?
    let sparkleUserDriverDelegate = ClipManUserDriverDelegate()
    lazy var sparkleUpdater = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: sparkleUserDriverDelegate
    )

    // SwiftData store, kept in an app-private directory.
    //
    // CRITICAL: a default `ModelConfiguration` (no `url:`) writes to the shared
    // `~/Library/Application Support/default.store`. On a non-sandboxed Mac that
    // single file is common ground for *every* app that likewise omits a custom
    // URL. When another such app opens it with a different model, Core Data's
    // automatic migration treats `ClipboardItem` as a removed entity and DROPS
    // the table — silently wiping all clipboard history and pins. (Field
    // evidence: the shared store had logged 5,676 transactions yet ClipMan's
    // primary-key counter had been reset to 3.) Pinning ClipMan to its own file
    // removes it from the shared store entirely, so nothing else can touch it.
    let modelContainer: ModelContainer = {
        let schema = Schema([ClipboardItem.self])
        let config = ModelConfiguration(schema: schema, url: AppDelegate.privateStoreURL())
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            AppDelegate.migrateOffSharedStoreIfNeeded(into: container)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// `~/Library/Application Support/ClipMan/ClipMan.store`, creating the
    /// containing directory if needed. Core Data creates the store file itself
    /// but requires its parent directory to already exist.
    private static func privateStoreURL() -> URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("ClipMan", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ClipMan.store")
    }

    /// One-time rescue of whatever still survives in the old shared
    /// `default.store`, copied into the new private store. Gated by a defaults
    /// flag so it runs exactly once — afterwards ClipMan never re-opens the
    /// shared file. Best-effort throughout: a failure here must never block
    /// launch, and the copy is skipped if the private store already has data so
    /// a stray re-run can't duplicate items.
    private static func migrateOffSharedStoreIfNeeded(into container: ModelContainer) {
        let flag = "didMigrateOffSharedStore"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        defer { UserDefaults.standard.set(true, forKey: flag) }

        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let oldURL = appSupport.appendingPathComponent("default.store")
        guard fm.fileExists(atPath: oldURL.path) else { return }

        let newContext = ModelContext(container)
        let newCount = (try? newContext.fetchCount(FetchDescriptor<ClipboardItem>())) ?? 0
        guard newCount == 0 else { return }

        let schema = Schema([ClipboardItem.self])
        let oldConfig = ModelConfiguration(schema: schema, url: oldURL)
        guard let oldContainer = try? ModelContainer(for: schema, configurations: [oldConfig]) else { return }
        let oldContext = ModelContext(oldContainer)
        guard let survivors = try? oldContext.fetch(
            FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        ), !survivors.isEmpty else { return }

        for old in survivors {
            let copy = ClipboardItem(
                content: old.content,
                rtfData: old.rtfData,
                imageData: old.imageData,
                fileURLs: old.fileURLs,
                sourceApp: old.sourceApp,
                isPinned: old.isPinned
            )
            copy.timestamp = old.timestamp
            newContext.insert(copy)
        }
        try? newContext.save()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateLegacyPillColorKey()

        createStatusItem()

        // Re-create or tear down the status item when its visibility flag changes.
        NotificationCenter.default.addObserver(
            forName: JorvikStatusItemVisibility.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyStatusItemVisibility()
            }
        }

        let context = ModelContext(modelContainer)
        clipboardMonitor.start(modelContext: context)

        let permissions = PermissionsManager()
        if !permissions.accessibilityGranted {
            permissions.requestAccessibility()
        }

        _ = sparkleUpdater  // forces lazy init so Sparkle starts at launch

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

        // Redraw the status icon when the display configuration changes — the
        // menu bar's effective thickness can shrink (e.g. moving from a notched
        // display to an external one) and leave the pre-rendered pill cropped.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshIcon()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        JorvikStatusItemVisibility.handleReopen()
        return true
    }

    // One-shot removal of the user-chosen pill colour key from the old design.
    // The new pill uses fixed grey/light colours; the key is dead weight.
    private func migrateLegacyPillColorKey() {
        let migrated = "didMigratePillColorV2"
        if UserDefaults.standard.bool(forKey: migrated) { return }
        UserDefaults.standard.removeObject(forKey: "menuBarPillColor")
        UserDefaults.standard.set(true, forKey: migrated)
    }

    // MARK: - Status Item

    private func createStatusItem() {
        guard JorvikStatusItemVisibility.isVisible else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "ClipManStatus"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        refreshIcon()
    }

    func applyStatusItemVisibility() {
        if JorvikStatusItemVisibility.isVisible {
            if statusItem == nil { createStatusItem() }
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func refreshIcon() {
        statusItem?.button?.image = JorvikMenuBarPill.icon(
            symbolName: "scissors",
            accessibilityDescription: "ClipMan"
        )
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        let isEmpty = historyIsEmpty()
        let actions: [JorvikMenuBuilder.ActionItem] = [
            JorvikMenuBuilder.ActionItem(
                title: "Show Clipboard History\u{2026}",
                action: #selector(showHistoryAction),
                target: self
            ),
            JorvikMenuBuilder.ActionItem(
                title: "Clear History",
                action: #selector(clearHistoryAction),
                target: self,
                isEnabled: !isEmpty
            ),
            JorvikMenuBuilder.ActionItem(title: "-", action: #selector(noop), target: self),
            JorvikMenuBuilder.ActionItem(
                title: "Check for Updates\u{2026}",
                action: #selector(checkForUpdates(_:)),
                target: self
            ),
        ]
        let built = JorvikMenuBuilder.buildMenu(
            appName: "ClipMan",
            aboutAction: #selector(openAboutAction),
            settingsAction: #selector(openSettingsAction),
            target: self,
            actions: actions
        )

        // Display the current global hotkey next to "Show Clipboard History…".
        // JorvikMenuBuilder.ActionItem only carries a single-char keyEquivalent
        // and no modifier mask; the user-configured shortcut needs both, so
        // apply them post-build.
        if let shortcut = KeyboardShortcuts.getShortcut(for: .showClipboardHistory),
           let keyEquiv = shortcut.nsMenuItemKeyEquivalent,
           let item = built.items.first(where: { $0.title == "Show Clipboard History\u{2026}" }) {
            item.keyEquivalent = keyEquiv
            item.keyEquivalentModifierMask = shortcut.modifiers
        }

        menu.removeAllItems()
        for item in built.items {
            built.removeItem(item)
            menu.addItem(item)
        }
    }

    @objc private func showHistoryAction() { toggleBrowser() }
    @objc private func clearHistoryAction() { clearHistory() }
    @objc private func openAboutAction() { openAbout() }
    @objc private func openSettingsAction() { openSettings() }
    @objc func checkForUpdates(_ sender: Any?) {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        sparkleUpdater.checkForUpdates(sender)
    }
    @objc private func noop() {}

    private func historyIsEmpty() -> Bool {
        let context = ModelContext(modelContainer)
        let count = (try? context.fetchCount(FetchDescriptor<ClipboardItem>())) ?? 0
        return count == 0
    }

    private func clearHistory() {
        let context = ModelContext(modelContainer)
        do {
            let items = try context.fetch(FetchDescriptor<ClipboardItem>())
            for item in items where !item.isPinned {
                context.delete(item)
            }
            try context.save()
        } catch {
            // Non-fatal; the next paste will still work.
        }
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

    func openSettings() {
        JorvikSettingsView.showWindow(appName: "ClipMan") { [weak self] in
            ClipManSettingsContent()

            MenuBarVisibilitySettings()

            MenuBarPillSettings { self?.refreshIcon() }
        }
    }

    // MARK: - About Window

    func openAbout() {
        JorvikAboutView.showWindow(
            appName: "ClipMan",
            repoName: "ClipMan",
            productPage: "utilities/clipman"
        )
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

/// Keeps Sparkle's update UI visible across the whole session, including
/// when the user switches to another app mid-download.
///
/// macOS 14+ deprecated `NSApp.activate(ignoringOtherApps: true)` and
/// the system now asks the active app for permission to yield focus
/// (often refused). Activation alone isn't enough.
///
/// Belt-and-braces strategy:
///  1. Use the modern activation API
///     (`NSRunningApplication.current.activate(options: [.activateAllWindows])`)
///     instead of the deprecated form.
///  2. While an update session is active, elevate every one of our
///     windows to `.floating`. A floating window (level 3) stays above
///     any other app's `.normal` windows (level 0) regardless of which
///     app holds focus — so even if the user switches to RM, the
///     Sparkle status / update windows remain visible.
///  3. Restore window levels when the session ends so we don't leave
///     non-update windows pinned floating.
final class ClipManUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    private var sessionObserver: NSObjectProtocol?
    private var elevatedWindows: [(window: NSWindow, originalLevel: NSWindow.Level)] = []

    func standardUserDriverWillShowModalAlert() {
        bringForward()
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        startFocusGuard()
        bringForward()
    }

    func standardUserDriverWillFinishUpdateSession() {
        stopFocusGuard()
    }

    private func bringForward() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        elevateAllWindows()
    }

    private func startFocusGuard() {
        guard sessionObserver == nil else { return }
        sessionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.bringForward()
        }
    }

    private func stopFocusGuard() {
        if let obs = sessionObserver {
            NotificationCenter.default.removeObserver(obs)
            sessionObserver = nil
        }
        for entry in elevatedWindows {
            entry.window.level = entry.originalLevel
        }
        elevatedWindows.removeAll()
    }

    /// Promote every visible window in this process to `.floating`. Any
    /// new Sparkle window that opens during the session is caught by
    /// the key-notification observer above and elevated then.
    private func elevateAllWindows() {
        for window in NSApp.windows where window.isVisible && window.level == .normal {
            elevatedWindows.append((window, window.level))
            window.level = .floating
        }
    }
}
