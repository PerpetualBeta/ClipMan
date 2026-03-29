import SwiftUI
import SwiftData

struct ClipboardBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var allItems: [ClipboardItem]
    @State private var currentIndex: Int = 0

    /// Pinned items first, then unpinned — both groups sorted newest-first
    private var items: [ClipboardItem] {
        let pinned = allItems.filter { $0.isPinned }
        let unpinned = allItems.filter { !$0.isPinned }
        return pinned + unpinned
    }

    /// Safe accessor for the currently selected item
    private var currentItem: ClipboardItem? {
        guard !items.isEmpty, currentIndex >= 0, currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    let onDismiss: () -> Void
    let onPaste: (ClipboardItem, Bool) -> Void
    let pasteEngine: PasteEngine

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Clipboard History")
                    .font(.headline)
                Spacer()
                if !items.isEmpty {
                    Text("\(currentIndex + 1) of \(items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            if let item = currentItem {
                ClipboardItemPreview(
                    item: item,
                    onPaste: { pasteCurrentItem(matchStyle: false) },
                    onPasteMatchStyle: { pasteCurrentItem(matchStyle: true) }
                )

                Divider()

                navigationBar(for: item)
            } else {
                emptyState
            }
        }
        .frame(width: 480, height: 380)
        .background(.regularMaterial)
        .onChange(of: allItems.count) {
            clampIndex()
        }
        .onAppear {
            currentIndex = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .browserNavigate)) { notification in
            if let direction = notification.object as? String {
                if direction == "left" { navigatePrevious() }
                else if direction == "right" { navigateNext() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .browserPaste)) { notification in
            let matchStyle = (notification.object as? Bool) ?? false
            pasteCurrentItem(matchStyle: matchStyle)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No clipboard items yet")
                .foregroundStyle(.secondary)
            Text("Copy something to get started")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func navigationBar(for item: ClipboardItem) -> some View {
        HStack {
            Button {
                navigatePrevious()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(currentIndex <= 0)

            Button {
                togglePin()
            } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
            }
            .help(item.isPinned ? "Unpin item" : "Pin item")

            Button {
                deleteCurrent()
            } label: {
                Image(systemName: "trash")
            }
            .help("Delete this item")

            Spacer()

            pageIndicator

            Spacer()

            Button {
                navigateNext()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(currentIndex >= items.count - 1)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var pageIndicator: some View {
        HStack(spacing: 4) {
            let totalDots = min(items.count, 10)
            ForEach(0..<totalDots, id: \.self) { dotIndex in
                let itemIndex = mappedIndex(dotIndex: dotIndex, totalDots: totalDots)
                Circle()
                    .fill(itemIndex == currentIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func mappedIndex(dotIndex: Int, totalDots: Int) -> Int {
        if items.count <= 10 { return dotIndex }
        let halfDots = totalDots / 2
        let windowStart = max(0, min(currentIndex - halfDots, items.count - totalDots))
        return windowStart + dotIndex
    }

    private func clampIndex() {
        if items.isEmpty {
            currentIndex = 0
        } else if currentIndex >= items.count {
            currentIndex = items.count - 1
        }
    }

    private func navigatePrevious() {
        if currentIndex > 0 { currentIndex -= 1 }
    }

    private func navigateNext() {
        if currentIndex < items.count - 1 { currentIndex += 1 }
    }

    private func pasteCurrentItem(matchStyle: Bool) {
        guard let item = currentItem else { return }
        onPaste(item, matchStyle)
    }

    private func togglePin() {
        guard let item = currentItem else { return }
        item.isPinned.toggle()
        try? modelContext.save()
    }

    private func deleteCurrent() {
        guard let item = currentItem else { return }
        let countAfterDelete = items.count - 1

        modelContext.delete(item)
        try? modelContext.save()

        if countAfterDelete == 0 {
            currentIndex = 0
        } else if currentIndex >= countAfterDelete {
            currentIndex = countAfterDelete - 1
        }
    }
}
