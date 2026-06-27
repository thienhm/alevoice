import XCTest
@testable import AleVoiceApp
import AleVoiceCore

final class OverlayWindowControllerTests: XCTestCase {
    @MainActor
    func test_renderNeverShowsOverlayForAnyState() {
        let states: [DictationSessionState] = [
            .idle,
            .recording,
            .processing,
            .success("done"),
            .error("failed")
        ]
        var showCount = 0
        var hideCount = 0
        let controller = OverlayWindowController(
            showWindow: { showCount += 1 },
            hideWindow: { hideCount += 1 }
        )

        for state in states {
            controller.render(state: state)
        }

        XCTAssertEqual(showCount, 0)
        XCTAssertEqual(hideCount, states.count)
    }
}
