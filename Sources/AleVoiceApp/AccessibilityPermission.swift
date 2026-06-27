import AleVoiceCore
import ApplicationServices
import Foundation

struct AccessibilityPermission: @unchecked Sendable {
    private let checkIsTrusted: @Sendable () -> Bool
    private let requestTrust: @Sendable () -> Bool

    init(
        checkIsTrusted: @escaping @Sendable () -> Bool = {
            AXIsProcessTrusted()
        },
        requestTrust: @escaping @Sendable () -> Bool = {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
    ) {
        self.checkIsTrusted = checkIsTrusted
        self.requestTrust = requestTrust
    }

    func status() -> AccessibilityPermissionStatus {
        if checkIsTrusted() {
            return .authorized
        }

        return .notDetermined
    }

    func requestAccess() -> AccessibilityPermissionStatus {
        if requestTrust() {
            return .authorized
        }

        return checkIsTrusted() ? .authorized : .denied
    }
}
