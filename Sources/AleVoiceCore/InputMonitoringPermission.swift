import Foundation

public enum InputMonitoringPermissionStatus: Equatable, Sendable {
    case authorized
    case denied
    case notDetermined
    case unknown
}
