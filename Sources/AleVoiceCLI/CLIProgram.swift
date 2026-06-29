import AleVoiceCore
import Foundation

struct CLIError: Error, CustomStringConvertible, Equatable {
    let description: String
}

struct CLIHelpRequested: Error {}

struct CLIArguments {
    let configPath: String?
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

        guard let audioPath else {
            throw CLIError(description: Self.usage)
        }

        self.configPath = configPath
        self.audioPath = audioPath
        self.mode = mode
    }

    static let usage = "usage: AleVoiceCLI transcribe [--config <path>] --audio <path> [--mode auto|en|vi]"

    private static func value(after flag: String, at index: inout Int, in arguments: [String]) throws -> String {
        index += 1
        guard index < arguments.count, arguments[index].hasPrefix("-") == false else {
            throw CLIError(description: "missing value for \(flag)")
        }
        return arguments[index]
    }
}

struct CLIContext {
    let manifestLoader: (String) throws -> SetupManifest
    let installer: (SetupInstallRequest) throws -> SetupInstallResult
    let doctor: (URL) throws -> SetupDoctorResult
    let transcribe: (URL, URL, SpeechLanguageMode?) throws -> SpeechTranscriptionResult
    let runApp: () throws -> Void
    let configPathResolver: () -> URL
    let installRootResolver: () -> URL
    let sampleAudioResolver: () -> URL

    static func live() -> CLIContext {
        let configResolver = {
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
                .appendingPathComponent("Config/speech-engine.json")
        }
        let sampleAudioResolver = {
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
                .appendingPathComponent("data/benchmarks/samples/en-001.wav")
        }
        let transcribeClosure: (URL, URL, SpeechLanguageMode?) throws -> SpeechTranscriptionResult = { configURL, audioURL, mode in
            let settings = try SpeechEngineSettings.load(from: configURL)
            let coordinator = TranscriptionCoordinator(settings: settings)
            return try coordinator.transcribe(audioURL: audioURL, overrideMode: mode)
        }

        return CLIContext(
            manifestLoader: { engineID in
                try SetupManifest.load(
                    from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
                        .appendingPathComponent("Config/engines/\(engineID).json")
                )
            },
            installer: { request in
                let doctor = AleVoiceDoctor(sampleAudioResolver: sampleAudioResolver, transcribe: transcribeClosure)
                return try SetupInstaller(doctor: doctor.run(configURL:)).install(request: request)
            },
            doctor: { configURL in
                try AleVoiceDoctor(sampleAudioResolver: sampleAudioResolver, transcribe: transcribeClosure).run(configURL: configURL)
            },
            transcribe: transcribeClosure,
            runApp: {
                try CLIProcessRunner().run(command: [
                    "/bin/sh",
                    "-lc",
                    "DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/run-alevoice-app"
                ])
            },
            configPathResolver: configResolver,
            installRootResolver: {
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support/AleVoice", isDirectory: true)
            },
            sampleAudioResolver: sampleAudioResolver
        )
    }

    static func failingDefaults() -> CLIContext {
        CLIContext(
            manifestLoader: { _ in throw CLIError(description: "unexpected manifest load") },
            installer: { _ in throw CLIError(description: "unexpected install") },
            doctor: { _ in throw CLIError(description: "unexpected doctor") },
            transcribe: { _, _, _ in throw CLIError(description: "unexpected transcribe") },
            runApp: { throw CLIError(description: "unexpected run") },
            configPathResolver: { URL(fileURLWithPath: "/tmp/config.json") },
            installRootResolver: { URL(fileURLWithPath: "/tmp/install", isDirectory: true) },
            sampleAudioResolver: { URL(fileURLWithPath: "/tmp/sample.wav") }
        )
    }
}

enum CLICommand {
    case help
    case setup(engineID: String, configURL: URL?, installRoot: URL?, forceDownload: Bool)
    case doctor(configURL: URL?)
    case transcribe(CLIArguments)
    case run
}

enum CLICommandParser {
    static func parse(arguments: [String]) throws -> CLICommand {
        guard let first = arguments.first else {
            return .help
        }

        if first == "--help" || first == "-h" || first == "help" {
            return .help
        }

        if first.hasPrefix("-") {
            return .transcribe(try CLIArguments(arguments: arguments))
        }

        switch first {
        case "setup":
            return try parseSetup(arguments: Array(arguments.dropFirst()))
        case "doctor":
            return try parseDoctor(arguments: Array(arguments.dropFirst()))
        case "transcribe":
            return .transcribe(try CLIArguments(arguments: Array(arguments.dropFirst())))
        case "run":
            return .run
        default:
            throw CLIError(description: "unknown command '\(first)'.\n\(CLIUsage.text)")
        }
    }

    private static func parseSetup(arguments: [String]) throws -> CLICommand {
        guard let engineID = arguments.first else {
            throw CLIError(description: "missing engine id\n\(CLIUsage.text)")
        }

        var configURL: URL?
        var installRoot: URL?
        var forceDownload = false
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--config-path":
                index += 1
                guard index < arguments.count else {
                    throw CLIError(description: "missing value for --config-path")
                }
                configURL = URL(fileURLWithPath: arguments[index])
            case "--install-root":
                index += 1
                guard index < arguments.count else {
                    throw CLIError(description: "missing value for --install-root")
                }
                installRoot = URL(fileURLWithPath: arguments[index], isDirectory: true)
            case "--force-download":
                forceDownload = true
            default:
                throw CLIError(description: "unknown setup argument '\(argument)'")
            }
            index += 1
        }

        return .setup(engineID: engineID, configURL: configURL, installRoot: installRoot, forceDownload: forceDownload)
    }

    private static func parseDoctor(arguments: [String]) throws -> CLICommand {
        var configURL: URL?
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--config-path":
                index += 1
                guard index < arguments.count else {
                    throw CLIError(description: "missing value for --config-path")
                }
                configURL = URL(fileURLWithPath: arguments[index])
            default:
                throw CLIError(description: "unknown doctor argument '\(argument)'")
            }
            index += 1
        }
        return .doctor(configURL: configURL)
    }
}

enum CLIUsage {
    static let text = """
    usage: AleVoiceCLI <command>

    commands:
      setup <engine-id> [--config-path <path>] [--install-root <path>] [--force-download]
      doctor [--config-path <path>]
      transcribe [--config <path>] --audio <path> [--mode auto|en|vi]
      run
    """
}

enum AleVoiceCLIProgram {
    static func run(
        arguments: [String],
        context: CLIContext = .live(),
        standardOutput: (String) -> Void = { fputs($0, stdout) },
        standardError: (String) -> Void = { fputs($0, stderr) }
    ) -> Int32 {
        do {
            switch try CLICommandParser.parse(arguments: arguments) {
            case .help:
                standardOutput(CLIUsage.text + "\n")
                return 0
            case let .setup(engineID, configURL, installRoot, forceDownload):
                let manifest = try context.manifestLoader(engineID)
                standardOutput("setting up \(engineID); downloads may take several minutes\n")
                let result = try context.installer(
                    .init(
                        manifest: manifest,
                        installRoot: installRoot ?? context.installRootResolver(),
                        configURL: configURL ?? context.configPathResolver(),
                        platform: try SetupPlatform.current(),
                        variantName: nil,
                        forceDownload: forceDownload
                    )
                )
                standardOutput("installed \(engineID)\n")
                standardOutput("binary=\(result.binaryURL.path)\n")
                standardOutput("model=\(result.modelURL.path)\n")
                standardOutput("config=\(result.configURL.path)\n")
                return 0
            case let .doctor(configURL):
                let result = try context.doctor(configURL ?? context.configPathResolver())
                for check in result.checks {
                    let statusText = check.status == .passed ? "passed" : "failed"
                    standardOutput("\(check.name): \(statusText) - \(check.detail)\n")
                }
                return result.isHealthy ? 0 : 1
            case let .transcribe(arguments):
                let configURL = URL(fileURLWithPath: arguments.configPath ?? context.configPathResolver().path)
                let result = try context.transcribe(
                    configURL,
                    URL(fileURLWithPath: arguments.audioPath),
                    arguments.mode
                )
                standardOutput("engine=\(result.engine.rawValue)\n")
                standardOutput("latency_ms=\(result.latencyMs)\n")
                standardOutput("\(result.transcript)\n")
                return 0
            case .run:
                try context.runApp()
                standardOutput("launching app\n")
                return 0
            }
        } catch is CLIHelpRequested {
            standardOutput(CLIUsage.text + "\n")
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

private struct CLIProcessRunner {
    func run(command: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command[0])
        process.arguments = Array(command.dropFirst())
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CLIError(description: "command failed with exit \(process.terminationStatus)")
        }
    }
}
