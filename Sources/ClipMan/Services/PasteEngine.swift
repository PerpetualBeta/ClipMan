import AppKit
import Carbon.HIToolbox

final class PasteEngine {
    private let monitor: ClipboardMonitor

    init(monitor: ClipboardMonitor) {
        self.monitor = monitor
    }

    func paste(_ item: ClipboardItem) {
        writeToPasteboard(item, plainTextOnly: false)
        simulatePaste()
    }

    func pasteAndMatchStyle(_ item: ClipboardItem) {
        writeToPasteboard(item, plainTextOnly: true)
        simulatePaste()
    }

    private func writeToPasteboard(_ item: ClipboardItem, plainTextOnly: Bool) {
        monitor.ignoreNextChange()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // File URLs — write them as file URL items
        if let fileURLStrings = item.fileURLs, !fileURLStrings.isEmpty {
            let fileURLs = fileURLStrings.compactMap { URL(string: $0) }
            pasteboard.writeObjects(fileURLs as [NSURL])
            return
        }

        if plainTextOnly {
            pasteboard.setString(item.content, forType: .string)
        } else {
            var types: [NSPasteboard.PasteboardType] = [.string]
            if item.rtfData != nil { types.append(.rtf) }
            if item.imageData != nil { types.append(.tiff) }

            pasteboard.declareTypes(types, owner: nil)
            pasteboard.setString(item.content, forType: .string)

            if let rtfData = item.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            if let imageData = item.imageData {
                pasteboard.setData(imageData, forType: .tiff)
            }
        }
    }

    private func simulatePaste() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let source = CGEventSource(stateID: .hidSystemState)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
            keyDown?.flags = .maskCommand

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
            keyUp?.flags = .maskCommand

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }
}
