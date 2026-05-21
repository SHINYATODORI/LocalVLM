import SwiftUI

struct ImageCardView: View {
    @Bindable var item: ImageItem
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailArea
            contentArea
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    // MARK: - Thumbnail

    private var thumbnailArea: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let img = item.image {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.secondary.opacity(0.15)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(height: 180)
            .clipped()

            // Analyzing overlay
            if item.isAnalyzing {
                Color.black.opacity(0.45)
                    .frame(height: 180)
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.3)
                    .frame(height: 180)
            }

            // Delete button (always on top)
            Button {
                vm.removeImage(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .frame(height: 180)
    }

    // MARK: - Content

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            // File name
            Text(item.fileName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            // Individual prompt
            TextField("個別プロンプト（オプション）", text: $item.individualPrompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
                .lineLimit(2...5)

            // Analyze button
            Button {
                Task { await vm.analyzeImage(item) }
            } label: {
                Label(item.isAnalyzing ? "解析中…" : "解析", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(item.isAnalyzing)

            // Result
            if !item.result.isEmpty {
                Divider()
                resultView
            }

            // Error
            if let error = item.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
    }

    // MARK: - Result

    private var resultView: some View {
        ScrollView {
            Text(item.result)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
        }
        .frame(maxHeight: 180)
    }
}
