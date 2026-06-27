import XCTest
@testable import AleVoiceApp
import AleVoiceCore

final class MenuBarControllerTests: XCTestCase {
    @MainActor
    func test_recordingStateUsesRedRecordingIndicator() {
        let model = MenuBarShellModel()
        let controller = MenuBarController(
            statusItem: nil,
            updateShell: { presentation in
                model.title = presentation.title
                model.isRecordingIndicatorVisible = presentation.isRecordingIndicatorVisible
            }
        )

        controller.render(
            state: .recording,
            microphoneText: "Microphone permission: authorized",
            accessibilityText: "Accessibility: authorized",
            inputMonitoringText: "Input Monitoring: authorized",
            shortcutText: "Dictation shortcut: Control+Space"
        )

        XCTAssertEqual(model.title, "AleVoice • Recording")
        XCTAssertTrue(model.isRecordingIndicatorVisible)
    }

    @MainActor
    func test_nonRecordingStatesUseDefaultIndicator() {
        let states: [DictationSessionState] = [
            .idle,
            .processing,
            .success("done"),
            .error("failed")
        ]

        for state in states {
            let model = MenuBarShellModel()
            let controller = MenuBarController(
                statusItem: nil,
                updateShell: { presentation in
                    model.title = presentation.title
                    model.isRecordingIndicatorVisible = presentation.isRecordingIndicatorVisible
                }
            )

            controller.render(
                state: state,
                microphoneText: "Microphone permission: authorized",
                accessibilityText: "Accessibility: authorized",
                inputMonitoringText: "Input Monitoring: authorized",
                shortcutText: "Dictation shortcut: Control+Space"
            )

            XCTAssertFalse(model.isRecordingIndicatorVisible, "Expected default icon for \(state)")
        }
    }
}
