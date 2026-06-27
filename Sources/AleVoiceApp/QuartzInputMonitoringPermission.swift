import AleVoiceCore
import CoreGraphics
import Foundation

struct QuartzInputMonitoringPermission: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let requestAttemptKey: String
    private let preflightListenEventAccess: @Sendable () -> Bool
    private let requestListenEventAccess: @Sendable () -> Bool

    init(
        userDefaults: UserDefaults = .standard,
        requestAttemptKey: String = "quartzInputMonitoringPermission.requested",
        preflightListenEventAccess: @escaping @Sendable () -> Bool = {
            CGPreflightListenEventAccess()
        },
        requestListenEventAccess: @escaping @Sendable () -> Bool = {
            CGRequestListenEventAccess()
        }
    ) {
        self.userDefaults = userDefaults
        self.requestAttemptKey = requestAttemptKey
        self.preflightListenEventAccess = preflightListenEventAccess
        self.requestListenEventAccess = requestListenEventAccess
    }

    func status() -> InputMonitoringPermissionStatus {
        if preflightListenEventAccess() {
            userDefaults.set(false, forKey: requestAttemptKey)
            return .authorized
        }

        if userDefaults.bool(forKey: requestAttemptKey) {
            return .unknown
        }

        return .notDetermined
    }

    func requestAccess() -> InputMonitoringPermissionStatus {
        userDefaults.set(true, forKey: requestAttemptKey)

        if requestListenEventAccess() {
            userDefaults.set(false, forKey: requestAttemptKey)
            return .authorized
        }

        if preflightListenEventAccess() {
            userDefaults.set(false, forKey: requestAttemptKey)
            return .authorized
        }

        return .denied
    }
}
