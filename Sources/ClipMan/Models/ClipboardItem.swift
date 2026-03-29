import Foundation
import SwiftData

@Model
final class ClipboardItem {
    var id: UUID
    var content: String
    var rtfData: Data?
    var imageData: Data?
    var fileURLs: [String]?
    var sourceApp: String?
    var timestamp: Date
    var isPinned: Bool

    init(
        content: String,
        rtfData: Data? = nil,
        imageData: Data? = nil,
        fileURLs: [String]? = nil,
        sourceApp: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = UUID()
        self.content = content
        self.rtfData = rtfData
        self.imageData = imageData
        self.fileURLs = fileURLs
        self.sourceApp = sourceApp
        self.timestamp = Date()
        self.isPinned = isPinned
    }

    /// Whether this item represents copied files rather than text
    var isFileItem: Bool {
        guard let urls = fileURLs else { return false }
        return !urls.isEmpty
    }

    /// Display-friendly summary for file items
    var displayContent: String {
        guard let urls = fileURLs, !urls.isEmpty else { return content }
        let names = urls.compactMap { URL(string: $0)?.lastPathComponent }
        if names.count == 1 {
            return names[0]
        }
        return "\(names.count) items: \(names.joined(separator: ", "))"
    }
}
