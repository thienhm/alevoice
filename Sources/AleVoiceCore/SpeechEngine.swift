import Foundation

public enum SpeechEngineKind: String, Codable, Equatable {
    case funasr
}

public enum SpeechLanguageMode: String, Codable, Equatable {
    case auto
    case en
    case vi
}

public struct SpeechTranscriptionRequest: Equatable {
    public let audioURL: URL
    public let mode: SpeechLanguageMode

    public init(audioURL: URL, mode: SpeechLanguageMode) {
        self.audioURL = audioURL
        self.mode = mode
    }
}

public struct SpeechTranscriptionResult: Equatable {
    public let engine: SpeechEngineKind
    public let modelIdentifier: String
    public let transcript: String
    public let latencyMs: Int

    public init(
        engine: SpeechEngineKind,
        modelIdentifier: String,
        transcript: String,
        latencyMs: Int
    ) {
        self.engine = engine
        self.modelIdentifier = modelIdentifier
        self.transcript = transcript
        self.latencyMs = latencyMs
    }
}

public enum SpeechEngineError: Error, Equatable {
    case invalidConfiguration(String)
    case processFailure(String)
    case emptyTranscript
}

public protocol SpeechEngine {
    func transcribe(_ request: SpeechTranscriptionRequest) throws -> SpeechTranscriptionResult
}
