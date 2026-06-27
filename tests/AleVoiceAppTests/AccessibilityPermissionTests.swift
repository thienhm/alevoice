import AleVoiceCore
import XCTest
@testable import AleVoiceApp

final class AccessibilityPermissionTests: XCTestCase {
    func test_requestAccessReportsUnknownWhenPromptDoesNotConfirmTrust() {
        let permission = AccessibilityPermission(
            checkIsTrusted: { false },
            requestTrust: { false }
        )

        XCTAssertEqual(permission.requestAccess(), AccessibilityPermissionStatus.unknown)
    }

    func test_requestAccessReportsAuthorizedWhenAlreadyTrustedAfterPrompt() {
        let permission = AccessibilityPermission(
            checkIsTrusted: { true },
            requestTrust: { false }
        )

        XCTAssertEqual(permission.requestAccess(), AccessibilityPermissionStatus.authorized)
    }
}
