import XCTest
@testable import AleVoiceApp
import AleVoiceCore

final class MenuBarMenuViewTests: XCTestCase {
    @MainActor
    func test_menuStatusLinesShowEnabledStateAndShortcutOnly() {
        let lines = menuStatusLines(
            statusText: "Idle",
            isDictationEnabled: true,
            shortcutText: "Dictation shortcut: Control+Space"
        )

        XCTAssertEqual(lines, [
            "Idle",
            "Enabled",
            "Dictation shortcut: Control+Space"
        ])
    }

    @MainActor
    func test_menuStatusLinesDoNotIncludePermissionRows() {
        let lines = menuStatusLines(
            statusText: "Idle",
            isDictationEnabled: false,
            shortcutText: "Dictation shortcut: not set"
        )

        XCTAssertFalse(lines.contains { $0.contains("Microphone permission") })
        XCTAssertFalse(lines.contains { $0.contains("Accessibility") })
        XCTAssertFalse(lines.contains { $0.contains("Input Monitoring") })
        XCTAssertEqual(lines[1], "Disabled")
    }

    @MainActor
    func test_lastErrorMessageReturnsErrorPayload() {
        XCTAssertEqual(lastErrorMessage(from: .error("paste failed")), "paste failed")
    }

    @MainActor
    func test_lastErrorMessageReturnsNilForNonErrorStates() {
        XCTAssertNil(lastErrorMessage(from: .idle))
        XCTAssertNil(lastErrorMessage(from: .recording))
        XCTAssertNil(lastErrorMessage(from: .processing))
        XCTAssertNil(lastErrorMessage(from: .success("done")))
    }
}
