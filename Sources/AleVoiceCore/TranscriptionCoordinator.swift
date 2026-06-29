import Foundation

public struct TranscriptionCoordinator {
    private let settings: SpeechEngineSettings
    private let engineFactory: (EnginePathConfig) -> SpeechEngine

    public init(
        settings: SpeechEngineSettings,
        engineFactory: @escaping (EnginePathConfig) -> SpeechEngine = { FunASRSpeechEngine(config: $0) }
    ) {
        self.settings = settings
        self.engineFactory = engineFactory
    }

    public func transcribe(
        audioURL: URL,
        overrideMode: SpeechLanguageMode?
    ) throws -> SpeechTranscriptionResult {
        let engine: SpeechEngine
        switch settings.engine {
        case .funasr:
            engine = engineFactory(settings.selectedPathConfig)
        }
        let request = SpeechTranscriptionRequest(
            audioURL: audioURL,
            mode: overrideMode ?? settings.selectedMode
        )
        return try engine.transcribe(request)
    }
}
