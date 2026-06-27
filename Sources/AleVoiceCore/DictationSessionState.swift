import Foundation

public enum DictationSessionState: Equatable {
    case idle
    case recording
    case processing
    case success(String)
    case error(String)
}
