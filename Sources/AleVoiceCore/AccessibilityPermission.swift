import Foundation

public enum AccessibilityPermissionStatus: Equatable, Sendable {
    case authorized
    case denied
    case notDetermined
    case unknown
}
