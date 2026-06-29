import Foundation
import XCTest
@testable import AleVoiceCLI
@testable import AleVoiceCore

final class SetupInstallerTests: XCTestCase {
    func test_setupMergesSecondEngineIntoExistingConfig() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let downloads = root.appendingPathComponent("fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)

        let runtimeSource = downloads.appendingPathComponent("runtime.tar.gz")
        let modelSource = downloads.appendingPathComponent("sensevoice-small-f16.gguf")
        let nanoRuntimeSource = downloads.appendingPathComponent("nano-runtime.tar.gz")
        let nanoModelSource = downloads.appendingPathComponent("qwen3-0.6b-q4km.gguf")
        let nanoEncoderSource = downloads.appendingPathComponent("funasr-encoder-f16.gguf")
        try Data("runtime".utf8).write(to: runtimeSource)
        try Data("model".utf8).write(to: modelSource)
        try Data("nano-runtime".utf8).write(to: nanoRuntimeSource)
        try Data("nano-model".utf8).write(to: nanoModelSource)
        try Data("nano-encoder".utf8).write(to: nanoEncoderSource)

        let senseVoiceManifest = try SetupManifest.load(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Config/engines/funasr-sensevoice.json")
        )
        let nanoManifest = try SetupManifest.load(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Config/engines/funasr-nano.json")
        )
        let configURL = root.appendingPathComponent("Config/speech-engine.json")

        let installer = SetupInstaller(
            downloader: FakeDownloader(fixtures: [
                URL(string: "https://github.com/modelscope/FunASR/releases/download/runtime-llamacpp-v0.1.2/funasr-llamacpp-macos-arm64.tar.gz")!: runtimeSource,
                URL(string: "https://huggingface.co/FunAudioLLM/SenseVoiceSmall-GGUF/resolve/main/sensevoice-small-f16.gguf")!: modelSource,
                URL(string: "https://github.com/modelscope/FunASR/releases/download/runtime-llamacpp-v0.1.3/funasr-llamacpp-macos-arm64.tar.gz")!: nanoRuntimeSource,
                URL(string: "https://huggingface.co/FunAudioLLM/Fun-ASR-Nano-GGUF/resolve/main/qwen3-0.6b-q4km.gguf")!: nanoModelSource,
                URL(string: "https://huggingface.co/FunAudioLLM/Fun-ASR-Nano-GGUF/resolve/main/funasr-encoder-f16.gguf")!: nanoEncoderSource,
            ]),
            hasher: FakeHasher(digests: [
                runtimeSource.path: "50a36463372eb87adf9e0829aa62b29ce94d7ba84ded705b9e81c768c274d923",
                modelSource.path: "2389039651f4574dbd674f1f1e296b8b1147b2e19a5fd9c2cd69e82669c78d8e",
                nanoRuntimeSource.path: "6bb457c9d841441823b253d7f631d7c7f04c55c26cc67fa98a0bd511f9e709ab",
                nanoModelSource.path: "cc5057552aa9dddedcda73ea8889854e8a257eb07d0a561b7234465c1e856f22",
                nanoEncoderSource.path: "f92f91d01a24fbed6c863495b2ee8c6a6788144a02858b75743f0946668de8a2",
                root.appendingPathComponent("AleVoice/downloads/funasr-sensevoice-funasr-llamacpp-macos-arm64.tar.gz").path: "50a36463372eb87adf9e0829aa62b29ce94d7ba84ded705b9e81c768c274d923",
                root.appendingPathComponent("AleVoice/downloads/funasr-sensevoice-sensevoice-small-f16.gguf").path: "2389039651f4574dbd674f1f1e296b8b1147b2e19a5fd9c2cd69e82669c78d8e",
                root.appendingPathComponent("AleVoice/downloads/funasr-nano-funasr-llamacpp-macos-arm64.tar.gz").path: "6bb457c9d841441823b253d7f631d7c7f04c55c26cc67fa98a0bd511f9e709ab",
                root.appendingPathComponent("AleVoice/downloads/funasr-nano-qwen3-0.6b-q4km.gguf").path: "cc5057552aa9dddedcda73ea8889854e8a257eb07d0a561b7234465c1e856f22",
                root.appendingPathComponent("AleVoice/downloads/funasr-nano-funasr-encoder-f16.gguf").path: "f92f91d01a24fbed6c863495b2ee8c6a6788144a02858b75743f0946668de8a2",
            ]),
            extractor: FakeExtractor { destination, archiveName in
                let binaryName = archiveName.contains("nano") ? "llama-funasr-cli" : "llama-funasr-sensevoice"
                try Data("bin".utf8).write(to: destination.appendingPathComponent(binaryName))
            },
            doctor: { _ in SetupDoctorResult(checks: []) }
        )

        _ = try installer.install(
            request: .init(
                manifest: senseVoiceManifest,
                installRoot: root.appendingPathComponent("AleVoice", isDirectory: true),
                configURL: configURL,
                platform: .macOSArm64,
                variantName: nil,
                forceDownload: false
            )
        )

        _ = try installer.install(
            request: .init(
                manifest: nanoManifest,
                installRoot: root.appendingPathComponent("AleVoice", isDirectory: true),
                configURL: configURL,
                platform: .macOSArm64,
                variantName: nil,
                forceDownload: false
            )
        )

        let saved = try SpeechEngineSettings.load(from: configURL)
        XCTAssertEqual(saved.engines.keys.sorted(), ["funasr-nano", "funasr-sensevoice"])
        XCTAssertEqual(saved.selectedEngineID, "funasr-sensevoice")
        XCTAssertEqual(saved.selectedMode, .auto)
    }

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
                root.appendingPathComponent("AleVoice/downloads/funasr-sensevoice-funasr-llamacpp-macos-arm64.tar.gz").path: "50a36463372eb87adf9e0829aa62b29ce94d7ba84ded705b9e81c768c274d923",
                root.appendingPathComponent("AleVoice/downloads/funasr-sensevoice-sensevoice-small-f16.gguf").path: "2389039651f4574dbd674f1f1e296b8b1147b2e19a5fd9c2cd69e82669c78d8e",
            ]),
            extractor: FakeExtractor { destination, _ in
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

    func test_setupInstallsAuxiliaryNanoEncoderModel() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let downloads = root.appendingPathComponent("fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)

        let runtimeSource = downloads.appendingPathComponent("nano-runtime.tar.gz")
        let modelSource = downloads.appendingPathComponent("qwen3-0.6b-q4km.gguf")
        let encoderSource = downloads.appendingPathComponent("funasr-encoder-f16.gguf")
        try Data("nano-runtime".utf8).write(to: runtimeSource)
        try Data("nano-model".utf8).write(to: modelSource)
        try Data("nano-encoder".utf8).write(to: encoderSource)

        let manifest = try SetupManifest.load(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Config/engines/funasr-nano.json")
        )
        let configURL = root.appendingPathComponent("Config/speech-engine.json")

        let installer = SetupInstaller(
            downloader: FakeDownloader(fixtures: [
                URL(string: "https://github.com/modelscope/FunASR/releases/download/runtime-llamacpp-v0.1.3/funasr-llamacpp-macos-arm64.tar.gz")!: runtimeSource,
                URL(string: "https://huggingface.co/FunAudioLLM/Fun-ASR-Nano-GGUF/resolve/main/qwen3-0.6b-q4km.gguf")!: modelSource,
                URL(string: "https://huggingface.co/FunAudioLLM/Fun-ASR-Nano-GGUF/resolve/main/funasr-encoder-f16.gguf")!: encoderSource,
            ]),
            hasher: FakeHasher(digests: [
                runtimeSource.path: "6bb457c9d841441823b253d7f631d7c7f04c55c26cc67fa98a0bd511f9e709ab",
                modelSource.path: "cc5057552aa9dddedcda73ea8889854e8a257eb07d0a561b7234465c1e856f22",
                encoderSource.path: "f92f91d01a24fbed6c863495b2ee8c6a6788144a02858b75743f0946668de8a2",
                root.appendingPathComponent("AleVoice/downloads/funasr-nano-funasr-llamacpp-macos-arm64.tar.gz").path: "6bb457c9d841441823b253d7f631d7c7f04c55c26cc67fa98a0bd511f9e709ab",
                root.appendingPathComponent("AleVoice/downloads/funasr-nano-qwen3-0.6b-q4km.gguf").path: "cc5057552aa9dddedcda73ea8889854e8a257eb07d0a561b7234465c1e856f22",
                root.appendingPathComponent("AleVoice/downloads/funasr-nano-funasr-encoder-f16.gguf").path: "f92f91d01a24fbed6c863495b2ee8c6a6788144a02858b75743f0946668de8a2",
            ]),
            extractor: FakeExtractor { destination, _ in
                try Data("bin".utf8).write(to: destination.appendingPathComponent("llama-funasr-cli"))
            },
            doctor: { _ in SetupDoctorResult(checks: []) }
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
        XCTAssertEqual(saved.selectedEngineID, "funasr-nano")
        XCTAssertEqual(saved.selectedEngineConfig.auxiliaryModelPaths["encoder"], root.appendingPathComponent("AleVoice/engines/funasr-nano/current/models/funasr-encoder-f16.gguf").path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.selectedEngineConfig.auxiliaryModelPaths["encoder"]!))
        XCTAssertEqual(result.binaryURL.lastPathComponent, "llama-funasr-cli")
    }

    func test_setupInstallsMLTNanoAndPersistsRuntimeProfile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let downloads = root.appendingPathComponent("fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)

        let runtimeSource = downloads.appendingPathComponent("crispasr-macos.tar.gz")
        let modelSource = downloads.appendingPathComponent("funasr-mlt-nano-2512-q8_0.gguf")
        try Data("runtime".utf8).write(to: runtimeSource)
        try Data("model".utf8).write(to: modelSource)

        let manifest = try SetupManifest.load(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Config/engines/funasr-mlt-nano.json")
        )
        let configURL = root.appendingPathComponent("Config/speech-engine.json")

        let installer = SetupInstaller(
            downloader: FakeDownloader(fixtures: [
                URL(string: "https://github.com/CrispStrobe/CrispASR/releases/download/v0.8.5/crispasr-macos.tar.gz")!: runtimeSource,
                URL(string: "https://huggingface.co/cstr/funasr-mlt-nano-GGUF/resolve/main/funasr-mlt-nano-2512-q8_0.gguf")!: modelSource,
            ]),
            hasher: FakeHasher(digests: [
                root.appendingPathComponent("AleVoice/downloads/funasr-mlt-nano-crispasr-macos.tar.gz").path: "6b01588c4833b419d562229a3a3dcba597105ba97d9e1f09974bb43b85d5be82",
                root.appendingPathComponent("AleVoice/downloads/funasr-mlt-nano-funasr-mlt-nano-2512-q8_0.gguf").path: "29d9ccaea032650bc747a33947f65f940bcbcf019d9f11471e4e8e0d7bab1b04",
            ]),
            extractor: FakeExtractor { destination, _ in
                let binaryURL = destination
                    .appendingPathComponent("crispasr-macos", isDirectory: true)
                    .appendingPathComponent("crispasr")
                try FileManager.default.createDirectory(
                    at: binaryURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try Data("bin".utf8).write(to: binaryURL)
            },
            doctor: { _ in SetupDoctorResult(checks: []) }
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
        XCTAssertEqual(saved.selectedEngineID, "funasr-mlt-nano")
        XCTAssertEqual(saved.selectedMode, .auto)
        XCTAssertEqual(saved.selectedEngineConfig.runtimeProfile, .crispASRFunASR)
        XCTAssertEqual(saved.selectedEngineConfig.supportedModes, [.auto, .en, .vi])
        XCTAssertEqual(result.binaryURL.path, root.appendingPathComponent("AleVoice/engines/funasr-mlt-nano/current/runtime/crispasr-macos/crispasr").path)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: result.binaryURL.path))
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
            extractor: FakeExtractor { _, _ in },
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
                    artifact: "funasr-sensevoice-funasr-llamacpp-macos-arm64.tar.gz",
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
                root.appendingPathComponent("AleVoice/downloads/funasr-sensevoice-funasr-llamacpp-macos-arm64.tar.gz").path: "50a36463372eb87adf9e0829aa62b29ce94d7ba84ded705b9e81c768c274d923",
                root.appendingPathComponent("AleVoice/downloads/funasr-sensevoice-sensevoice-small-f16.gguf").path: "2389039651f4574dbd674f1f1e296b8b1147b2e19a5fd9c2cd69e82669c78d8e",
            ]),
            extractor: FakeExtractor { destination, _ in
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
    let body: (URL, String) throws -> Void

    func extract(archiveAt: URL, kind: ArtifactUnpackKind, to destinationURL: URL) throws {
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        try body(destinationURL, archiveAt.lastPathComponent)
    }
}
