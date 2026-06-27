import AleVoiceCore
import CoreGraphics
import Foundation

struct QuartzInputMonitoringPermission: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let requestAttemptKey: String

    init(
        userDefaults: UserDefaults = .standard,
        requestAttemptKey: String = "quartzInputMonitoringPermission.requested"
    ) {
        self.userDefaults = userDefaults
        self.requestAttemptKey = requestAttemptKey
    }

    func status() -> InputMonitoringPermissionStatus {
        if CGPreflightListenEventAccess() {
            return .authorized
        }

        if userDefaults.bool(forKey: requestAttemptKey) {
            return .denied
        }

        return .notDetermined
    }

    func requestAccess() -> InputMonitoringPermissionStatus {
        userDefaults.set(true, forKey: requestAttemptKey)

        if CGRequestListenEventAccess() {
            return .authorized
        }

        return CGPreflightListenEventAccess() ? .authorized : .denied
    }
}
