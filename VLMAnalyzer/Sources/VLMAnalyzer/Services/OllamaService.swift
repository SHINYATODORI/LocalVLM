import AppKit
import Foundation

// MARK: - Request / Response types

private struct ChatRequest: Encodable {
    let model: String
    let messages: [Message]
    let stream: Bool

    struct Message: Encodable {
        let role: String
        let content: String
        let images: [String]?
    }
}

private struct ChatResponse: Decodable {
    let message: Message

    struct Message: Decodable {
        let content: String
    }
}

// MARK: - Errors

enum OllamaError: LocalizedError {
    case imageConversionFailed
    case serverUnreachable
    case httpError(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "画像の変換に失敗しました"
        case .serverUnreachable:     return "ollamaサーバーに接続できません。`ollama serve` が起動しているか確認してください"
        case .httpError(let code):   return "サーバーエラー (HTTP \(code))"
        case .decodingFailed:        return "レスポンスの解析に失敗しました"
        }
    }
}

// MARK: - Models list response

private struct TagsResponse: Decodable {
    let models: [ModelEntry]
    struct ModelEntry: Decodable {
        let name: String
    }
}

// MARK: - Service

actor OllamaService {
    static let shared = OllamaService()

    private let baseURL = URL(string: "http://localhost:11434")!
    var currentModel: String = "qwen3-vl:8b"
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()

    func setModel(_ model: String) {
        currentModel = model
    }

    func fetchModels() async -> [String] {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return [] }
        guard let (data, _) = try? await session.data(from: url),
              let decoded = try? JSONDecoder().decode(TagsResponse.self, from: data)
        else { return [] }
        return decoded.models.map { $0.name }.sorted()
    }

    func analyze(imageURL: URL, prompt: String) async throws -> String {
        let base64 = try imageToBase64(url: imageURL)

        let body = ChatRequest(
            model: currentModel,
            messages: [.init(role: "user", content: prompt, images: [base64])],
            stream: false
        )

        var req = URLRequest(url: baseURL.appendingPathComponent("api/chat"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch let err as URLError where err.code == .cannotConnectToHost || err.code == .networkConnectionLost {
            throw OllamaError.serverUnreachable
        }

        guard let http = response as? HTTPURLResponse else { throw OllamaError.decodingFailed }
        guard http.statusCode == 200 else { throw OllamaError.httpError(http.statusCode) }

        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data) else {
            throw OllamaError.decodingFailed
        }
        return decoded.message.content
    }

    // MARK: - Private

    private func imageToBase64(url: URL) throws -> String {
        guard
            let nsImage = NSImage(contentsOf: url),
            let tiff = nsImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        else {
            throw OllamaError.imageConversionFailed
        }
        return jpeg.base64EncodedString()
    }
}
