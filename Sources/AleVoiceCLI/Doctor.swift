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
        } catch {
            checks.append(.init(name: "config-parse", status: .failed, detail: "\(error)"))
            return SetupDoctorResult(checks: checks)
        }

        let binaryURL = URL(fileURLWithPath: settings.funasr.binaryPath)
        if fileManager.fileExists(atPath: binaryURL.path) {
            checks.append(.init(name: "binary", status: .passed, detail: binaryURL.path))
        } else {
            checks.append(.init(name: "binary", status: .failed, detail: "missing binary at \(binaryURL.path)"))
        }

        if fileManager.isExecutableFile(atPath: binaryURL.path) {
            checks.append(.init(name: "binary-executable", status: .passed, detail: binaryURL.path))
        } else {
            checks.append(.init(name: "binary-executable", status: .failed, detail: "binary is not executable"))
        }

        let modelURL = URL(fileURLWithPath: settings.funasr.modelPath)
        if fileManager.fileExists(atPath: modelURL.path) {
            checks.append(.init(name: "model", status: .passed, detail: modelURL.path))
        } else {
            checks.append(.init(name: "model", status: .failed, detail: "missing model at \(modelURL.path)"))
        }

        let sampleAudioURL = sampleAudioResolver()
        if fileManager.fileExists(atPath: sampleAudioURL.path) {
            checks.append(.init(name: "sample-audio", status: .passed, detail: sampleAudioURL.path))
        } else {
            checks.append(.init(name: "sample-audio", status: .failed, detail: "missing sample audio at \(sampleAudioURL.path)"))
        }

        if checks.allSatisfy({ $0.status == .passed }) {
            do {
                _ = try transcribe(configURL, sampleAudioURL, .auto)
                checks.append(.init(name: "sample-transcribe", status: .passed, detail: "sample transcription succeeded"))
            } catch {
                checks.append(.init(name: "sample-transcribe", status: .failed, detail: "\(error)"))
            }
        }

        return SetupDoctorResult(checks: checks)
    }
}
