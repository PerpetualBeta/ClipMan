import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("ClipMan")
                .font(.title)
                .fontWeight(.semibold)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("A lightweight clipboard manager\nfor macOS.")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundStyle(.secondary)

            Text("\u{00A9} 2026 Jorvik Software")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 300, height: 220)
    }
}
