import AleVoiceCore
import XCTest
@testable import AleVoiceApp

final class QuartzInputMonitoringPermissionTests: XCTestCase {
    func test_statusReportsUnknownWhenPriorRequestStateIsStale() {
        let userDefaults = UserDefaults(suiteName: "QuartzInputMonitoringPermissionTests.stale")!
        userDefaults.removePersistentDomain(forName: "QuartzInputMonitoringPermissionTests.stale")
        userDefaults.set(true, forKey: "requested")

        let permission = QuartzInputMonitoringPermission(
            userDefaults: userDefaults,
            requestAttemptKey: "requested",
            preflightListenEventAccess: { false },
            requestListenEventAccess: { false }
        )

        XCTAssertEqual(permission.status(), InputMonitoringPermissionStatus.unknown)
    }
}
