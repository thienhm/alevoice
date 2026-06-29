import XCTest
@testable import AleVoiceAppUI
import AleVoiceCore

final class TranscriptionDebugViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: TranscriptionDebugViewModel.dictationEnabledDefaultsKey)
    }

    @MainActor
    func test_dictationEnabledDefaultsToTrueWhenPreferenceIsMissing() {
        let defaults = UserDefaults(suiteName: "TranscriptionDebugViewModelTests.default.\(UUID().uuidString)")!
        defaults.removeObject(forKey: TranscriptionDebugViewModel.dictationEnabledDefaultsKey)

        let viewModel = TranscriptionDebugViewModel(
            defaults: defaults,
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )

        XCTAssertTrue(viewModel.isDictationEnabled)
        XCTAssertTrue(viewModel.canToggleDictationEnabled)
    }

    @MainActor
    func test_setDictationEnabledPersistsPreference() {
        let suiteName = "TranscriptionDebugViewModelTests.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removeObject(forKey: TranscriptionDebugViewModel.dictationEnabledDefaultsKey)
        let viewModel = TranscriptionDebugViewModel(
            defaults: defaults,
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )

        viewModel.setDictationEnabled(false)

        let reloadedViewModel = TranscriptionDebugViewModel(
            defaults: UserDefaults(suiteName: suiteName)!,
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )
        XCTAssertFalse(viewModel.isDictationEnabled)
        XCTAssertFalse(reloadedViewModel.isDictationEnabled)
    }

    @MainActor
    func test_dictationEnabledToggleIsUnavailableWhileBusy() async {
        let gate = AsyncGate()
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {
                await gate.wait()
            },
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )

        let task = Task {
            await viewModel.startRecording()
        }
        await Task.yield()
        XCTAssertFalse(viewModel.canToggleDictationEnabled)

        await gate.release()
        await task.value
        XCTAssertFalse(viewModel.canToggleDictationEnabled)
    }

    @MainActor
    func test_startRecordingDoesNothingWhenDictationIsDisabled() async {
        let probe = RecordingProbe()
        let defaults = UserDefaults(suiteName: "TranscriptionDebugViewModelTests.disabledStart.\(UUID().uuidString)")!
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {
                await probe.markStart()
            },
            defaults: defaults,
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )
        viewModel.setDictationEnabled(false)

        await viewModel.startRecording()

        let didStart = await probe.didStart()
        XCTAssertFalse(didStart)
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.recordingStatusText, "Recorder idle")
    }

    @MainActor
    func test_runSampleStillWorksWhenDictationIsDisabled() async throws {
        let result = SpeechTranscriptionResult(
            engine: .funasr,
            modelIdentifier: "sensevoice-small",
            transcript: "sample still works",
            latencyMs: 42
        )
        let defaults = UserDefaults(suiteName: "TranscriptionDebugViewModelTests.disabledSample.\(UUID().uuidString)")!
        let viewModel = TranscriptionDebugViewModel(
            defaults: defaults,
            transcribe: { _, _, _ async throws in result }
        )
        viewModel.setDictationEnabled(false)

        await viewModel.runSample(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            audioURL: URL(fileURLWithPath: "/tmp/sample.wav"),
            mode: .auto
        )

        XCTAssertEqual(viewModel.transcript, "sample still works")
        XCTAssertEqual(viewModel.latencyText, "42 ms")
        XCTAssertNil(viewModel.errorText)
    }

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
    func test_requestMicrophonePermissionUpdatesStatusText() async throws {
        let viewModel = TranscriptionDebugViewModel(
            requestMicrophonePermission: { .authorized },
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )

        await viewModel.requestMicrophonePermission()

        XCTAssertEqual(viewModel.permissionStatusText, "Microphone permission: authorized")
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
    func test_stopRecordingUsesSelectedModeForRecordingFlow() async throws {
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
        viewModel.applySpeechEngineSettings(
            SpeechEngineSettings(
                selectedEngineID: "funasr-nano",
                selectedMode: .vi,
                engines: [
                    "funasr-nano": EngineInstallConfig(
                        engineKind: .funasr,
                        displayName: "FunASR Nano",
                        binaryPath: "/tmp/llama-funasr-cli",
                        modelPath: "/tmp/model.gguf",
                        defaultMode: .auto,
                        supportedModes: [.auto, .en, .vi]
                    ),
                ]
            )
        )

        await viewModel.startRecording()
        await viewModel.stopRecordingAndTranscribe(
            configURL: URL(fileURLWithPath: "/tmp/config.json")
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
    func test_selectingEngineFiltersUnsupportedMode() {
        let viewModel = TranscriptionDebugViewModel(
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )
        viewModel.applySpeechEngineSettings(
            SpeechEngineSettings(
                selectedEngineID: "funasr-nano",
                selectedMode: .vi,
                engines: [
                    "funasr-sensevoice": EngineInstallConfig(
                        engineKind: .funasr,
                        displayName: "FunASR SenseVoice",
                        binaryPath: "/tmp/sensevoice",
                        modelPath: "/tmp/sensevoice.gguf",
                        defaultMode: .auto,
                        supportedModes: [.auto]
                    ),
                    "funasr-nano": EngineInstallConfig(
                        engineKind: .funasr,
                        displayName: "FunASR Nano",
                        binaryPath: "/tmp/nano",
                        modelPath: "/tmp/nano.gguf",
                        defaultMode: .auto,
                        supportedModes: [.auto, .en, .vi]
                    ),
                ]
            )
        )

        viewModel.selectEngine(id: "funasr-sensevoice")

        XCTAssertEqual(viewModel.selectedEngineID, "funasr-sensevoice")
        XCTAssertEqual(viewModel.selectedMode, .auto)
        XCTAssertEqual(viewModel.availableLanguageModes, [.auto])
    }

    @MainActor
    func test_modeOptionsFollowSelectedEngine() {
        let viewModel = TranscriptionDebugViewModel(
            transcribe: { _, _, _ async throws in
                fatalError("transcribe should not be called")
            }
        )
        viewModel.applySpeechEngineSettings(
            SpeechEngineSettings(
                selectedEngineID: "funasr-sensevoice",
                selectedMode: .auto,
                engines: [
                    "funasr-sensevoice": EngineInstallConfig(
                        engineKind: .funasr,
                        displayName: "FunASR SenseVoice",
                        binaryPath: "/tmp/sensevoice",
                        modelPath: "/tmp/sensevoice.gguf",
                        defaultMode: .auto,
                        supportedModes: [.auto]
                    ),
                    "funasr-nano": EngineInstallConfig(
                        engineKind: .funasr,
                        displayName: "FunASR Nano",
                        binaryPath: "/tmp/nano",
                        modelPath: "/tmp/nano.gguf",
                        defaultMode: .auto,
                        supportedModes: [.auto, .en, .vi]
                    ),
                ]
            )
        )

        XCTAssertEqual(viewModel.availableLanguageModes, [.auto])

        viewModel.selectEngine(id: "funasr-nano")

        XCTAssertEqual(viewModel.availableLanguageModes, [.auto, .en, .vi])
    }

    @MainActor
    func test_stopRecordingDeliversSuccessfulTranscript() async throws {
        let outputProbe = TranscriptOutputProbe()
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {},
            stopRecording: {
                AudioRecordingResult(audioURL: URL(fileURLWithPath: "/tmp/captured.wav"), byteCount: 4_096)
            },
            transcribe: { _, _, _ async throws in
                SpeechTranscriptionResult(
                    engine: .funasr,
                    modelIdentifier: "sensevoice-small",
                    transcript: "paste me",
                    latencyMs: 456
                )
            },
            deliverTranscript: { transcript in
                await outputProbe.record(transcript)
            }
        )

        await viewModel.startRecording()
        await viewModel.stopRecordingAndTranscribe(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            mode: .auto
        )

        let delivered = await outputProbe.transcripts()
        XCTAssertEqual(delivered, ["paste me"])
        XCTAssertEqual(viewModel.transcript, "paste me")
        XCTAssertNil(viewModel.errorText)
    }

    @MainActor
    func test_stopRecordingFormatsTranscriptBeforeDelivery() async throws {
        let outputProbe = TranscriptOutputProbe()
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {},
            stopRecording: {
                AudioRecordingResult(audioURL: URL(fileURLWithPath: "/tmp/captured.wav"), byteCount: 4_096)
            },
            transcribe: { _, _, _ async throws in
                SpeechTranscriptionResult(
                    engine: .funasr,
                    modelIdentifier: "sensevoice-small",
                    transcript: "new line benchmark summary colon faster period",
                    latencyMs: 456
                )
            },
            deliverTranscript: { transcript in
                await outputProbe.record(transcript)
            }
        )

        await viewModel.startRecording()
        await viewModel.stopRecordingAndTranscribe(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            mode: .auto
        )

        let delivered = await outputProbe.transcripts()
        XCTAssertEqual(delivered, ["\nbenchmark summary: faster."])
        XCTAssertEqual(viewModel.transcript, "\nbenchmark summary: faster.")
    }

    @MainActor
    func test_sessionStateTracksRecordingProcessingAndSuccess() async throws {
        let gate = AsyncGate()
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {},
            stopRecording: {
                AudioRecordingResult(audioURL: URL(fileURLWithPath: "/tmp/captured.wav"), byteCount: 4_096)
            },
            transcribe: { _, _, _ async throws in
                await gate.wait()
                return SpeechTranscriptionResult(
                    engine: .funasr,
                    modelIdentifier: "sensevoice-small",
                    transcript: "done",
                    latencyMs: 456
                )
            }
        )

        await viewModel.startRecording()
        XCTAssertEqual(viewModel.sessionState, .recording)

        let task = Task {
            await viewModel.stopRecordingAndTranscribe(
                configURL: URL(fileURLWithPath: "/tmp/config.json"),
                mode: .auto
            )
        }

        await Task.yield()
        XCTAssertEqual(viewModel.sessionState, .processing)

        await gate.release()
        await task.value

        XCTAssertEqual(viewModel.sessionState, .success("done"))
    }

    @MainActor
    func test_stopRecordingKeepsTranscriptWhenDeliveryFails() async throws {
        enum StubError: Error {
            case pasteFailed
        }

        let viewModel = TranscriptionDebugViewModel(
            startRecording: {},
            stopRecording: {
                AudioRecordingResult(audioURL: URL(fileURLWithPath: "/tmp/captured.wav"), byteCount: 4_096)
            },
            transcribe: { _, _, _ async throws in
                SpeechTranscriptionResult(
                    engine: .funasr,
                    modelIdentifier: "sensevoice-small",
                    transcript: "still visible",
                    latencyMs: 456
                )
            },
            deliverTranscript: { _ in
                throw StubError.pasteFailed
            }
        )

        await viewModel.startRecording()
        await viewModel.stopRecordingAndTranscribe(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            mode: .auto
        )

        XCTAssertFalse(viewModel.isRecording)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.recordingStatusText, "Last recording ready")
        XCTAssertEqual(viewModel.transcript, "still visible")
        XCTAssertEqual(viewModel.latencyText, "456 ms")
        XCTAssertEqual(viewModel.errorText, "pasteFailed")
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
        XCTAssertEqual(viewModel.sessionState, .error("Microphone permission denied"))
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
        let outputProbe = TranscriptOutputProbe()
        let viewModel = TranscriptionDebugViewModel(
            transcribe: { _, _, _ async throws in result },
            deliverTranscript: { transcript in
                await outputProbe.record(transcript)
            }
        )

        await viewModel.runSample(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            audioURL: URL(fileURLWithPath: "/tmp/sample.wav"),
            mode: .auto
        )

        XCTAssertEqual(viewModel.transcript, "hello world")
        XCTAssertEqual(viewModel.latencyText, "210 ms")
        XCTAssertNil(viewModel.errorText)
        let delivered = await outputProbe.transcripts()
        XCTAssertTrue(delivered.isEmpty)
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

private actor TranscriptOutputProbe {
    private var storedTranscripts: [String] = []

    func record(_ transcript: String) {
        storedTranscripts.append(transcript)
    }

    func transcripts() -> [String] {
        storedTranscripts
    }
}

private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    func wait() async {
        if isReleased {
            isReleased = false
            return
        }

        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        if let continuation {
            continuation.resume()
            self.continuation = nil
        } else {
            isReleased = true
        }
    }
}
