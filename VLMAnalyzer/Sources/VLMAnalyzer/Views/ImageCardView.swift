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

            if item.isAnalyzing {
                Color.black.opacity(0.45).frame(height: 180)
                ProgressView().tint(.white).scaleEffect(1.3).frame(height: 180)
            }

            Button { vm.removeImage(item) } label: {
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

    // MARK: - Content (+2pt fonts throughout)

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.fileName)
                .font(.system(size: 13))   // caption(11) → 13
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            TextEditor(text: $item.individualPrompt)
                .font(.system(size: 14))   // callout(12) → 14
                .frame(minHeight: 52, maxHeight: 100)
                .scrollContentBackground(.hidden)
                .background(Color(.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if item.individualPrompt.isEmpty {
                        Text("個別プロンプト（オプション）")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 5)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }

            Button {
                Task { await vm.analyzeImage(item) }
            } label: {
                Label(item.isAnalyzing ? "解析中…" : "解析", systemImage: "play.fill")
                    .font(.system(size: 14))   // +2pt
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(item.isAnalyzing)

            if !item.result.isEmpty {
                Divider()
                resultView
            }

            if let error = item.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))   // caption(11) → 13
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
    }

    // MARK: - Result

    private var resultView: some View {
        ScrollView {
            Text(item.result)
                .font(.system(size: 15))   // callout(12) → 15
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
        }
        .frame(maxHeight: 200)
    }
}
