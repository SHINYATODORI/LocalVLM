import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class AppViewModel {
    var images: [ImageItem] = []
    var commonPrompt: String = ""
    var isAnalyzingAll: Bool = false
    var analyzedCount: Int = 0
    var analyzeTotal: Int = 0

    // MARK: - Image management

    func addImages(urls: [URL]) {
        let imageTypes = Set(["jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "tiff", "webp"])
        let newItems = urls
            .filter { imageTypes.contains($0.pathExtension.lowercased()) }
            .filter { url in !images.contains(where: { $0.url == url }) }
            .map { ImageItem(url: $0) }
        images.append(contentsOf: newItems)
    }

    func removeImage(_ item: ImageItem) {
        images.removeAll { $0.id == item.id }
    }

    // MARK: - Analysis

    func analyzeImage(_ item: ImageItem) async {
        guard !item.isAnalyzing else { return }
        let prompt = combined(common: commonPrompt, individual: item.individualPrompt)
        guard !prompt.isEmpty else { return }

        item.isAnalyzing = true
        item.result = ""
        item.error = nil

        do {
            item.result = try await OllamaService.shared.analyze(imageURL: item.url, prompt: prompt)
        } catch {
            item.error = error.localizedDescription
        }
        item.isAnalyzing = false
    }

    func analyzeAll() async {
        let targets = images.filter {
            !combined(common: commonPrompt, individual: $0.individualPrompt).isEmpty
        }
        guard !targets.isEmpty else { return }

        isAnalyzingAll = true
        analyzeTotal = targets.count
        analyzedCount = 0

        for item in targets {
            item.isAnalyzing = true
            item.result = ""
            item.error = nil
        }

        await withTaskGroup(of: Void.self) { group in
            for item in targets {
                let prompt = combined(common: commonPrompt, individual: item.individualPrompt)
                group.addTask {
                    do {
                        let result = try await OllamaService.shared.analyze(imageURL: item.url, prompt: prompt)
                        await MainActor.run {
                            item.result = result
                            item.isAnalyzing = false
                            self.analyzedCount += 1
                        }
                    } catch {
                        await MainActor.run {
                            item.error = error.localizedDescription
                            item.isAnalyzing = false
                            self.analyzedCount += 1
                        }
                    }
                }
            }
        }

        isAnalyzingAll = false
    }

    // MARK: - HTML Report

    func generateHTMLReport() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
        let dateStr = formatter.string(from: Date())

        let completed = images.filter { !$0.result.isEmpty }.count
        let errors    = images.filter { $0.error != nil }.count

        var cards = ""
        for (i, item) in images.enumerated() {
            let prompt = combined(common: commonPrompt, individual: item.individualPrompt)

            let imgTag: String
            if let b64 = imageBase64(url: item.url) {
                imgTag = "<img src=\"data:image/jpeg;base64,\(b64)\" class=\"photo\">"
            } else {
                imgTag = "<div class=\"no-photo\">画像を読み込めませんでした</div>"
            }

            let statusClass: String
            let statusLabel: String
            if item.isAnalyzing        { statusClass = "analyzing"; statusLabel = "解析中" }
            else if item.error != nil  { statusClass = "error";     statusLabel = "エラー" }
            else if !item.result.isEmpty { statusClass = "done";    statusLabel = "完了" }
            else                       { statusClass = "pending";   statusLabel = "未解析" }

            let resultHTML = item.result.isEmpty
                ? "<span class=\"empty\">未解析</span>"
                : "<p>\(htmlEscape(item.result).replacingOccurrences(of: "\n", with: "<br>"))</p>"

            let errorHTML = item.error.map {
                "<div class=\"error-msg\">⚠️ \(htmlEscape($0))</div>"
            } ?? ""

            cards += """
            <div class="card">
              <div class="card-header">
                <span class="idx">\(i + 1)</span>
                <span class="fname">\(htmlEscape(item.fileName))</span>
                <span class="badge \(statusClass)">\(statusLabel)</span>
              </div>
              <div class="photo-wrap">\(imgTag)</div>
              <div class="card-body">
                <div class="field">
                  <div class="field-label">個別プロンプト</div>
                  <div class="field-val">\(item.individualPrompt.isEmpty ? "<em>（なし）</em>" : htmlEscape(item.individualPrompt))</div>
                </div>
                <div class="field">
                  <div class="field-label">送信プロンプト（共通＋個別）</div>
                  <div class="field-val combined">\(prompt.isEmpty ? "<em>（なし）</em>" : htmlEscape(prompt).replacingOccurrences(of: "\n", with: "<br>"))</div>
                </div>
                <div class="field">
                  <div class="field-label">解析結果</div>
                  <div class="result">\(resultHTML)</div>
                </div>
                \(errorHTML)
              </div>
            </div>
            """
        }

        return """
        <!DOCTYPE html>
        <html lang="ja">
        <head>
        <meta charset="UTF-8">
        <title>VLM Analysis Report</title>
        <style>
        *{box-sizing:border-box;margin:0;padding:0}
        body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#f5f5f7;color:#1d1d1f;padding:28px}
        .rpt-header{background:linear-gradient(135deg,#0f0c29,#302b63,#24243e);color:#fff;padding:28px 32px;border-radius:16px;margin-bottom:24px}
        .rpt-header h1{font-size:24px;font-weight:700;margin-bottom:10px;letter-spacing:-0.3px}
        .rpt-header .meta{font-size:13px;opacity:.8;line-height:2}
        .summary{display:flex;gap:12px;margin-bottom:24px}
        .sum-item{flex:1;background:#fff;border-radius:12px;padding:16px 20px;box-shadow:0 1px 5px rgba(0,0,0,.08)}
        .sum-item .lbl{font-size:10px;color:#999;text-transform:uppercase;letter-spacing:.8px;margin-bottom:4px}
        .sum-item .val{font-size:26px;font-weight:700}
        .common-box{background:#fff;border-radius:12px;padding:18px 22px;margin-bottom:24px;box-shadow:0 1px 5px rgba(0,0,0,.08);border-left:4px solid #0066cc}
        .common-box .lbl{font-size:10px;color:#999;text-transform:uppercase;letter-spacing:.8px;margin-bottom:6px}
        .common-box p{font-size:14px;line-height:1.7}
        .card{background:#fff;border-radius:16px;margin-bottom:28px;overflow:hidden;box-shadow:0 2px 10px rgba(0,0,0,.10)}
        .card-header{display:flex;align-items:center;gap:10px;padding:14px 20px;background:#f8f8fa;border-bottom:1px solid #ebebed}
        .idx{background:#0066cc;color:#fff;width:28px;height:28px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:700;flex-shrink:0}
        .fname{font-size:14px;font-weight:600;flex:1;word-break:break-all}
        .badge{font-size:11px;padding:3px 10px;border-radius:20px;font-weight:600}
        .badge.done{background:#d4edda;color:#155724}
        .badge.analyzing{background:#cce5ff;color:#004085}
        .badge.error{background:#f8d7da;color:#721c24}
        .badge.pending{background:#e2e3e5;color:#383d41}
        .photo-wrap{line-height:0}
        .photo{width:100%;max-height:480px;object-fit:cover;display:block}
        .no-photo{padding:40px;text-align:center;color:#aaa;background:#fafafa;font-size:13px}
        .card-body{padding:22px}
        .field{margin-bottom:18px}
        .field:last-child{margin-bottom:0}
        .field-label{font-size:10px;color:#999;text-transform:uppercase;letter-spacing:.8px;margin-bottom:6px;font-weight:600}
        .field-val{font-size:13px;color:#444;background:#f8f9fa;padding:10px 14px;border-radius:8px;line-height:1.7}
        .field-val.combined{border-left:3px solid #0066cc}
        .result{font-size:14px;line-height:1.9;color:#1d1d1f;background:#f0f7ff;padding:16px 20px;border-radius:8px;border-left:3px solid #0066cc}
        .result p{margin-bottom:8px}.result p:last-child{margin-bottom:0}
        .empty{color:#bbb;font-style:italic}
        .error-msg{font-size:13px;color:#c00;background:#fff5f5;padding:10px 14px;border-radius:8px;margin-top:12px}
        .footer{text-align:center;color:#bbb;font-size:12px;padding:20px}
        </style>
        </head>
        <body>
        <div class="rpt-header">
          <h1>📊 VLM Analysis Report</h1>
          <div class="meta">
            生成日時：\(dateStr)<br>
            使用モデル：qwen2.5vl:32b (ollama / ローカル)<br>
            共通プロンプト：\(commonPrompt.isEmpty ? "（なし）" : htmlEscape(commonPrompt))
          </div>
        </div>

        <div class="summary">
          <div class="sum-item"><div class="lbl">総画像数</div><div class="val">\(images.count)</div></div>
          <div class="sum-item"><div class="lbl">解析完了</div><div class="val" style="color:#28a745">\(completed)</div></div>
          <div class="sum-item"><div class="lbl">未解析</div><div class="val" style="color:#888">\(images.count - completed - errors)</div></div>
          <div class="sum-item"><div class="lbl">エラー</div><div class="val" style="color:\(errors > 0 ? "#dc3545" : "#ccc")">\(errors)</div></div>
        </div>

        \(cards)
        <div class="footer">Generated by VLM Analyzer — qwen2.5vl:32b via ollama</div>
        </body>
        </html>
        """
    }

    // MARK: - Helpers

    func combined(common: String, individual: String) -> String {
        [common, individual]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func imageBase64(url: URL, maxWidth: Int = 960) -> String? {
        guard let src = NSImage(contentsOf: url) else { return nil }
        let targetSize: CGSize = src.size.width > CGFloat(maxWidth)
            ? CGSize(width: CGFloat(maxWidth),
                     height: src.size.height * CGFloat(maxWidth) / src.size.width)
            : src.size

        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        src.draw(in: NSRect(origin: .zero, size: targetSize),
                 from: NSRect(origin: .zero, size: src.size),
                 operation: .copy, fraction: 1.0)
        resized.unlockFocus()

        guard let tiff   = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg   = bitmap.representation(using: .jpeg,
                                                 properties: [.compressionFactor: 0.82])
        else { return nil }
        return jpeg.base64EncodedString()
    }

    private func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
