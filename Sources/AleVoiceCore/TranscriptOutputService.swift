import Foundation

public enum TranscriptOutputError: Error, Equatable, LocalizedError, Sendable {
    case emptyTranscript

    public var errorDescription: String? {
        switch self {
        case .emptyTranscript:
            return "Transcript is empty"
        }
    }
}

public struct TranscriptOutputService: Sendable {
    private let deliverClosure: @Sendable (String) async throws -> Void

    public init(deliver: @escaping @Sendable (String) async throws -> Void) {
        self.deliverClosure = deliver
    }

    public func deliver(_ transcript: String) async throws {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            throw TranscriptOutputError.emptyTranscript
        }

        try await deliverClosure(transcript)
    }
}
