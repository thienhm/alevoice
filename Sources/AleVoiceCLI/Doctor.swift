import AleVoiceCore
import Foundation

struct AleVoiceDoctor {
    let sampleAudioResolver: () -> URL
    let transcribe: (URL, URL, SpeechLanguageMode?) throws -> SpeechTranscriptionResult
    let fileManager: FileManager

    init(
        sampleAudioResolver: @escaping () -> URL,
        transcribe: @escaping (URL, URL, SpeechLanguageMode?) throws -> SpeechTranscriptionResult,
        fileManager: FileManager = .default
    ) {
        self.sampleAudioResolver = sampleAudioResolver
        self.transcribe = transcribe
        self.fileManager = fileManager
    }

    func run(configURL: URL) throws -> SetupDoctorResult {
        var checks: [SetupDoctorCheck] = []

        guard fileManager.fileExists(atPath: configURL.path) else {
            checks.append(.init(name: "config", status: .failed, detail: "missing config at \(configURL.path)"))
            return SetupDoctorResult(checks: checks)
        }
        checks.append(.init(name: "config", status: .passed, detail: configURL.path))

        let settings: SpeechEngineSettings
        do {
            settings = try SpeechEngineSettings.load(from: configURL)
            checks.append(.init(name: "config-parse", status: .passed, detail: settings.selectedEngineID))
            checks.append(.init(name: "selected-mode", status: .passed, detail: settings.selectedMode.rawValue))
        } catch {
            checks.append(.init(name: "config-parse", status: .failed, detail: "\(error)"))
            return SetupDoctorResult(checks: checks)
        }

        appendEngineChecks(settings: settings, to: &checks)

        let sampleAudioURL = sampleAudioResolver()
        if fileManager.fileExists(atPath: sampleAudioURL.path) {
            checks.append(.init(name: "sample-audio", status: .passed, detail: sampleAudioURL.path))
        } else {
            checks.append(.init(name: "sample-audio", status: .failed, detail: "missing sample audio at \(sampleAudioURL.path)"))
        }

        if checks.allSatisfy({ $0.status == .passed }) {
            do {
                _ = try transcribe(configURL, sampleAudioURL, settings.selectedMode)
                checks.append(.init(name: "sample-transcribe", status: .passed, detail: "sample transcription succeeded"))
            } catch {
                checks.append(.init(name: "sample-transcribe", status: .failed, detail: "\(error)"))
            }
        }

        return SetupDoctorResult(checks: checks)
    }

    private func appendEngineChecks(settings: SpeechEngineSettings, to checks: inout [SetupDoctorCheck]) {
        for (engineID, config) in settings.availableEngines {
            let selectedMarker = engineID == settings.selectedEngineID ? " | selected" : ""
            let modes = config.supportedModes.map(\.rawValue).joined(separator: ",")
            checks.append(.init(
                name: "engine:\(engineID)",
                status: .passed,
                detail: "\(config.displayName)\(selectedMarker) | modes=\(modes) | default=\(config.defaultMode.rawValue) | runtime=\(config.runtimeProfile.rawValue)"
            ))

            let binaryURL = URL(fileURLWithPath: config.binaryPath)
            if fileManager.fileExists(atPath: binaryURL.path) {
                checks.append(.init(name: "engine:\(engineID):binary", status: .passed, detail: binaryURL.path))
            } else {
                checks.append(.init(
                    name: "engine:\(engineID):binary",
                    status: .failed,
                    detail: "missing binary at \(binaryURL.path)"
                ))
            }

            if fileManager.isExecutableFile(atPath: binaryURL.path) {
                checks.append(.init(name: "engine:\(engineID):binary-executable", status: .passed, detail: binaryURL.path))
            } else {
                checks.append(.init(
                    name: "engine:\(engineID):binary-executable",
                    status: .failed,
                    detail: "binary is not executable"
                ))
            }

            let modelURL = URL(fileURLWithPath: config.modelPath)
            if fileManager.fileExists(atPath: modelURL.path) {
                checks.append(.init(name: "engine:\(engineID):model", status: .passed, detail: modelURL.path))
            } else {
                checks.append(.init(
                    name: "engine:\(engineID):model",
                    status: .failed,
                    detail: "missing model at \(modelURL.path)"
                ))
            }

            for (key, path) in config.auxiliaryModelPaths.sorted(by: { $0.key < $1.key }) {
                if fileManager.fileExists(atPath: path) {
                    checks.append(.init(name: "engine:\(engineID):auxiliary-model:\(key)", status: .passed, detail: path))
                } else {
                    checks.append(.init(
                        name: "engine:\(engineID):auxiliary-model:\(key)",
                        status: .failed,
                        detail: "missing model at \(path)"
                    ))
                }
            }
        }
    }
}
