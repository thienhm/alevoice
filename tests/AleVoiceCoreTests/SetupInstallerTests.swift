import Foundation
import XCTest
@testable import AleVoiceCLI
@testable import AleVoiceCore

final class SetupInstallerTests: XCTestCase {
    func test_setupInstallsRuntimeAndModelWritesConfigAndRunsDoctor() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let downloads = root.appendingPathComponent("fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)

        let runtimeSource = downloads.appendingPathComponent("runtime.tar.gz")
        let modelSource = downloads.appendingPathComponent("sensevoice-small-f16.gguf")
        try Data("runtime".utf8).write(to: runtimeSource)
        try Data("model".utf8).write(to: modelSource)

        let manifest = try SetupManifest.load(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Config/engines/funasr-sensevoice.json")
        )
        let configURL = root.appendingPathComponent("Config/speech-engine.json")

        var doctorConfigURL: URL?
        let installer = SetupInstaller(
            downloader: FakeDownloader(fixtures: [
                URL(string: "https://github.com/modelscope/FunASR/releases/download/runtime-llamacpp-v0.1.2/funasr-llamacpp-macos-arm64.tar.gz")!: runtimeSource,
                URL(string: "https://huggingface.co/FunAudioLLM/SenseVoiceSmall-GGUF/resolve/main/sensevoice-small-f16.gguf")!: modelSource,
            ]),
            hasher: FakeHasher(digests: [
                runtimeSource.path: "50a36463372eb87adf9e0829aa62b29ce94d7ba84ded705b9e81c768c274d923",
                modelSource.path: "2389039651f4574dbd674f1f1e296b8b1147b2e19a5fd9c2cd69e82669c78d8e",
                root.appendingPathComponent("AleVoice/downloads/funasr-llamacpp-macos-arm64.tar.gz").path: "50a36463372eb87adf9e0829aa62b29ce94d7ba84ded705b9e81c768c274d923",
                root.appendingPathComponent("AleVoice/downloads/sensevoice-small-f16.gguf").path: "2389039651f4574dbd674f1f1e296b8b1147b2e19a5fd9c2cd69e82669c78d8e",
            ]),
            extractor: FakeExtractor { destination in
                let binaryURL = destination.appendingPathComponent("llama-funasr-sensevoice")
                try Data("bin".utf8).write(to: binaryURL)
            },
            doctor: { url in
                doctorConfigURL = url
                return SetupDoctorResult(checks: [.init(name: "config", status: .passed, detail: "ok")])
            }
        )

        let result = try installer.install(
            request: .init(
                manifest: manifest,
                installRoot: root.appendingPathComponent("AleVoice", isDirectory: true),
                configURL: configURL,
                platform: .macOSArm64,
                variantName: nil,
                forceDownload: false
            )
        )

        let saved = try SpeechEngineSettings.load(from: configURL)
        XCTAssertEqual(saved.selectedEngineID, "funasr-sensevoice")
        XCTAssertEqual(saved.funasr.binaryPath, result.binaryURL.path)
        XCTAssertEqual(saved.funasr.modelPath, result.modelURL.path)
        XCTAssertEqual(doctorConfigURL, configURL)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: result.binaryURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.modelURL.path))
    }

    func test_setupFailsOnChecksumMismatchBeforeInstall() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let downloads = root.appendingPathComponent("fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)

        let runtimeSource = downloads.appendingPathComponent("runtime.tar.gz")
        let modelSource = downloads.appendingPathComponent("sensevoice-small-f16.gguf")
        try Data("runtime".utf8).write(to: runtimeSource)
        try Data("model".utf8).write(to: modelSource)

        let manifest = try SetupManifest.load(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Config/engines/funasr-sensevoice.json")
        )
        let configURL = root.appendingPathComponent("Config/speech-engine.json")

        let installer = SetupInstaller(
            downloader: FakeDownloader(fixtures: [
                URL(string: "https://github.com/modelscope/FunASR/releases/download/runtime-llamacpp-v0.1.2/funasr-llamacpp-macos-arm64.tar.gz")!: runtimeSource,
                URL(string: "https://huggingface.co/FunAudioLLM/SenseVoiceSmall-GGUF/resolve/main/sensevoice-small-f16.gguf")!: modelSource,
            ]),
            hasher: FakeHasher(digests: [:]),
            extractor: FakeExtractor { _ in },
            doctor: { _ in SetupDoctorResult(checks: []) }
        )

        XCTAssertThrowsError(
            try installer.install(
                request: .init(
                    manifest: manifest,
                    installRoot: root.appendingPathComponent("AleVoice", isDirectory: true),
                    configURL: configURL,
                    platform: .macOSArm64,
                    variantName: nil,
                    forceDownload: false
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? SetupInstallerError,
                .checksumMismatch(
                    artifact: "funasr-llamacpp-macos-arm64.tar.gz",
                    expected: "50a36463372eb87adf9e0829aa62b29ce94d7ba84ded705b9e81c768c274d923",
                    actual: ""
                )
            )
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: configURL.path))
    }

    func test_setupMarksRuntimeExecutableAfterUnpack() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let downloads = root.appendingPathComponent("fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)

        let runtimeSource = downloads.appendingPathComponent("runtime.tar.gz")
        let modelSource = downloads.appendingPathComponent("sensevoice-small-f16.gguf")
        try Data("runtime".utf8).write(to: runtimeSource)
        try Data("model".utf8).write(to: modelSource)

        let manifest = try SetupManifest.load(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Config/engines/funasr-sensevoice.json")
        )

        let installer = SetupInstaller(
            downloader: FakeDownloader(fixtures: [
                URL(string: "https://github.com/modelscope/FunASR/releases/download/runtime-llamacpp-v0.1.2/funasr-llamacpp-macos-arm64.tar.gz")!: runtimeSource,
                URL(string: "https://huggingface.co/FunAudioLLM/SenseVoiceSmall-GGUF/resolve/main/sensevoice-small-f16.gguf")!: modelSource,
            ]),
            hasher: FakeHasher(digests: [
                root.appendingPathComponent("AleVoice/downloads/funasr-llamacpp-macos-arm64.tar.gz").path: "50a36463372eb87adf9e0829aa62b29ce94d7ba84ded705b9e81c768c274d923",
                root.appendingPathComponent("AleVoice/downloads/sensevoice-small-f16.gguf").path: "2389039651f4574dbd674f1f1e296b8b1147b2e19a5fd9c2cd69e82669c78d8e",
            ]),
            extractor: FakeExtractor { destination in
                let binaryURL = destination.appendingPathComponent("llama-funasr-sensevoice")
                try Data("bin".utf8).write(to: binaryURL)
                try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: binaryURL.path)
            },
            doctor: { _ in SetupDoctorResult(checks: []) }
        )

        let result = try installer.install(
            request: .init(
                manifest: manifest,
                installRoot: root.appendingPathComponent("AleVoice", isDirectory: true),
                configURL: root.appendingPathComponent("Config/speech-engine.json"),
                platform: .macOSArm64,
                variantName: nil,
                forceDownload: false
            )
        )

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: result.binaryURL.path))
    }
}

private struct FakeDownloader: ArtifactDownloading {
    let fixtures: [URL: URL]

    func download(from url: URL, to destinationURL: URL) throws {
        guard let fixture = fixtures[url] else {
            throw SetupInstallerError.downloadFailed("missing fixture for \(url.absoluteString)")
        }
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: fixture, to: destinationURL)
    }
}

private struct FakeHasher: SHA256Hashing {
    let digests: [String: String]

    func digest(of fileURL: URL) throws -> String {
        digests[fileURL.path, default: ""]
    }
}

private struct FakeExtractor: ArchiveExtracting {
    let body: (URL) throws -> Void

    func extract(archiveAt: URL, kind: ArtifactUnpackKind, to destinationURL: URL) throws {
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        try body(destinationURL)
    }
}
