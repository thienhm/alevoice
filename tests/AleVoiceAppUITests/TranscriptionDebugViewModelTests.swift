import XCTest
@testable import AleVoiceAppUI
import AleVoiceCore

final class TranscriptionDebugViewModelTests: XCTestCase {
    @MainActor
    func test_runSampleUpdatesTranscriptAndLatency() async throws {
        let result = SpeechTranscriptionResult(
            engine: .funasr,
            modelIdentifier: "sensevoice-small",
            transcript: "hello world",
            latencyMs: 210
        )
        let viewModel = TranscriptionDebugViewModel(
            transcribe: { _, _, _ async throws in result }
        )

        await viewModel.runSample(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            audioURL: URL(fileURLWithPath: "/tmp/sample.wav"),
            mode: .auto
        )

        XCTAssertEqual(viewModel.transcript, "hello world")
        XCTAssertEqual(viewModel.latencyText, "210 ms")
        XCTAssertNil(viewModel.errorText)
    }

    @MainActor
    func test_runSampleClearsPriorSuccessStateWhenTranscriptionFails() async throws {
        enum StubError: Error {
            case failed
        }

        let callCounter = CallCounter()
        let viewModel = TranscriptionDebugViewModel(
            transcribe: { _, _, _ async throws in
                if await callCounter.next() == 1 {
                    return SpeechTranscriptionResult(
                        engine: .funasr,
                        modelIdentifier: "sensevoice-small",
                        transcript: "previous success",
                        latencyMs: 321
                    )
                }
                throw StubError.failed
            }
        )

        await viewModel.runSample(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            audioURL: URL(fileURLWithPath: "/tmp/sample.wav"),
            mode: .auto
        )
        await viewModel.runSample(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            audioURL: URL(fileURLWithPath: "/tmp/sample.wav"),
            mode: .auto
        )

        XCTAssertEqual(viewModel.transcript, "")
        XCTAssertEqual(viewModel.latencyText, "")
        XCTAssertEqual(viewModel.errorText, "failed")
    }

    @MainActor
    func test_runSampleIgnoresStaleEarlierCompletionDuringOverlap() async throws {
        let gate = AsyncGate()
        let viewModel = TranscriptionDebugViewModel(
            transcribe: { _, audioURL, _ async throws in
                if audioURL.lastPathComponent == "first.wav" {
                    await gate.wait()
                    return SpeechTranscriptionResult(
                        engine: .funasr,
                        modelIdentifier: "sensevoice-small",
                        transcript: "stale first",
                        latencyMs: 999
                    )
                }

                return SpeechTranscriptionResult(
                    engine: .funasr,
                    modelIdentifier: "sensevoice-small",
                    transcript: "fresh second",
                    latencyMs: 111
                )
            }
        )

        let firstTask = Task {
            await viewModel.runSample(
                configURL: URL(fileURLWithPath: "/tmp/config.json"),
                audioURL: URL(fileURLWithPath: "/tmp/first.wav"),
                mode: .auto
            )
        }

        await Task.yield()
        XCTAssertTrue(viewModel.isRunning)

        let secondTask = Task {
            await viewModel.runSample(
                configURL: URL(fileURLWithPath: "/tmp/config.json"),
                audioURL: URL(fileURLWithPath: "/tmp/second.wav"),
                mode: .auto
            )
        }

        await secondTask.value
        XCTAssertFalse(viewModel.isRunning)

        await gate.release()
        await firstTask.value

        XCTAssertEqual(viewModel.transcript, "fresh second")
        XCTAssertEqual(viewModel.latencyText, "111 ms")
        XCTAssertNil(viewModel.errorText)
        XCTAssertFalse(viewModel.isRunning)
    }
}

private actor CallCounter {
    private var count = 0

    func next() -> Int {
        count += 1
        return count
    }
}

private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}
