import AppKit
import SwiftData
import Combine

@Observable
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var modelContext: ModelContext?
    private(set) var latestItem: ClipboardItem?

    var maxItems: Int {
        UserDefaults.standard.integer(forKey: "maxClipboardItems").clamped(to: 10...500, default: 50)
    }

    func start(modelContext: ModelContext) {
        self.modelContext = modelContext
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreNextChange() {
        lastChangeCount = NSPasteboard.general.changeCount + 1
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let modelContext else { return }

        // Determine what's on the pasteboard
        let plainText = pasteboard.string(forType: .string)
        let rtfData = pasteboard.data(forType: .rtf)
        let fileURLs = captureFileURLs(from: pasteboard)

        // Capture image data
        var imageData: Data?
        if let tiffData = pasteboard.data(forType: .tiff) {
            imageData = tiffData
        } else if let pngData = pasteboard.data(forType: .png) {
            imageData = pngData
        }

        // Build content string — files get a filename summary, images get a label
        let content: String
        if let fileURLs, !fileURLs.isEmpty {
            let names = fileURLs.compactMap { URL(string: $0)?.lastPathComponent }
            content = names.count == 1 ? names[0] : "\(names.count) items"
        } else if let plainText, !plainText.isEmpty {
            content = plainText
        } else if imageData != nil {
            content = "[Image]"
        } else {
            // Nothing useful to capture
            return
        }

        // Deduplicate
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        if let existingItems = try? modelContext.fetch(descriptor),
           let mostRecent = existingItems.first,
           mostRecent.content == content,
           mostRecent.fileURLs == fileURLs {
            return
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        let item = ClipboardItem(
            content: content,
            rtfData: rtfData,
            imageData: imageData,
            fileURLs: fileURLs,
            sourceApp: sourceApp
        )

        modelContext.insert(item)
        latestItem = item
        trimHistory(modelContext: modelContext)
        try? modelContext.save()
    }

    private func captureFileURLs(from pasteboard: NSPasteboard) -> [String]? {
        // Check for file URLs on the pasteboard
        guard let items = pasteboard.pasteboardItems else { return nil }

        var urls: [String] = []
        for item in items {
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString) {
                urls.append(url.absoluteString)
            }
        }

        return urls.isEmpty ? nil : urls
    }

    private func trimHistory(modelContext: ModelContext) {
        let max = maxItems
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        guard let allItems = try? modelContext.fetch(descriptor) else { return }

        var unpinnedCount = 0
        for item in allItems {
            if item.isPinned { continue }
            unpinnedCount += 1
            if unpinnedCount > max {
                modelContext.delete(item)
            }
        }
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>, default defaultValue: Int) -> Int {
        if self == 0 { return defaultValue }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
