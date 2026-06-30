import AleVoiceCore
import Foundation

struct InstalledModelRemovalResult: Equatable {
    let removedEngineID: String
    let removedDisplayName: String
    let selectedEngineID: String
    let removedDirectoryURL: URL
}

struct InstalledModelRemover {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func remove(
        engineID: String,
        configURL: URL,
        installRoot: URL
    ) throws -> InstalledModelRemovalResult {
        let settings = try SpeechEngineSettings.load(from: configURL)
        guard settings.engines.count > 1 else {
            throw CLIError(description: "cannot remove the only installed model")
        }
        guard let removed = settings.engines[engineID] else {
            throw CLIError(description: "installed model '\(engineID)' not found")
        }

        var engines = settings.engines
        engines.removeValue(forKey: engineID)

        let selectedEngineID: String
        let selectedMode: SpeechLanguageMode
        if settings.selectedEngineID == engineID || engines[settings.selectedEngineID] == nil {
            selectedEngineID = engines.keys.sorted().first!
            selectedMode = engines[selectedEngineID]!.defaultMode
        } else {
            selectedEngineID = settings.selectedEngineID
            let selectedConfig = engines[selectedEngineID]!
            selectedMode = selectedConfig.supportedModes.contains(settings.selectedMode)
                ? settings.selectedMode
                : selectedConfig.defaultMode
        }

        let removedDirectoryURL = installRoot
            .appendingPathComponent("engines", isDirectory: true)
            .appendingPathComponent(engineID, isDirectory: true)
        if fileManager.fileExists(atPath: removedDirectoryURL.path) {
            try fileManager.removeItem(at: removedDirectoryURL)
        }

        let updatedSettings = SpeechEngineSettings(
            selectedEngineID: selectedEngineID,
            selectedMode: selectedMode,
            engines: engines
        )
        try updatedSettings.save(to: configURL)

        return InstalledModelRemovalResult(
            removedEngineID: engineID,
            removedDisplayName: removed.displayName,
            selectedEngineID: selectedEngineID,
            removedDirectoryURL: removedDirectoryURL
        )
    }
}
