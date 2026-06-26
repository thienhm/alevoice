// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AleVoice",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "AleVoiceCore", targets: ["AleVoiceCore"]),
    ],
    targets: [
        .target(name: "AleVoiceCore"),
        .testTarget(
            name: "AleVoiceCoreTests",
            dependencies: ["AleVoiceCore"],
            path: "tests/AleVoiceCoreTests"
        ),
    ]
)
