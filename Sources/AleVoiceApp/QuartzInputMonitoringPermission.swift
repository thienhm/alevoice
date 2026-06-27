import AleVoiceCore
import CoreGraphics
import Foundation

struct QuartzInputMonitoringPermission {
    func status() -> InputMonitoringPermissionStatus {
        if CGPreflightListenEventAccess() {
            return .authorized
        }

        return .notDetermined
    }

    func requestAccess() -> InputMonitoringPermissionStatus {
        if CGRequestListenEventAccess() {
            return .authorized
        }

        return status() == .authorized ? .authorized : .denied
    }
}
