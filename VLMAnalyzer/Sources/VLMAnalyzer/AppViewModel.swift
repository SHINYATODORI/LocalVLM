import SwiftUI
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class AppViewModel {
    var images: [ImageItem] = []
    var commonPrompt: String = ""
    var isAnalyzingAll: Bool = false

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
        let prompt = combinedPrompt(common: commonPrompt, individual: item.individualPrompt)
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
        guard !images.isEmpty else { return }
        isAnalyzingAll = true

        let targets = images
        let common = commonPrompt

        await withTaskGroup(of: Void.self) { group in
            for item in targets {
                let prompt = combinedPrompt(common: common, individual: item.individualPrompt)
                guard !prompt.isEmpty else { continue }

                item.isAnalyzing = true
                item.result = ""
                item.error = nil

                group.addTask {
                    do {
                        let result = try await OllamaService.shared.analyze(imageURL: item.url, prompt: prompt)
                        await MainActor.run {
                            item.result = result
                            item.isAnalyzing = false
                        }
                    } catch {
                        await MainActor.run {
                            item.error = error.localizedDescription
                            item.isAnalyzing = false
                        }
                    }
                }
            }
        }

        isAnalyzingAll = false
    }

    // MARK: - Report

    func generateReport() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = formatter.string(from: Date())

        var lines = [
            "# VLM Analysis Report",
            "",
            "**Generated:** \(date)",
            "**Model:** qwen2.5vl:7b",
            "**Common Prompt:** \(commonPrompt.isEmpty ? "_(none)_" : commonPrompt)",
            "",
            "---",
            "",
        ]

        for (i, item) in images.enumerated() {
            lines += [
                "## [\(i + 1)] \(item.fileName)",
                "",
                "**Individual Prompt:** \(item.individualPrompt.isEmpty ? "_(none)_" : item.individualPrompt)",
                "",
                "**Combined Prompt:**",
                combinedPrompt(common: commonPrompt, individual: item.individualPrompt).isEmpty
                    ? "_(none)_"
                    : combinedPrompt(common: commonPrompt, individual: item.individualPrompt),
                "",
                "**Result:**",
                item.result.isEmpty ? "_(not analyzed)_" : item.result,
                "",
                "---",
                "",
            ]
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func combinedPrompt(common: String, individual: String) -> String {
        [common, individual]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
