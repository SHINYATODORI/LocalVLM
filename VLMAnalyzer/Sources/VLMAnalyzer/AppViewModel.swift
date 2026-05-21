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
    var availableModels: [String] = []
    var selectedModel: String = "qwen3-vl:8b"
    var isReleasingModel: Bool = false   // モデルアンロード中フラグ

    /// 解析中かどうか（全件 or 個別どちらかでも）
    var isAnyAnalyzing: Bool {
        isAnalyzingAll || images.contains(where: { $0.isAnalyzing })
    }

    // MARK: - Model management

    /// VLモデル全リスト
    var vlModels: [String] {
        let keywords = ["vl", "vision", "llava", "moondream", "minicpm-v", "cogvlm", "internvl"]
        return availableModels.filter { model in
            keywords.contains(where: { model.lowercased().contains($0) })
        }
    }

    /// 小型VLモデルのみ（32b等を除外）— プルダウンに表示する候補
    var smallVlModels: [String] {
        let exclude = ["32b", "30b", "27b", "20b", "14b", "13b"]
        return vlModels.filter { model in
            !exclude.contains(where: { model.lowercased().contains($0) })
        }
    }

    func loadModels() async {
        let models = await OllamaService.shared.fetchModels()
        availableModels = models
        // smallVlModels優先、なければvlModels、なければ全体
        let pool = smallVlModels.isEmpty ? (vlModels.isEmpty ? models : vlModels) : smallVlModels
        if !pool.isEmpty && !pool.contains(selectedModel) {
            selectedModel = pool.first ?? selectedModel
            await OllamaService.shared.setModel(selectedModel)
        }
    }

    /// モデル切替：旧モデルをアンロードしてから新モデルをセット
    func switchModel(to newModel: String) async {
        guard newModel != selectedModel else { return }
        guard !isAnyAnalyzing else { return }

        isReleasingModel = true
        let old = selectedModel
        selectedModel = newModel                       // Pickerのbindingを先に更新
        await OllamaService.shared.unloadModel(old)
        await OllamaService.shared.setModel(newModel)
        isReleasingModel = false
    }

    /// ollamaサーバーを停止
    func stopOllama() {
        Task { await OllamaService.shared.stopServer() }
    }

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

    // MARK: - HTML Evaluation Report

    func generateHTMLReport() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
        let dateStr = formatter.string(from: Date())

        let completed  = images.filter { !$0.result.isEmpty }.count
        let _          = images.filter { $0.error != nil }.count
        let evaluated  = images.filter { !$0.expectedValue.isEmpty && !$0.result.isEmpty }
        let matchCount = evaluated.filter { isMatch(result: $0.result, expected: $0.expectedValue) }.count
        let accuracy   = evaluated.isEmpty ? "-" : "\(Int(Double(matchCount) / Double(evaluated.count) * 100))%"

        var cards = ""
        for (i, item) in images.enumerated() {
            let imgTag: String
            if let b64 = imageBase64(url: item.url) {
                imgTag = "<img src=\"data:image/jpeg;base64,\(b64)\" class=\"photo\">"
            } else {
                imgTag = "<div class=\"no-photo\">画像を読み込めませんでした</div>"
            }

            // 評価判定
            let hasExpected = !item.expectedValue.isEmpty
            let hasResult   = !item.result.isEmpty
            let matched     = hasExpected && hasResult && isMatch(result: item.result, expected: item.expectedValue)

            let statusClass: String
            let statusLabel: String
            if item.isAnalyzing          { statusClass = "analyzing"; statusLabel = "解析中" }
            else if item.error != nil    { statusClass = "error";     statusLabel = "エラー" }
            else if hasExpected && hasResult {
                statusClass = matched ? "match" : "mismatch"
                statusLabel = matched ? "✅ 一致" : "❌ 不一致"
            }
            else if hasResult            { statusClass = "done";     statusLabel = "解析済" }
            else                         { statusClass = "pending";  statusLabel = "未解析" }

            // 比較テーブル
            let comparisonHTML: String
            if hasResult {
                let expectedCell = hasExpected
                    ? htmlEscape(item.expectedValue).replacingOccurrences(of: "\n", with: "<br>")
                    : "<em class=\"empty\">期待値なし</em>"
                let matchRow = hasExpected ? """
                  <tr>
                    <th>判定</th>
                    <td colspan="2">
                      <span class="verdict \(matched ? "match" : "mismatch")">
                        \(matched ? "✅ 一致 — 期待値と合致しています" : "❌ 不一致 — 期待値と異なります")
                      </span>
                    </td>
                  </tr>
                """ : ""
                comparisonHTML = """
                <table class="cmp-table">
                  <tr>
                    <th style="width:80px">期待値</th>
                    <td class="expected">\(expectedCell)</td>
                    <th style="width:80px">解析結果</th>
                    <td class="result-cell">\(htmlEscape(item.result).replacingOccurrences(of: "\n", with: "<br>"))</td>
                  </tr>
                  \(matchRow)
                </table>
                """
            } else {
                comparisonHTML = "<span class=\"empty\">未解析</span>"
            }

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
              <div class="card-layout">
                <div class="photo-col">\(imgTag)</div>
                <div class="eval-col">
                  \(comparisonHTML)
                  \(errorHTML)
                </div>
              </div>
            </div>
            """
        }

        return """
        <!DOCTYPE html>
        <html lang="ja">
        <head>
        <meta charset="UTF-8">
        <title>VLM Evaluation Report</title>
        <style>
        *{box-sizing:border-box;margin:0;padding:0}
        body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#f5f5f7;color:#1d1d1f;padding:28px}
        .rpt-header{background:linear-gradient(135deg,#1a1a2e,#16213e,#0f3460);color:#fff;padding:28px 32px;border-radius:16px;margin-bottom:24px}
        .rpt-header h1{font-size:24px;font-weight:700;margin-bottom:10px}
        .rpt-header .meta{font-size:13px;opacity:.8;line-height:2}
        .summary{display:flex;gap:12px;margin-bottom:24px}
        .sum-item{flex:1;background:#fff;border-radius:12px;padding:16px 20px;box-shadow:0 1px 5px rgba(0,0,0,.08)}
        .sum-item .lbl{font-size:10px;color:#999;text-transform:uppercase;letter-spacing:.8px;margin-bottom:4px}
        .sum-item .val{font-size:26px;font-weight:700}
        .card{background:#fff;border-radius:16px;margin-bottom:24px;overflow:hidden;box-shadow:0 2px 10px rgba(0,0,0,.10)}
        .card-header{display:flex;align-items:center;gap:10px;padding:12px 18px;background:#f8f8fa;border-bottom:1px solid #ebebed}
        .idx{background:#0066cc;color:#fff;width:26px;height:26px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;flex-shrink:0}
        .fname{font-size:14px;font-weight:600;flex:1;word-break:break-all}
        .badge{font-size:11px;padding:3px 10px;border-radius:20px;font-weight:600;white-space:nowrap}
        .badge.match{background:#d4edda;color:#155724}
        .badge.mismatch{background:#f8d7da;color:#721c24}
        .badge.done{background:#cce5ff;color:#004085}
        .badge.analyzing{background:#fff3cd;color:#856404}
        .badge.error{background:#f8d7da;color:#721c24}
        .badge.pending{background:#e2e3e5;color:#383d41}
        .card-layout{display:flex;gap:0}
        .photo-col{width:280px;flex-shrink:0;line-height:0}
        .photo{width:100%;height:100%;object-fit:cover;display:block;min-height:160px;max-height:320px}
        .no-photo{width:280px;padding:40px 20px;text-align:center;color:#aaa;background:#fafafa;font-size:13px}
        .eval-col{flex:1;padding:18px 20px;display:flex;flex-direction:column;justify-content:flex-start;gap:12px}
        .cmp-table{width:100%;border-collapse:collapse;font-size:13px;line-height:1.7}
        .cmp-table th{width:72px;padding:10px 12px;background:#f0f0f5;color:#555;font-weight:600;vertical-align:top;border:1px solid #e0e0e8;text-align:left;white-space:nowrap}
        .cmp-table td{padding:10px 14px;vertical-align:top;border:1px solid #e0e0e8}
        .cmp-table td.expected{background:#fffbf0;border-left:3px solid #f0a500}
        .cmp-table td.result-cell{background:#f0f7ff;border-left:3px solid #0066cc}
        .verdict{display:inline-block;padding:6px 14px;border-radius:8px;font-weight:600;font-size:13px}
        .verdict.match{background:#d4edda;color:#155724}
        .verdict.mismatch{background:#f8d7da;color:#721c24}
        .empty{color:#bbb;font-style:italic}
        .error-msg{font-size:13px;color:#c00;background:#fff5f5;padding:10px 14px;border-radius:8px}
        .footer{text-align:center;color:#bbb;font-size:12px;padding:20px}
        </style>
        </head>
        <body>
        <div class="rpt-header">
          <h1>🔬 VLM Evaluation Report</h1>
          <div class="meta">
            生成日時：\(dateStr)<br>
            使用モデル：\(selectedModel) (ollama / ローカル)<br>
            共通プロンプト：\(commonPrompt.isEmpty ? "（なし）" : htmlEscape(commonPrompt))
          </div>
        </div>
        <div class="summary">
          <div class="sum-item"><div class="lbl">総画像数</div><div class="val">\(images.count)</div></div>
          <div class="sum-item"><div class="lbl">解析完了</div><div class="val" style="color:#0066cc">\(completed)</div></div>
          <div class="sum-item"><div class="lbl">一致</div><div class="val" style="color:#28a745">\(matchCount)</div></div>
          <div class="sum-item"><div class="lbl">不一致</div><div class="val" style="color:#dc3545">\(evaluated.count - matchCount)</div></div>
          <div class="sum-item"><div class="lbl">正解率</div><div class="val" style="color:\(accuracy == "-" ? "#ccc" : (matchCount == evaluated.count && !evaluated.isEmpty) ? "#28a745" : "#e67e00")">\(accuracy)</div></div>
        </div>
        \(cards)
        <div class="footer">Generated by VLM Analyzer — \(selectedModel) via ollama</div>
        </body>
        </html>
        """
    }

    /// 期待値と解析結果の一致判定（部分一致）
    private func isMatch(result: String, expected: String) -> Bool {
        let r = result.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let e = expected.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !e.isEmpty else { return false }
        return r.contains(e) || e.contains(r)
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
