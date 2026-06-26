// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AleVoice",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "AleVoiceCore", targets: ["AleVoiceCore"]),
        .executable(name: "AleVoiceCLI", targets: ["AleVoiceCLI"]),
    ],
    targets: [
        .target(name: "AleVoiceCore"),
        .executableTarget(
            name: "AleVoiceCLI",
            dependencies: ["AleVoiceCore"]
        ),
        .testTarget(
            name: "AleVoiceCoreTests",
            dependencies: ["AleVoiceCore", "AleVoiceCLI"],
            path: "tests/AleVoiceCoreTests"
        ),
    ]
)
