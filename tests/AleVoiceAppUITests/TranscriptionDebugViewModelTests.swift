import XCTest
@testable import AleVoiceAppUI
import AleVoiceCore

final class TranscriptionDebugViewModelTests: XCTestCase {
    @MainActor
    func test_refreshPermissionStatusShowsAuthorizedState() async throws {
        let viewModel = TranscriptionDebugViewModel(
            microphonePermissionStatus: { .authorized },
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )

        await viewModel.refreshPermissionStatus()

        XCTAssertEqual(viewModel.permissionStatusText, "Microphone permission: authorized")
    }

    @MainActor
    func test_refreshPermissionStatusShowsDeniedState() async throws {
        let viewModel = TranscriptionDebugViewModel(
            microphonePermissionStatus: { .denied },
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )

        await viewModel.refreshPermissionStatus()

        XCTAssertEqual(viewModel.permissionStatusText, "Microphone permission: denied")
    }

    @MainActor
    func test_startRecordingUpdatesRecordingState() async throws {
        let probe = RecordingProbe()
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {
                await probe.markStart()
            },
            stopRecording: {
                fatalError("stopRecording should not be called")
            },
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )

        await viewModel.startRecording()

        let didStart = await probe.didStart()
        XCTAssertTrue(didStart)
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.recordingStatusText, "Recording in progress")
        XCTAssertNil(viewModel.errorText)
    }

    @MainActor
    func test_startRecordingMarksRunningWhileStartIsInFlight() async throws {
        let gate = AsyncGate()
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {
                await gate.wait()
            },
            stopRecording: {
                fatalError("stopRecording should not be called")
            },
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )

        let task = Task {
            await viewModel.startRecording()
        }

        await Task.yield()
        XCTAssertTrue(viewModel.isRunning)
        XCTAssertFalse(viewModel.isRecording)

        await gate.release()
        await task.value

        XCTAssertFalse(viewModel.isRunning)
        XCTAssertTrue(viewModel.isRecording)
    }

    @MainActor
    func test_startRecordingRefreshesPermissionStatusAfterDeniedStart() async throws {
        let viewModel = TranscriptionDebugViewModel(
            microphonePermissionStatus: { .denied },
            startRecording: {
                throw AudioRecorderError.permissionDenied
            },
            stopRecording: {
                fatalError("stopRecording should not be called")
            },
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )

        await viewModel.startRecording()

        XCTAssertEqual(viewModel.permissionStatusText, "Microphone permission: denied")
        XCTAssertEqual(viewModel.errorText, "Microphone permission denied")
    }

    @MainActor
    func test_stopRecordingTranscribesCapturedAudioWithExplicitMode() async throws {
        let capturedURL = URL(fileURLWithPath: "/tmp/captured.wav")
        let probe = TranscriptionProbe()
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {},
            stopRecording: {
                AudioRecordingResult(audioURL: capturedURL, byteCount: 4_096)
            },
            transcribe: { configURL, audioURL, mode async throws in
                await probe.record(configURL: configURL, audioURL: audioURL, mode: mode)
                return SpeechTranscriptionResult(
                    engine: .funasr,
                    modelIdentifier: "sensevoice-small",
                    transcript: "captured speech",
                    latencyMs: 456
                )
            }
        )

        await viewModel.startRecording()
        await viewModel.stopRecordingAndTranscribe(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            mode: .vi
        )

        let invocation = await probe.invocation()
        XCTAssertEqual(invocation?.configURL, URL(fileURLWithPath: "/tmp/config.json"))
        XCTAssertEqual(invocation?.audioURL, capturedURL)
        XCTAssertEqual(invocation?.mode, .vi)
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(viewModel.recordingStatusText, "Last recording ready")
        XCTAssertEqual(viewModel.transcript, "captured speech")
        XCTAssertEqual(viewModel.latencyText, "456 ms")
        XCTAssertNil(viewModel.errorText)
    }

    @MainActor
    func test_startRecordingSurfacesPermissionDeniedError() async throws {
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {
                throw AudioRecorderError.permissionDenied
            },
            stopRecording: {
                fatalError("stopRecording should not be called")
            },
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )

        await viewModel.startRecording()

        XCTAssertFalse(viewModel.isRecording)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.recordingStatusText, "Recorder idle")
        XCTAssertEqual(viewModel.errorText, "Microphone permission denied")
    }

    @MainActor
    func test_stopRecordingSurfacesEmptyRecordingErrorWithoutTranscribing() async throws {
        let probe = RecordingProbe()
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {},
            stopRecording: {
                await probe.markStop()
                throw AudioRecorderError.emptyRecording
            },
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )

        await viewModel.startRecording()
        await viewModel.stopRecordingAndTranscribe(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            mode: .auto
        )

        let didStop = await probe.didStop()
        XCTAssertTrue(didStop)
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.recordingStatusText, "Recorder idle")
        XCTAssertEqual(viewModel.errorText, "Recording produced no audio")
        XCTAssertEqual(viewModel.transcript, "")
        XCTAssertEqual(viewModel.latencyText, "")
    }

    @MainActor
    func test_runSampleWhileRecordingSurfacesAlreadyRecordingWithoutTranscribing() async throws {
        let probe = TranscriptionProbe()
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {},
            stopRecording: {
                AudioRecordingResult(audioURL: URL(fileURLWithPath: "/tmp/captured.wav"), byteCount: 1_024)
            },
            transcribe: { configURL, audioURL, mode async throws in
                await probe.record(configURL: configURL, audioURL: audioURL, mode: mode)
                return SpeechTranscriptionResult(
                    engine: .funasr,
                    modelIdentifier: "sensevoice-small",
                    transcript: "should not run",
                    latencyMs: 1
                )
            }
        )

        await viewModel.startRecording()
        await viewModel.runSample(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            audioURL: URL(fileURLWithPath: "/tmp/sample.wav"),
            mode: .auto
        )

        let invocation = await probe.invocation()
        XCTAssertNil(invocation)
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.recordingStatusText, "Recording in progress")
        XCTAssertEqual(viewModel.errorText, "Recording is already in progress")
    }

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

private actor RecordingProbe {
    private var started = false
    private var stopped = false

    func markStart() {
        started = true
    }

    func markStop() {
        stopped = true
    }

    func didStart() -> Bool {
        started
    }

    func didStop() -> Bool {
        stopped
    }
}

private actor TranscriptionProbe {
    struct Invocation: Equatable {
        let configURL: URL
        let audioURL: URL
        let mode: SpeechLanguageMode
    }

    private var storedInvocation: Invocation?

    func record(configURL: URL, audioURL: URL, mode: SpeechLanguageMode) {
        storedInvocation = Invocation(configURL: configURL, audioURL: audioURL, mode: mode)
    }

    func invocation() -> Invocation? {
        storedInvocation
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
