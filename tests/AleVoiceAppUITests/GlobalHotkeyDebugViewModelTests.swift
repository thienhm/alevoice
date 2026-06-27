import XCTest
@testable import AleVoiceAppUI
import AleVoiceCore

final class GlobalHotkeyDebugViewModelTests: XCTestCase {
    @MainActor
    func test_refreshInputMonitoringStatusShowsAuthorizedState() async {
        let viewModel = TranscriptionDebugViewModel(
            inputMonitoringPermissionStatus: { .authorized },
            transcribe: { _, _, _ in fatalError() }
        )

        await viewModel.refreshInputMonitoringStatus()

        XCTAssertEqual(viewModel.inputMonitoringStatusText, "Input Monitoring: authorized")
    }

    @MainActor
    func test_requestInputMonitoringPermissionUpdatesStatusText() async {
        let viewModel = TranscriptionDebugViewModel(
            requestInputMonitoringPermission: { .denied },
            transcribe: { _, _, _ in fatalError() }
        )

        await viewModel.requestInputMonitoringPermission()

        XCTAssertEqual(viewModel.inputMonitoringStatusText, "Input Monitoring: denied")
    }

    @MainActor
    func test_refreshAccessibilityStatusShowsAuthorizedState() async {
        let viewModel = TranscriptionDebugViewModel(
            accessibilityPermissionStatus: { .authorized },
            transcribe: { _, _, _ in fatalError() }
        )

        await viewModel.refreshAccessibilityStatus()

        XCTAssertEqual(viewModel.accessibilityStatusText, "Accessibility: authorized")
    }

    @MainActor
    func test_requestAccessibilityPermissionUpdatesStatusText() async {
        let viewModel = TranscriptionDebugViewModel(
            requestAccessibilityPermission: { .denied },
            transcribe: { _, _, _ in fatalError() }
        )

        await viewModel.requestAccessibilityPermission()

        XCTAssertEqual(viewModel.accessibilityStatusText, "Accessibility: denied")
    }

    @MainActor
    func test_captureShortcutSavesDisplayTextAndClearsError() async {
        let shortcut = try! DictationShortcut(modifiers: [.control], primaryKey: .space)
        let viewModel = TranscriptionDebugViewModel(
            beginShortcutCapture: { .success(shortcut) },
            saveShortcut: { saved in
                XCTAssertEqual(saved, shortcut)
            },
            transcribe: { _, _, _ in fatalError() }
        )

        await viewModel.captureShortcut()

        XCTAssertEqual(viewModel.shortcutDisplayText, "Dictation shortcut: Control+Space")
        XCTAssertNil(viewModel.errorText)
        XCTAssertFalse(viewModel.isCapturingShortcut)
    }

    @MainActor
    func test_captureShortcutRejectsMissingModifier() async {
        let viewModel = TranscriptionDebugViewModel(
            beginShortcutCapture: { .failure(.missingModifier) },
            transcribe: { _, _, _ in fatalError() }
        )

        await viewModel.captureShortcut()

        XCTAssertEqual(viewModel.errorText, "Shortcut must include at least one modifier")
        XCTAssertEqual(viewModel.shortcutDisplayText, "Dictation shortcut: not set")
    }

    @MainActor
    func test_hotkeyReleaseAlwaysUsesAutoModeForMvp() async throws {
        let probe = TranscriptionProbe()
        let shortcut = try! DictationShortcut(modifiers: [.control], primaryKey: .space)
        let viewModel = TranscriptionDebugViewModel(
            loadShortcut: { shortcut },
            startRecording: {},
            stopRecording: {
                AudioRecordingResult(audioURL: URL(fileURLWithPath: "/tmp/captured.wav"), byteCount: 123)
            },
            transcribe: { configURL, audioURL, mode in
                await probe.record(configURL: configURL, audioURL: audioURL, mode: mode)
                return SpeechTranscriptionResult(
                    engine: .funasr,
                    modelIdentifier: "sensevoice-small",
                    transcript: "hello",
                    latencyMs: 99
                )
            }
        )
        viewModel.selectedMode = .vi
        await viewModel.startRecording()
        await viewModel.handleGlobalShortcutRelease(configURL: URL(fileURLWithPath: "/tmp/config.json"))

        let invocation = await probe.invocation()
        XCTAssertEqual(invocation?.mode, .auto)
    }

    @MainActor
    func test_hotkeyReleaseDuringActivationStopsAfterStartCompletes() async {
        let gate = AsyncGate()
        let recordingProbe = RecordingProbe()
        let transcriptionProbe = TranscriptionProbe()
        let outputProbe = TranscriptOutputProbe()
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {
                await gate.wait()
                await recordingProbe.markStart()
            },
            stopRecording: {
                await recordingProbe.markStop()
                return AudioRecordingResult(audioURL: URL(fileURLWithPath: "/tmp/captured.wav"), byteCount: 123)
            },
            transcribe: { configURL, audioURL, mode in
                await transcriptionProbe.record(configURL: configURL, audioURL: audioURL, mode: mode)
                return SpeechTranscriptionResult(
                    engine: .funasr,
                    modelIdentifier: "sensevoice-small",
                    transcript: "hello",
                    latencyMs: 99
                )
            },
            deliverTranscript: { transcript in
                await outputProbe.record(transcript)
            }
        )
        viewModel.selectedMode = .vi

        let activationTask = Task {
            await viewModel.handleGlobalShortcutActivation()
        }

        await Task.yield()
        XCTAssertTrue(viewModel.isRunning)
        XCTAssertFalse(viewModel.isRecording)

        await viewModel.handleGlobalShortcutRelease(configURL: URL(fileURLWithPath: "/tmp/config.json"))

        let didStopBeforeStartFinished = await recordingProbe.didStop()
        XCTAssertFalse(didStopBeforeStartFinished)

        await gate.release()
        await activationTask.value

        let invocation = await transcriptionProbe.invocation()
        XCTAssertEqual(invocation?.configURL, URL(fileURLWithPath: "/tmp/config.json"))
        XCTAssertEqual(invocation?.audioURL, URL(fileURLWithPath: "/tmp/captured.wav"))
        XCTAssertEqual(invocation?.mode, .auto)
        let didStop = await recordingProbe.didStop()
        XCTAssertTrue(didStop)
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(viewModel.transcript, "hello")
        let delivered = await outputProbe.transcripts()
        XCTAssertEqual(delivered, ["hello"])
    }

    @MainActor
    func test_hotkeyReleaseDuringSampleRunDoesNotStopNextManualRecording() async {
        let gate = AsyncGate()
        let recordingProbe = RecordingProbe()
        let transcriptionProbe = TranscriptionProbe()
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {
                await recordingProbe.markStart()
            },
            stopRecording: {
                await recordingProbe.markStop()
                return AudioRecordingResult(audioURL: URL(fileURLWithPath: "/tmp/captured.wav"), byteCount: 123)
            },
            transcribe: { configURL, audioURL, mode in
                await transcriptionProbe.record(configURL: configURL, audioURL: audioURL, mode: mode)
                if audioURL.lastPathComponent == "sample.wav" {
                    await gate.wait()
                    return SpeechTranscriptionResult(
                        engine: .funasr,
                        modelIdentifier: "sensevoice-small",
                        transcript: "sample",
                        latencyMs: 10
                    )
                }

                return SpeechTranscriptionResult(
                    engine: .funasr,
                    modelIdentifier: "sensevoice-small",
                    transcript: "captured",
                    latencyMs: 99
                )
            }
        )

        let sampleTask = Task {
            await viewModel.runSample(
                configURL: URL(fileURLWithPath: "/tmp/sample-config.json"),
                audioURL: URL(fileURLWithPath: "/tmp/sample.wav"),
                mode: .auto
            )
        }

        await Task.yield()
        XCTAssertTrue(viewModel.isRunning)
        XCTAssertFalse(viewModel.isRecording)

        await viewModel.handleGlobalShortcutRelease(configURL: URL(fileURLWithPath: "/tmp/stale-config.json"))

        await gate.release()
        await sampleTask.value

        await viewModel.startRecording()

        let didStop = await recordingProbe.didStop()
        let invocations = await transcriptionProbe.invocations()
        XCTAssertFalse(didStop)
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertEqual(invocations.map(\.audioURL), [URL(fileURLWithPath: "/tmp/sample.wav")])
        XCTAssertEqual(viewModel.transcript, "sample")
    }

    @MainActor
    func test_hotkeyReleaseAfterFailedActivationPreservesStartErrorAndSkipsTranscription() async {
        let probe = TranscriptionProbe()
        let viewModel = TranscriptionDebugViewModel(
            startRecording: {
                throw AudioRecorderError.permissionDenied
            },
            transcribe: { configURL, audioURL, mode in
                await probe.record(configURL: configURL, audioURL: audioURL, mode: mode)
                return SpeechTranscriptionResult(
                    engine: .funasr,
                    modelIdentifier: "sensevoice-small",
                    transcript: "unexpected",
                    latencyMs: 1
                )
            }
        )

        await viewModel.handleGlobalShortcutActivation()
        await viewModel.handleGlobalShortcutRelease(configURL: URL(fileURLWithPath: "/tmp/config.json"))

        XCTAssertEqual(viewModel.errorText, "Microphone permission denied")
        XCTAssertFalse(viewModel.isRecording)
        let invocation = await probe.invocation()
        XCTAssertNil(invocation)
    }

    @MainActor
    func test_manualActionsAreBlockedDuringShortcutCapture() async {
        let gate = AsyncGate()
        let transcriptionProbe = TranscriptionProbe()
        let recordingProbe = RecordingProbe()
        let viewModel = TranscriptionDebugViewModel(
            beginShortcutCapture: {
                await gate.wait()
                return .failure(.missingModifier)
            },
            startRecording: {
                await recordingProbe.markStart()
            },
            stopRecording: {
                await recordingProbe.markStop()
                return AudioRecordingResult(audioURL: URL(fileURLWithPath: "/tmp/captured.wav"), byteCount: 42)
            },
            transcribe: { configURL, audioURL, mode in
                await transcriptionProbe.record(configURL: configURL, audioURL: audioURL, mode: mode)
                return SpeechTranscriptionResult(
                    engine: .funasr,
                    modelIdentifier: "sensevoice-small",
                    transcript: "unexpected",
                    latencyMs: 1
                )
            }
        )

        let captureTask = Task {
            await viewModel.captureShortcut()
        }

        await Task.yield()
        XCTAssertTrue(viewModel.isCapturingShortcut)

        await viewModel.startRecording()
        await viewModel.stopRecordingAndTranscribe(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            mode: .auto
        )
        await viewModel.runSample(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            audioURL: URL(fileURLWithPath: "/tmp/sample.wav"),
            mode: .auto
        )

        let didStart = await recordingProbe.didStart()
        let didStop = await recordingProbe.didStop()
        let invocation = await transcriptionProbe.invocation()
        XCTAssertFalse(didStart)
        XCTAssertFalse(didStop)
        XCTAssertNil(invocation)
        XCTAssertEqual(viewModel.recordingStatusText, "Recorder idle")

        await gate.release()
        await captureTask.value
    }
}

private actor TranscriptionProbe {
    struct Invocation: Equatable {
        let configURL: URL
        let audioURL: URL
        let mode: SpeechLanguageMode
    }

    private var storedInvocation: Invocation?
    private var storedInvocations: [Invocation] = []

    func record(configURL: URL, audioURL: URL, mode: SpeechLanguageMode) {
        let invocation = Invocation(configURL: configURL, audioURL: audioURL, mode: mode)
        storedInvocation = invocation
        storedInvocations.append(invocation)
    }

    func invocation() -> Invocation? {
        storedInvocation
    }

    func invocations() -> [Invocation] {
        storedInvocations
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
