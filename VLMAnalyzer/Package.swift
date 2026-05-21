// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VLMAnalyzer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "VLMAnalyzer",
            path: "Sources/VLMAnalyzer",
            linkerSettings: [.linkedFramework("WebKit")]
        )
    ]
)
