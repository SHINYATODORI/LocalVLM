import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - WKWebView wrapper

struct WebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.setValue(false, forKey: "drawsBackground")
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Report sheet

struct ReportView: View {
    let htmlContent: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WebView(html: htmlContent)
                .navigationTitle("解析レポート")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                    ToolbarItemGroup(placement: .confirmationAction) {
                        Button { saveAsHTML() } label: {
                            Label("HTML保存", systemImage: "square.and.arrow.down")
                        }
                        Button { saveAsMarkdown() } label: {
                            Label("MD保存", systemImage: "doc.plaintext")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
        }
        .frame(minWidth: 780, minHeight: 560)
    }

    // MARK: - Save

    private func saveAsHTML() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "vlm_report_\(timestamp()).html"
        panel.allowedContentTypes  = [UTType(filenameExtension: "html") ?? .html]
        panel.message = "HTMLレポートの保存先を選択"
        if panel.runModal() == .OK, let url = panel.url {
            try? htmlContent.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func saveAsMarkdown() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "vlm_report_\(timestamp()).md"
        panel.allowedContentTypes  = [.plainText]
        panel.message = "Markdownレポートの保存先を選択"
        if panel.runModal() == .OK, let url = panel.url {
            // Strip HTML tags for a plain markdown fallback
            let plain = htmlContent
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&amp;",  with: "&")
                .replacingOccurrences(of: "&lt;",   with: "<")
                .replacingOccurrences(of: "&gt;",   with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
            try? plain.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }
}
