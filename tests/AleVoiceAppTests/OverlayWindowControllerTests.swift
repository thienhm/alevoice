import XCTest
@testable import AleVoiceApp
import AleVoiceCore

final class OverlayWindowControllerTests: XCTestCase {
    @MainActor
    func test_renderShowsRecordingOverlay() {
        var didShow = false
        let controller = OverlayWindowController(
            showWindow: { didShow = true },
            hideWindow: { XCTFail("hide should not be called") }
        )

        controller.render(state: .recording)

        XCTAssertTrue(didShow)
    }

    @MainActor
    func test_renderHidesOverlayWhenIdle() {
        var didHide = false
        let controller = OverlayWindowController(
            showWindow: { XCTFail("show should not be called") },
            hideWindow: { didHide = true }
        )

        controller.render(state: .idle)

        XCTAssertTrue(didHide)
    }
}
