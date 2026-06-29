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

public struct EngineInstallConfig: Codable, Equatable, Sendable {
    public let engineKind: SpeechEngineKind
    public let binaryPath: String
    public let modelPath: String
    public let defaultMode: SpeechLanguageMode

    public init(
        engineKind: SpeechEngineKind,
        binaryPath: String,
        modelPath: String,
        defaultMode: SpeechLanguageMode
    ) {
        self.engineKind = engineKind
        self.binaryPath = binaryPath
        self.modelPath = modelPath
        self.defaultMode = defaultMode
    }

    public var pathConfig: EnginePathConfig {
        EnginePathConfig(
            binaryPath: binaryPath,
            modelPath: modelPath,
            defaultMode: defaultMode
        )
    }
}

public struct SpeechEngineSettings: Codable, Equatable, Sendable {
    public let selectedEngineID: String
    public let engines: [String: EngineInstallConfig]

    public var selectedEngineConfig: EngineInstallConfig {
        engines[selectedEngineID]!
    }

    public var engine: SpeechEngineKind {
        selectedEngineConfig.engineKind
    }

    public var funasr: EnginePathConfig {
        selectedEngineConfig.pathConfig
    }

    public init(selectedEngineID: String, engines: [String: EngineInstallConfig]) {
        self.selectedEngineID = selectedEngineID
        self.engines = engines
    }

    public init(engine: SpeechEngineKind, funasr: EnginePathConfig) {
        self.selectedEngineID = engine.rawValue
        self.engines = [
            engine.rawValue: EngineInstallConfig(
                engineKind: engine,
                binaryPath: funasr.binaryPath,
                modelPath: funasr.modelPath,
                defaultMode: funasr.defaultMode
            ),
        ]
    }

    public static func load(from url: URL) throws -> SpeechEngineSettings {
        let data = try Data(contentsOf: url)
        let settings = try JSONDecoder().decode(Self.self, from: data)
        try settings.validate()
        return settings
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let selectedEngineID = try container.decodeIfPresent(String.self, forKey: .selectedEngine),
           let engines = try container.decodeIfPresent([String: EngineInstallConfig].self, forKey: .engines) {
            self.init(selectedEngineID: selectedEngineID, engines: engines)
            return
        }

        let engine = try container.decode(SpeechEngineKind.self, forKey: .engine)
        let funasr = try container.decode(EnginePathConfig.self, forKey: .funasr)
        self.init(engine: engine, funasr: funasr)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedEngineID, forKey: .selectedEngine)
        try container.encode(engines, forKey: .engines)
    }

    private func validate() throws {
        guard let selected = engines[selectedEngineID] else {
            throw SpeechEngineError.invalidConfiguration(
                "selectedEngine '\(selectedEngineID)' must exist in engines"
            )
        }
        guard selected.engineKind == .funasr else {
            throw SpeechEngineError.invalidConfiguration("only funasr is supported in current local runtime")
        }
        guard !selected.binaryPath.isEmpty else {
            throw SpeechEngineError.invalidConfiguration("funasr binaryPath must be non-empty")
        }
        guard !selected.modelPath.isEmpty else {
            throw SpeechEngineError.invalidConfiguration("funasr modelPath must be non-empty")
        }
        guard selected.defaultMode == .auto else {
            throw SpeechEngineError.invalidConfiguration(
                "funasr runtime only supports defaultMode 'auto' in current local runtime"
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case selectedEngine
        case engines
        case engine
        case funasr
    }
}
