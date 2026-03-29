import SwiftUI
import QuickLookThumbnailing

struct ClipboardItemPreview: View {
    let item: ClipboardItem
    let onPaste: () -> Void
    let onPasteMatchStyle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Source app + timestamp header
            HStack {
                if let sourceApp = item.sourceApp {
                    Text(displayName(for: sourceApp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Content preview
            contentPreview

            // Action buttons
            HStack(spacing: 12) {
                Spacer()

                Button {
                    onPaste()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onPasteMatchStyle()
                } label: {
                    Label("Paste & Match Style", systemImage: "textformat")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var contentPreview: some View {
        if let fileURLs = item.fileURLs, !fileURLs.isEmpty {
            // File preview
            filePreview(urls: fileURLs)
        } else if let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
            // Inline image
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            // Plain/rich text
            ScrollView {
                Text(item.content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
        }
    }

    @ViewBuilder
    private func filePreview(urls: [String]) -> some View {
        if urls.count == 1, let urlString = urls.first, let url = URL(string: urlString) {
            // Single file — show large thumbnail + filename
            VStack(spacing: 8) {
                ThumbnailView(url: url, size: CGSize(width: 300, height: 180))
                    .frame(maxHeight: 180)

                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity)
        } else {
            // Multiple files — grid of small thumbnails
            let fileURLObjects = urls.compactMap { URL(string: $0) }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                    ForEach(fileURLObjects, id: \.absoluteString) { url in
                        VStack(spacing: 4) {
                            ThumbnailView(url: url, size: CGSize(width: 72, height: 72))
                                .frame(width: 72, height: 72)

                            Text(url.lastPathComponent)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(width: 80)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    private func displayName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleID.components(separatedBy: ".").last ?? bundleID
    }
}

// MARK: - QuickLook Thumbnail View

struct ThumbnailView: View {
    let url: URL
    let size: CGSize
    @State private var thumbnail: NSImage?
    @State private var loaded = false

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if loaded {
                // Fallback: system icon for this file type
                fileIcon
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await generateThumbnail()
        }
    }

    private var fileIcon: some View {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    private func generateThumbnail() async {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2.0,
            representationTypes: .all
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            await MainActor.run {
                self.thumbnail = representation.nsImage
                self.loaded = true
            }
        } catch {
            // QuickLook failed — will show file icon fallback
            await MainActor.run {
                self.loaded = true
            }
        }
    }
}
