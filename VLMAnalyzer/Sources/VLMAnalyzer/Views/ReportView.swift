import SwiftUI
import UniformTypeIdentifiers

struct ReportView: View {
    let content: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(.textBackgroundColor))
            .navigationTitle("解析レポート")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveReport()
                    } label: {
                        Label("保存", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    private func saveReport() {
        let panel = NSSavePanel()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        panel.nameFieldStringValue = "vlm_report_\(formatter.string(from: Date())).md"
        panel.allowedContentTypes = [.plainText]
        panel.message = "レポートの保存先を選択してください"

        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
