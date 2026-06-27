import XCTest
@testable import AleVoiceApp
import AleVoiceCore

final class MenuBarControllerTests: XCTestCase {
    @MainActor
    func test_menuBarSummaryUsesRecordingState() {
        var title = ""
        let controller = MenuBarController(
            setTitle: { title = $0 }
        )

        controller.render(
            state: .recording,
            microphoneText: "Microphone permission: authorized",
            accessibilityText: "Accessibility: authorized",
            inputMonitoringText: "Input Monitoring: authorized",
            shortcutText: "Dictation shortcut: Control+Space"
        )

        XCTAssertEqual(title, "AleVoice • Recording")
    }

    @MainActor
    func test_menuBarSummaryUsesProcessingState() {
        var title = ""
        let controller = MenuBarController(
            setTitle: { title = $0 }
        )

        controller.render(
            state: .processing,
            microphoneText: "Microphone permission: authorized",
            accessibilityText: "Accessibility: authorized",
            inputMonitoringText: "Input Monitoring: authorized",
            shortcutText: "Dictation shortcut: Control+Space"
        )

        XCTAssertEqual(title, "AleVoice • Processing")
    }
}
