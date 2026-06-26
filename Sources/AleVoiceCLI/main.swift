import AleVoiceCore
import Foundation

struct CLIError: Error, CustomStringConvertible, Equatable {
    let description: String
}

struct CLIHelpRequested: Error {}

struct CLIArguments {
    let configPath: String
    let audioPath: String
    let mode: SpeechLanguageMode?

    init(arguments: [String]) throws {
        var configPath: String?
        var audioPath: String?
        var mode: SpeechLanguageMode?

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--config":
                configPath = try Self.value(after: argument, at: &index, in: arguments)
            case "--audio":
                audioPath = try Self.value(after: argument, at: &index, in: arguments)
            case "--mode":
                let rawMode = try Self.value(after: argument, at: &index, in: arguments)
                guard let parsedMode = SpeechLanguageMode(rawValue: rawMode) else {
                    throw CLIError(description: "invalid --mode value '\(rawMode)'. expected auto|en|vi")
                }
                mode = parsedMode
            case "--help", "-h":
                throw CLIHelpRequested()
            default:
                throw CLIError(description: "unknown argument '\(argument)'.\n\(Self.usage)")
            }
            index += 1
        }

        guard let configPath, let audioPath else {
            throw CLIError(description: Self.usage)
        }

        self.configPath = configPath
        self.audioPath = audioPath
        self.mode = mode
    }

    static let usage = "usage: AleVoiceCLI --config <path> --audio <path> [--mode auto|en|vi]"

    private static func value(after flag: String, at index: inout Int, in arguments: [String]) throws -> String {
        index += 1
        guard index < arguments.count, arguments[index].hasPrefix("-") == false else {
            throw CLIError(description: "missing value for \(flag)")
        }
        return arguments[index]
    }
}

enum AleVoiceCLIProgram {
    static func run(
        arguments: [String],
        standardOutput: (String) -> Void = { fputs($0, stdout) },
        standardError: (String) -> Void = { fputs($0, stderr) }
    ) -> Int32 {
        do {
            let arguments = try CLIArguments(arguments: arguments)
            let settings = try SpeechEngineSettings.load(
                from: URL(fileURLWithPath: arguments.configPath)
            )
            let coordinator = TranscriptionCoordinator(settings: settings)
            let result = try coordinator.transcribe(
                audioURL: URL(fileURLWithPath: arguments.audioPath),
                overrideMode: arguments.mode
            )
            standardOutput("engine=\(result.engine.rawValue)\n")
            standardOutput("latency_ms=\(result.latencyMs)\n")
            standardOutput("\(result.transcript)\n")
            return 0
        } catch is CLIHelpRequested {
            standardOutput("\(CLIArguments.usage)\n")
            return 0
        } catch {
            standardError("\(error)\n")
            return 1
        }
    }
}

@main
struct AleVoiceCLI {
    static func main() {
        Foundation.exit(AleVoiceCLIProgram.run(arguments: Array(CommandLine.arguments.dropFirst())))
    }
}
