// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "aiess",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "aiess",
            path: "Sources/aiess"
        )
    ]
)
