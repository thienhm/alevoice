import Foundation

public final class FunASRSpeechEngine: SpeechEngine {
    private let config: EnginePathConfig
    private let runner: ProcessRunning

    public init(config: EnginePathConfig, runner: ProcessRunning = SystemProcessRunner()) {
        self.config = config
        self.runner = runner
    }

    public func buildCommand(for request: SpeechTranscriptionRequest) throws -> [String] {
        try ensureModeSupported(request.mode)
        switch config.runtimeProfile {
        case .llamaCPP:
            return llamaCPPCommand(for: request)
        case .crispASRFunASR:
            return crispASRCommand(for: request)
        }
    }

    private func llamaCPPCommand(for request: SpeechTranscriptionRequest) -> [String] {
        if let encoderPath = config.auxiliaryModelPaths["encoder"] {
            return [
                config.binaryPath,
                "--enc",
                encoderPath,
                "-m",
                config.modelPath,
                "-a",
                request.audioURL.path,
            ]
        }
        return [
            config.binaryPath,
            "-m",
            config.modelPath,
            "-a",
            request.audioURL.path,
        ]
    }

    private func crispASRCommand(for request: SpeechTranscriptionRequest) -> [String] {
        [
            config.binaryPath,
            "--backend",
            "fun-asr-mlt-nano",
            "-m",
            config.modelPath,
            "-f",
            request.audioURL.path,
            "-l",
            request.mode.rawValue,
            "-nt",
            "-np",
        ]
    }

    public func transcribe(_ request: SpeechTranscriptionRequest) throws -> SpeechTranscriptionResult {
        let output = try runner.run(command: try buildCommand(for: request))
        let transcript = Self.parseTranscript(output.stdout)
        guard !transcript.isEmpty else {
            throw SpeechEngineError.emptyTranscript
        }

        return SpeechTranscriptionResult(
            engine: .funasr,
            modelIdentifier: config.modelPath,
            transcript: transcript,
            latencyMs: output.latencyMs
        )
    }

    static func parseTranscript(_ stdout: String) -> String {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^\[\d{2}:\d{2}:\d{2}\.\d{3}\s+-->\s+\d{2}:\d{2}:\d{2}\.\d{3}\]\s*(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: trimmed,
                  range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
              ),
              match.numberOfRanges == 2,
              let transcriptRange = Range(match.range(at: 1), in: trimmed)
        else {
            return trimmed
        }

        return String(trimmed[transcriptRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func ensureModeSupported(_ mode: SpeechLanguageMode) throws {
        guard config.supportedModes.contains(mode) else {
            throw SpeechEngineError.invalidConfiguration(
                "funasr runtime does not support explicit language mode '\(mode.rawValue)'"
            )
        }
    }
}
