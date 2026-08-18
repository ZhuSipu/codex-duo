// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CodexDuo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CodexDuo", targets: ["CodexDuo"]),
    ],
    targets: [
        .executableTarget(name: "CodexDuo", path: "Sources/CodexDuo"),
    ]
)
