import Foundation

public enum FunASRRuntimeProfile: String, Codable, Equatable, Sendable {
    case llamaCPP = "llamaCpp"
    case crispASRFunASR = "crispasrFunASR"
}

public struct EnginePathConfig: Codable, Equatable, Sendable {
    public let displayName: String
    public let binaryPath: String
    public let modelPath: String
    public let defaultMode: SpeechLanguageMode
    public let supportedModes: [SpeechLanguageMode]
    public let auxiliaryModelPaths: [String: String]
    public let runtimeProfile: FunASRRuntimeProfile

    public init(
        displayName: String = "FunASR",
        binaryPath: String,
        modelPath: String,
        defaultMode: SpeechLanguageMode,
        supportedModes: [SpeechLanguageMode] = [.auto],
        auxiliaryModelPaths: [String: String] = [:],
        runtimeProfile: FunASRRuntimeProfile = .llamaCPP
    ) {
        self.displayName = displayName
        self.binaryPath = binaryPath
        self.modelPath = modelPath
        self.defaultMode = defaultMode
        self.supportedModes = supportedModes
        self.auxiliaryModelPaths = auxiliaryModelPaths
        self.runtimeProfile = runtimeProfile
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            displayName: try container.decodeIfPresent(String.self, forKey: .displayName) ?? "FunASR",
            binaryPath: try container.decode(String.self, forKey: .binaryPath),
            modelPath: try container.decode(String.self, forKey: .modelPath),
            defaultMode: try container.decode(SpeechLanguageMode.self, forKey: .defaultMode),
            supportedModes: try container.decodeIfPresent([SpeechLanguageMode].self, forKey: .supportedModes) ?? [.auto],
            auxiliaryModelPaths: try container.decodeIfPresent([String: String].self, forKey: .auxiliaryModelPaths) ?? [:],
            runtimeProfile: try container.decodeIfPresent(FunASRRuntimeProfile.self, forKey: .runtimeProfile) ?? .llamaCPP
        )
    }

    private enum CodingKeys: String, CodingKey {
        case displayName
        case binaryPath
        case modelPath
        case defaultMode
        case supportedModes
        case auxiliaryModelPaths
        case runtimeProfile
    }
}

public struct EngineInstallConfig: Codable, Equatable, Sendable {
    public let engineKind: SpeechEngineKind
    public let displayName: String
    public let binaryPath: String
    public let modelPath: String
    public let defaultMode: SpeechLanguageMode
    public let supportedModes: [SpeechLanguageMode]
    public let auxiliaryModelPaths: [String: String]
    public let runtimeProfile: FunASRRuntimeProfile

    public init(
        engineKind: SpeechEngineKind,
        displayName: String = "FunASR",
        binaryPath: String,
        modelPath: String,
        defaultMode: SpeechLanguageMode,
        supportedModes: [SpeechLanguageMode] = [.auto],
        auxiliaryModelPaths: [String: String] = [:],
        runtimeProfile: FunASRRuntimeProfile = .llamaCPP
    ) {
        self.engineKind = engineKind
        self.displayName = displayName
        self.binaryPath = binaryPath
        self.modelPath = modelPath
        self.defaultMode = defaultMode
        self.supportedModes = supportedModes
        self.auxiliaryModelPaths = auxiliaryModelPaths
        self.runtimeProfile = runtimeProfile
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            engineKind: try container.decode(SpeechEngineKind.self, forKey: .engineKind),
            displayName: try container.decodeIfPresent(String.self, forKey: .displayName) ?? "FunASR",
            binaryPath: try container.decode(String.self, forKey: .binaryPath),
            modelPath: try container.decode(String.self, forKey: .modelPath),
            defaultMode: try container.decode(SpeechLanguageMode.self, forKey: .defaultMode),
            supportedModes: try container.decodeIfPresent([SpeechLanguageMode].self, forKey: .supportedModes) ?? [.auto],
            auxiliaryModelPaths: try container.decodeIfPresent([String: String].self, forKey: .auxiliaryModelPaths) ?? [:],
            runtimeProfile: try container.decodeIfPresent(FunASRRuntimeProfile.self, forKey: .runtimeProfile) ?? .llamaCPP
        )
    }

    public var pathConfig: EnginePathConfig {
        EnginePathConfig(
            displayName: displayName,
            binaryPath: binaryPath,
            modelPath: modelPath,
            defaultMode: defaultMode,
            supportedModes: supportedModes,
            auxiliaryModelPaths: auxiliaryModelPaths,
            runtimeProfile: runtimeProfile
        )
    }

    private enum CodingKeys: String, CodingKey {
        case engineKind
        case displayName
        case binaryPath
        case modelPath
        case defaultMode
        case supportedModes
        case auxiliaryModelPaths
        case runtimeProfile
    }
}

public struct SpeechEngineSettings: Codable, Equatable, Sendable {
    public let selectedEngineID: String
    public let selectedMode: SpeechLanguageMode
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

    public var selectedPathConfig: EnginePathConfig {
        selectedEngineConfig.pathConfig
    }

    public var availableEngines: [(id: String, config: EngineInstallConfig)] {
        engines.keys.sorted().map { ($0, engines[$0]!) }
    }

    public init(
        selectedEngineID: String,
        selectedMode: SpeechLanguageMode = .auto,
        engines: [String: EngineInstallConfig]
    ) {
        self.selectedEngineID = selectedEngineID
        self.selectedMode = selectedMode
        self.engines = engines
    }

    public init(engine: SpeechEngineKind, funasr: EnginePathConfig) {
        self.selectedEngineID = engine.rawValue
        self.selectedMode = funasr.defaultMode
        self.engines = [
            engine.rawValue: EngineInstallConfig(
                engineKind: engine,
                displayName: funasr.displayName,
                binaryPath: funasr.binaryPath,
                modelPath: funasr.modelPath,
                defaultMode: funasr.defaultMode,
                supportedModes: funasr.supportedModes,
                auxiliaryModelPaths: funasr.auxiliaryModelPaths,
                runtimeProfile: funasr.runtimeProfile
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
            self.init(
                selectedEngineID: selectedEngineID,
                selectedMode: try container.decodeIfPresent(SpeechLanguageMode.self, forKey: .selectedMode)
                    ?? engines[selectedEngineID]?.defaultMode
                    ?? .auto,
                engines: engines
            )
            return
        }

        let engine = try container.decode(SpeechEngineKind.self, forKey: .engine)
        let funasr = try container.decode(EnginePathConfig.self, forKey: .funasr)
        self.init(engine: engine, funasr: funasr)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedEngineID, forKey: .selectedEngine)
        try container.encode(selectedMode, forKey: .selectedMode)
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
        guard selected.supportedModes.contains(selectedMode) else {
            throw SpeechEngineError.invalidConfiguration(
                "selectedMode '\(selectedMode.rawValue)' must be supported by selectedEngine '\(selectedEngineID)'"
            )
        }
        for (key, path) in selected.auxiliaryModelPaths {
            guard !path.isEmpty else {
                throw SpeechEngineError.invalidConfiguration("auxiliary model path '\(key)' must be non-empty")
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case selectedEngine
        case selectedMode
        case engines
        case engine
        case funasr
    }
}
