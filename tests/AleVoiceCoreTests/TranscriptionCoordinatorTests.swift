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
            standardOutput: output.append,
            standardError: errorOutput.append
        )

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(output.text, CLIArguments.usage + "\n")
        XCTAssertEqual(errorOutput.text, "")
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
