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
    func test_hotkeyReleaseUsesSelectedMode() async throws {
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
        XCTAssertEqual(invocation?.mode, .vi)
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
