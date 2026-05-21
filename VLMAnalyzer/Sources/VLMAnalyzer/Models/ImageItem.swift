import AppKit
import Observation

@Observable
final class ImageItem: Identifiable, @unchecked Sendable {
    let id = UUID()
    let url: URL
    var individualPrompt: String = ""
    var result: String = ""
    var error: String? = nil
    var isAnalyzing: Bool = false

    var fileName: String { url.lastPathComponent }
    let image: NSImage?

    init(url: URL) {
        self.url = url
        self.image = NSImage(contentsOf: url)
    }
}
