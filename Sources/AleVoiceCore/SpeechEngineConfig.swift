import Foundation

public struct EnginePathConfig: Codable, Equatable, Sendable {
    public let binaryPath: String
    public let modelPath: String
    public let defaultMode: SpeechLanguageMode

    public init(binaryPath: String, modelPath: String, defaultMode: SpeechLanguageMode) {
        self.binaryPath = binaryPath
        self.modelPath = modelPath
        self.defaultMode = defaultMode
    }
}

public struct SpeechEngineSettings: Codable, Equatable, Sendable {
    public let engine: SpeechEngineKind
    public let funasr: EnginePathConfig

    public init(engine: SpeechEngineKind, funasr: EnginePathConfig) {
        self.engine = engine
        self.funasr = funasr
    }

    public static func load(from url: URL) throws -> SpeechEngineSettings {
        let data = try Data(contentsOf: url)
        let settings = try JSONDecoder().decode(Self.self, from: data)
        try settings.validate()
        return settings
    }

    private func validate() throws {
        guard !funasr.binaryPath.isEmpty else {
            throw SpeechEngineError.invalidConfiguration("funasr binaryPath must be non-empty")
        }
        guard !funasr.modelPath.isEmpty else {
            throw SpeechEngineError.invalidConfiguration("funasr modelPath must be non-empty")
        }
        guard funasr.defaultMode == .auto else {
            throw SpeechEngineError.invalidConfiguration(
                "funasr runtime only supports defaultMode 'auto' in current local runtime"
            )
        }
    }
}
