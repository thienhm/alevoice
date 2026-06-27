// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AleVoice",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "AleVoiceCore", targets: ["AleVoiceCore"]),
        .library(name: "AleVoiceAppUI", targets: ["AleVoiceAppUI"]),
        .executable(name: "AleVoiceCLI", targets: ["AleVoiceCLI"]),
        .executable(name: "AleVoiceApp", targets: ["AleVoiceApp"]),
    ],
    targets: [
        .target(name: "AleVoiceCore"),
        .target(
            name: "AleVoiceAppUI",
            dependencies: ["AleVoiceCore"]
        ),
        .executableTarget(
            name: "AleVoiceCLI",
            dependencies: ["AleVoiceCore"]
        ),
        .executableTarget(
            name: "AleVoiceApp",
            dependencies: ["AleVoiceCore", "AleVoiceAppUI"]
        ),
        .testTarget(
            name: "AleVoiceCoreTests",
            dependencies: ["AleVoiceCore", "AleVoiceCLI"],
            path: "tests/AleVoiceCoreTests"
        ),
        .testTarget(
            name: "AleVoiceAppUITests",
            dependencies: ["AleVoiceAppUI", "AleVoiceCore"],
            path: "tests/AleVoiceAppUITests"
        ),
        .testTarget(
            name: "AleVoiceAppTests",
            dependencies: ["AleVoiceApp", "AleVoiceCore"],
            path: "tests/AleVoiceAppTests"
        ),
    ]
)
