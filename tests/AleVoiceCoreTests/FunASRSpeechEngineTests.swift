import XCTest
@testable import AleVoiceCore

final class FunASRSpeechEngineTests: XCTestCase {
    func test_buildCommandMatchesBenchmarkShapeForAutoMode() throws {
        let config = EnginePathConfig(
            binaryPath: "/tmp/funasr",
            modelPath: "/tmp/funasr.gguf",
            defaultMode: .auto
        )
        let engine = FunASRSpeechEngine(config: config, runner: FakeRunner())
        let request = SpeechTranscriptionRequest(
            audioURL: URL(fileURLWithPath: "/tmp/en-001.wav"),
            mode: .auto
        )

        XCTAssertEqual(
            try engine.buildCommand(for: request),
            ["/tmp/funasr", "-m", "/tmp/funasr.gguf", "-a", "/tmp/en-001.wav"]
        )
    }

    func test_buildCommandRejectsExplicitLanguageModeWhenRuntimeLacksFlag() throws {
        let config = EnginePathConfig(
            binaryPath: "/tmp/funasr",
            modelPath: "/tmp/funasr.gguf",
            defaultMode: .auto
        )
        let engine = FunASRSpeechEngine(config: config, runner: FakeRunner())
        let request = SpeechTranscriptionRequest(
            audioURL: URL(fileURLWithPath: "/tmp/en-001.wav"),
            mode: .en
        )

        XCTAssertThrowsError(try engine.buildCommand(for: request)) { error in
            XCTAssertEqual(
                error as? SpeechEngineError,
                .invalidConfiguration("funasr runtime does not support explicit language mode 'en'")
            )
        }
    }

    func test_transcribeStripsTimestampWrapperAndReturnsLatency() throws {
        let runner = FakeRunner(
            stdout: "[00:00:00.000 --> 00:00:02.000]   hello from engine\n",
            latencyMs: 250
        )
        let config = EnginePathConfig(
            binaryPath: "/tmp/funasr",
            modelPath: "/tmp/funasr.gguf",
            defaultMode: .auto
        )
        let engine = FunASRSpeechEngine(config: config, runner: runner)

        let result = try engine.transcribe(
            SpeechTranscriptionRequest(
                audioURL: URL(fileURLWithPath: "/tmp/en-001.wav"),
                mode: .auto
            )
        )

        XCTAssertEqual(result.engine, .funasr)
        XCTAssertEqual(result.modelIdentifier, "/tmp/funasr.gguf")
        XCTAssertEqual(result.transcript, "hello from engine")
        XCTAssertEqual(result.latencyMs, 250)
    }

    func test_transcribePreservesBracketTextThatIsNotTimestampWrapper() throws {
        let runner = FakeRunner(
            stdout: "INFO [00:00:00.000 --> 00:00:02.000] first ] final transcript\n",
            latencyMs: 250
        )
        let config = EnginePathConfig(
            binaryPath: "/tmp/funasr",
            modelPath: "/tmp/funasr.gguf",
            defaultMode: .auto
        )
        let engine = FunASRSpeechEngine(config: config, runner: runner)

        let result = try engine.transcribe(
            SpeechTranscriptionRequest(
                audioURL: URL(fileURLWithPath: "/tmp/en-001.wav"),
                mode: .auto
            )
        )

        XCTAssertEqual(result.transcript, "INFO [00:00:00.000 --> 00:00:02.000] first ] final transcript")
    }

    func test_transcribePreservesNonTimestampBracketText() throws {
        let runner = FakeRunner(
            stdout: "set array[0] to value\n",
            latencyMs: 250
        )
        let config = EnginePathConfig(
            binaryPath: "/tmp/funasr",
            modelPath: "/tmp/funasr.gguf",
            defaultMode: .auto
        )
        let engine = FunASRSpeechEngine(config: config, runner: runner)

        let result = try engine.transcribe(
            SpeechTranscriptionRequest(
                audioURL: URL(fileURLWithPath: "/tmp/en-001.wav"),
                mode: .auto
            )
        )

        XCTAssertEqual(result.transcript, "set array[0] to value")
    }

    func test_systemRunnerCompletesWithLargeStdoutAndStderr() throws {
        let runner = SystemProcessRunner(timeoutSeconds: 5)
        let output = try runner.run(
            command: [
                "/bin/sh",
                "-c",
                "i=0; while [ $i -lt 20000 ]; do echo out; echo err >&2; i=$((i + 1)); done",
            ]
        )

        XCTAssertTrue(output.stdout.hasPrefix("out\nout\n"))
        XCTAssertTrue(output.stderr.hasPrefix("err\nerr\n"))
    }

    func test_systemRunnerTimeoutFailsQuickly() throws {
        let runner = SystemProcessRunner(timeoutSeconds: 0.1)

        do {
            _ = try runner.run(command: ["/bin/sh", "-c", "sleep 5"])
            XCTFail("Expected timeout failure")
        } catch let error as SpeechEngineError {
            XCTAssertEqual(error, .processFailure("funasr timed out after 0.1s"))
        }
    }

    func test_systemRunnerEmptyCommandThrowsProcessFailure() throws {
        let runner = SystemProcessRunner()

        do {
            _ = try runner.run(command: [])
            XCTFail("Expected process failure")
        } catch let error as SpeechEngineError {
            XCTAssertEqual(error, .processFailure("empty command"))
        }
    }

    func test_systemRunnerMapsNonzeroExitToProcessFailure() throws {
        let runner = SystemProcessRunner()

        do {
            _ = try runner.run(
                command: ["/bin/sh", "-c", "echo runner-failed >&2; exit 7"]
            )
            XCTFail("Expected process failure")
        } catch let error as SpeechEngineError {
            XCTAssertEqual(error, .processFailure("runner-failed"))
        }
    }

    func test_systemRunnerUsesExactFallbackMessageWhenStderrEmpty() throws {
        let runner = SystemProcessRunner()

        do {
            _ = try runner.run(
                command: ["/bin/sh", "-c", "exit 9"]
            )
            XCTFail("Expected process failure")
        } catch let error as SpeechEngineError {
            XCTAssertEqual(error, .processFailure("funasr exited 9"))
        }
    }
}

private struct FakeRunner: ProcessRunning {
    var stdout: String = "hello from engine\n"
    var stderr: String = ""
    var latencyMs: Int = 250

    func run(command: [String]) throws -> ProcessOutput {
        ProcessOutput(stdout: stdout, stderr: stderr, latencyMs: latencyMs)
    }
}
