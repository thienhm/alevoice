import XCTest
@testable import AleVoiceCore
@testable import AleVoiceCLI

final class TranscriptionCoordinatorTests: XCTestCase {
    func test_transcribeBuildsFunASREngineFromSettingsAndUsesDefaultMode() throws {
        let settings = SpeechEngineSettings(
            engine: .funasr,
            funasr: EnginePathConfig(
                binaryPath: "/tmp/funasr",
                modelPath: "/tmp/funasr.gguf",
                defaultMode: .vi
            )
        )
        let engine = StubEngine(
            result: .init(
                engine: .funasr,
                modelIdentifier: "/tmp/funasr.gguf",
                transcript: "xin chao",
                latencyMs: 111
            )
        )
        var factoryConfig: EnginePathConfig?
        let coordinator = TranscriptionCoordinator(settings: settings) { config in
            factoryConfig = config
            return engine
        }

        let result = try coordinator.transcribe(
            audioURL: URL(fileURLWithPath: "/tmp/vi-001.wav"),
            overrideMode: nil
        )

        XCTAssertEqual(factoryConfig, settings.funasr)
        XCTAssertEqual(engine.lastRequest?.audioURL.path, "/tmp/vi-001.wav")
        XCTAssertEqual(engine.lastRequest?.mode, .vi)
        XCTAssertEqual(result.transcript, "xin chao")
        XCTAssertEqual(result.latencyMs, 111)
    }

    func test_transcribeUsesSelectedModeWhenOverrideIsNil() throws {
        let settings = SpeechEngineSettings(
            selectedEngineID: "funasr-nano",
            selectedMode: .en,
            engines: [
                "funasr-nano": EngineInstallConfig(
                    engineKind: .funasr,
                    displayName: "FunASR Nano",
                    binaryPath: "/tmp/llama-funasr-cli",
                    modelPath: "/tmp/qwen3-0.6b-q4km.gguf",
                    defaultMode: .auto,
                    supportedModes: [.auto, .en],
                    auxiliaryModelPaths: ["encoder": "/tmp/funasr-encoder-f16.gguf"]
                ),
            ]
        )
        let engine = StubEngine(
            result: .init(
                engine: .funasr,
                modelIdentifier: "/tmp/qwen3-0.6b-q4km.gguf",
                transcript: "xin chao",
                latencyMs: 111
            )
        )
        let coordinator = TranscriptionCoordinator(settings: settings) { _ in engine }

        _ = try coordinator.transcribe(
            audioURL: URL(fileURLWithPath: "/tmp/vi-001.wav"),
            overrideMode: nil
        )

        XCTAssertEqual(engine.lastRequest?.mode, .en)
    }

    func test_transcribeUsesOverrideModeWhenProvided() throws {
        let settings = SpeechEngineSettings(
            engine: .funasr,
            funasr: EnginePathConfig(
                binaryPath: "/tmp/funasr",
                modelPath: "/tmp/funasr.gguf",
                defaultMode: .vi
            )
        )
        let engine = StubEngine(
            result: .init(
                engine: .funasr,
                modelIdentifier: "/tmp/funasr.gguf",
                transcript: "hello",
                latencyMs: 87
            )
        )
        let coordinator = TranscriptionCoordinator(settings: settings) { _ in engine }

        _ = try coordinator.transcribe(
            audioURL: URL(fileURLWithPath: "/tmp/en-001.wav"),
            overrideMode: .en
        )

        XCTAssertEqual(engine.lastRequest?.mode, .en)
    }

    func test_cliRunPrintsUsageAndExitsZeroForHelp() {
        let output = LockedTextOutput()
        let errorOutput = LockedTextOutput()

        let exitCode = AleVoiceCLIProgram.run(
            arguments: ["--help"],
            context: .failingDefaults(),
            standardOutput: output.append,
            standardError: errorOutput.append
        )

        XCTAssertEqual(exitCode, 0)
        XCTAssertTrue(output.text.contains("usage: AleVoiceCLI"))
        XCTAssertTrue(output.text.contains("setup funasr-sensevoice"))
        XCTAssertTrue(output.text.contains("setup funasr-nano"))
        XCTAssertTrue(output.text.contains("setup funasr-mlt-nano"))
        XCTAssertTrue(output.text.contains("--mode auto|en|vi"))
        XCTAssertTrue(output.text.contains("build"))
        XCTAssertTrue(output.text.contains("run"))
        XCTAssertEqual(errorOutput.text, "")
    }

    func test_cliMapsLegacyRootFlagsToTranscribe() throws {
        let output = LockedTextOutput()
        let errorOutput = LockedTextOutput()
        var capturedAudioURL: URL?
        var capturedConfigURL: URL?

        let exitCode = AleVoiceCLIProgram.run(
            arguments: ["--config", "/tmp/config.json", "--audio", "/tmp/sample.wav", "--mode", "auto"],
            context: CLIContext(
                manifestLoader: { _ in fatalError("unexpected") },
                installer: { _ in fatalError("unexpected") },
                doctor: { _ in fatalError("unexpected") },
                transcribe: { configURL, audioURL, mode in
                    capturedConfigURL = configURL
                    capturedAudioURL = audioURL
                    XCTAssertEqual(mode, .auto)
                    return .init(engine: .funasr, modelIdentifier: "model", transcript: "hello", latencyMs: 123)
                },
                runApp: { fatalError("unexpected") },
                configPathResolver: { URL(fileURLWithPath: "/tmp/config.json") },
                installRootResolver: { URL(fileURLWithPath: "/tmp/install", isDirectory: true) },
                sampleAudioResolver: { URL(fileURLWithPath: "/tmp/sample.wav") }
            ),
            standardOutput: output.append,
            standardError: errorOutput.append
        )

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(capturedConfigURL?.path, "/tmp/config.json")
        XCTAssertEqual(capturedAudioURL?.path, "/tmp/sample.wav")
        XCTAssertTrue(output.text.contains("engine=funasr"))
        XCTAssertEqual(errorOutput.text, "")
    }

    func test_cliTranscribeOmitsModeSoConfigSelectedModeCanApply() throws {
        let output = LockedTextOutput()
        let errorOutput = LockedTextOutput()
        var capturedMode: SpeechLanguageMode?

        let exitCode = AleVoiceCLIProgram.run(
            arguments: ["transcribe", "--config", "/tmp/config.json", "--audio", "/tmp/sample.wav"],
            context: CLIContext(
                manifestLoader: { _ in fatalError("unexpected") },
                installer: { _ in fatalError("unexpected") },
                doctor: { _ in fatalError("unexpected") },
                transcribe: { _, _, mode in
                    capturedMode = mode
                    return .init(engine: .funasr, modelIdentifier: "model", transcript: "hello", latencyMs: 123)
                },
                runApp: { fatalError("unexpected") },
                configPathResolver: { URL(fileURLWithPath: "/tmp/config.json") },
                installRootResolver: { URL(fileURLWithPath: "/tmp/install", isDirectory: true) },
                sampleAudioResolver: { URL(fileURLWithPath: "/tmp/sample.wav") }
            ),
            standardOutput: output.append,
            standardError: errorOutput.append
        )

        XCTAssertEqual(exitCode, 0)
        XCTAssertNil(capturedMode)
        XCTAssertEqual(errorOutput.text, "")
    }

    func test_cliSetupRunsInstallerForKnownEngine() {
        let output = LockedTextOutput()
        let errorOutput = LockedTextOutput()
        var capturedRequest: SetupInstallRequest?
        let manifest = try! SetupManifest.load(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Config/engines/funasr-sensevoice.json")
        )

        let exitCode = AleVoiceCLIProgram.run(
            arguments: ["setup", "funasr-sensevoice"],
            context: CLIContext(
                manifestLoader: { _ in manifest },
                installer: { request in
                    capturedRequest = request
                    return SetupInstallResult(
                        binaryURL: URL(fileURLWithPath: "/tmp/install/runtime/llama-funasr-sensevoice"),
                        modelURL: URL(fileURLWithPath: "/tmp/install/models/sensevoice-small-f16.gguf"),
                        configURL: URL(fileURLWithPath: "/tmp/config.json"),
                        doctorResult: SetupDoctorResult(checks: [.init(name: "config", status: .passed, detail: "ok")])
                    )
                },
                doctor: { _ in fatalError("unexpected") },
                transcribe: { _, _, _ in fatalError("unexpected") },
                runApp: { fatalError("unexpected") },
                configPathResolver: { URL(fileURLWithPath: "/tmp/config.json") },
                installRootResolver: { URL(fileURLWithPath: "/tmp/install", isDirectory: true) },
                sampleAudioResolver: { URL(fileURLWithPath: "/tmp/sample.wav") }
            ),
            standardOutput: output.append,
            standardError: errorOutput.append
        )

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(capturedRequest?.manifest.id, "funasr-sensevoice")
        XCTAssertTrue(output.text.contains("installed funasr-sensevoice"))
        XCTAssertEqual(errorOutput.text, "")
    }

    func test_cliDoctorReportsMissingConfig() {
        let output = LockedTextOutput()
        let errorOutput = LockedTextOutput()

        let exitCode = AleVoiceCLIProgram.run(
            arguments: ["doctor"],
            context: CLIContext(
                manifestLoader: { _ in fatalError("unexpected") },
                installer: { _ in fatalError("unexpected") },
                doctor: { _ in
                    SetupDoctorResult(
                        checks: [.init(name: "config", status: .failed, detail: "missing config")]
                    )
                },
                transcribe: { _, _, _ in fatalError("unexpected") },
                runApp: { fatalError("unexpected") },
                configPathResolver: { URL(fileURLWithPath: "/tmp/missing-config.json") },
                installRootResolver: { URL(fileURLWithPath: "/tmp/install", isDirectory: true) },
                sampleAudioResolver: { URL(fileURLWithPath: "/tmp/sample.wav") }
            ),
            standardOutput: output.append,
            standardError: errorOutput.append
        )

        XCTAssertEqual(exitCode, 1)
        XCTAssertTrue(output.text.contains("config: failed"))
        XCTAssertEqual(errorOutput.text, "")
    }

    func test_doctorReportsSelectedModeAndAuxiliaryModel() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let binaryURL = root.appendingPathComponent("llama-funasr-cli")
        let modelURL = root.appendingPathComponent("qwen3-0.6b-q4km.gguf")
        let encoderURL = root.appendingPathComponent("funasr-encoder-f16.gguf")
        let sampleURL = root.appendingPathComponent("sample.wav")
        try Data("bin".utf8).write(to: binaryURL)
        try Data("model".utf8).write(to: modelURL)
        try Data("encoder".utf8).write(to: encoderURL)
        try Data("audio".utf8).write(to: sampleURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binaryURL.path)
        let configURL = root.appendingPathComponent("speech-engine.json")
        let settings = SpeechEngineSettings(
            selectedEngineID: "funasr-nano",
            selectedMode: .en,
            engines: [
                "funasr-nano": EngineInstallConfig(
                    engineKind: .funasr,
                    displayName: "FunASR Nano",
                    binaryPath: binaryURL.path,
                    modelPath: modelURL.path,
                    defaultMode: .auto,
                    supportedModes: [.auto, .en],
                    auxiliaryModelPaths: ["encoder": encoderURL.path]
                ),
            ]
        )
        try settings.save(to: configURL)

        let result = try AleVoiceDoctor(
            sampleAudioResolver: { sampleURL },
            transcribe: { _, _, mode in
                XCTAssertEqual(mode, .en)
                return .init(engine: .funasr, modelIdentifier: "model", transcript: "ok", latencyMs: 1)
            }
        ).run(configURL: configURL)

        XCTAssertTrue(result.checks.contains(.init(name: "selected-mode", status: .passed, detail: "en")))
        XCTAssertTrue(result.checks.contains(.init(name: "auxiliary-model:encoder", status: .passed, detail: encoderURL.path)))
    }

    func test_cliBuildInvokesAppBuilder() {
        let output = LockedTextOutput()
        let errorOutput = LockedTextOutput()
        var invoked = false

        let exitCode = AleVoiceCLIProgram.run(
            arguments: ["build"],
            context: CLIContext(
                manifestLoader: { _ in fatalError("unexpected") },
                installer: { _ in fatalError("unexpected") },
                doctor: { _ in fatalError("unexpected") },
                transcribe: { _, _, _ in fatalError("unexpected") },
                buildApp: { invoked = true },
                runApp: { fatalError("unexpected") },
                configPathResolver: { URL(fileURLWithPath: "/tmp/config.json") },
                installRootResolver: { URL(fileURLWithPath: "/tmp/install", isDirectory: true) },
                sampleAudioResolver: { URL(fileURLWithPath: "/tmp/sample.wav") }
            ),
            standardOutput: output.append,
            standardError: errorOutput.append
        )

        XCTAssertEqual(exitCode, 0)
        XCTAssertTrue(invoked)
        XCTAssertTrue(output.text.contains("built app"))
        XCTAssertEqual(errorOutput.text, "")
    }

    func test_cliRunInvokesAppRunnerWithoutBuilding() {
        let output = LockedTextOutput()
        let errorOutput = LockedTextOutput()
        var buildInvoked = false
        var runInvoked = false

        let exitCode = AleVoiceCLIProgram.run(
            arguments: ["run"],
            context: CLIContext(
                manifestLoader: { _ in fatalError("unexpected") },
                installer: { _ in fatalError("unexpected") },
                doctor: { _ in fatalError("unexpected") },
                transcribe: { _, _, _ in fatalError("unexpected") },
                buildApp: { buildInvoked = true },
                runApp: { runInvoked = true },
                configPathResolver: { URL(fileURLWithPath: "/tmp/config.json") },
                installRootResolver: { URL(fileURLWithPath: "/tmp/install", isDirectory: true) },
                sampleAudioResolver: { URL(fileURLWithPath: "/tmp/sample.wav") }
            ),
            standardOutput: output.append,
            standardError: errorOutput.append
        )

        XCTAssertEqual(exitCode, 0)
        XCTAssertFalse(buildInvoked)
        XCTAssertTrue(runInvoked)
        XCTAssertTrue(output.text.contains("launching app"))
        XCTAssertEqual(errorOutput.text, "")
    }

    func test_cliRunSurfacesRunnerFailureWhenBundleIsMissing() {
        let output = LockedTextOutput()
        let errorOutput = LockedTextOutput()

        let exitCode = AleVoiceCLIProgram.run(
            arguments: ["run"],
            context: CLIContext(
                manifestLoader: { _ in fatalError("unexpected") },
                installer: { _ in fatalError("unexpected") },
                doctor: { _ in fatalError("unexpected") },
                transcribe: { _, _, _ in fatalError("unexpected") },
                runApp: { throw CLIError(description: "app bundle not found at /tmp/build/AleVoice.app; build it first") },
                configPathResolver: { URL(fileURLWithPath: "/tmp/config.json") },
                installRootResolver: { URL(fileURLWithPath: "/tmp/install", isDirectory: true) },
                sampleAudioResolver: { URL(fileURLWithPath: "/tmp/sample.wav") }
            ),
            standardOutput: output.append,
            standardError: errorOutput.append
        )

        XCTAssertEqual(exitCode, 1)
        XCTAssertEqual(output.text, "")
        XCTAssertTrue(errorOutput.text.contains("build it first"))
    }

    func test_cliParserRejectsFlagTokenAsConfigValue() {
        XCTAssertThrowsError(try CLIArguments(arguments: ["--config", "--audio", "/tmp/sample.wav"])) { error in
            XCTAssertEqual(
                error as? CLIError,
                CLIError(description: "missing value for --config")
            )
        }
    }

    func test_cliParserRejectsFlagTokenAsAudioValue() {
        XCTAssertThrowsError(try CLIArguments(arguments: ["--config", "/tmp/config.json", "--audio", "--mode", "en"])) { error in
            XCTAssertEqual(
                error as? CLIError,
                CLIError(description: "missing value for --audio")
            )
        }
    }

    func test_cliParserRejectsShortFlagTokenAsAudioValue() {
        XCTAssertThrowsError(try CLIArguments(arguments: ["--config", "/tmp/config.json", "--audio", "-h"])) { error in
            XCTAssertEqual(
                error as? CLIError,
                CLIError(description: "missing value for --audio")
            )
        }
    }

    func test_cliParserRejectsFlagTokenAsModeValue() {
        XCTAssertThrowsError(try CLIArguments(arguments: ["--config", "/tmp/config.json", "--audio", "/tmp/sample.wav", "--mode", "--help"])) { error in
            XCTAssertEqual(
                error as? CLIError,
                CLIError(description: "missing value for --mode")
            )
        }
    }
}

private final class StubEngine: @unchecked Sendable, SpeechEngine {
    let result: SpeechTranscriptionResult
    private(set) var lastRequest: SpeechTranscriptionRequest?

    init(result: SpeechTranscriptionResult) {
        self.result = result
    }

    func transcribe(_ request: SpeechTranscriptionRequest) throws -> SpeechTranscriptionResult {
        lastRequest = request
        return result
    }
}

private final class LockedTextOutput: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var text = ""

    func append(_ value: String) {
        lock.lock()
        defer { lock.unlock() }
        text += value
    }
}
