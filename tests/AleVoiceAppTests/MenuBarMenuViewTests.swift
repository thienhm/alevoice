import XCTest
@testable import AleVoiceApp
import AleVoiceCore

final class MenuBarMenuViewTests: XCTestCase {
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
