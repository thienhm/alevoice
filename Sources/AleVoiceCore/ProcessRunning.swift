import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct ProcessOutput: Equatable, Sendable {
    public let stdout: String
    public let stderr: String
    public let latencyMs: Int

    public init(stdout: String, stderr: String, latencyMs: Int) {
        self.stdout = stdout
        self.stderr = stderr
        self.latencyMs = latencyMs
    }
}

public protocol ProcessRunning: Sendable {
    func run(command: [String]) throws -> ProcessOutput
}

public struct SystemProcessRunner: ProcessRunning, Sendable {
    private let timeoutSeconds: TimeInterval

    public init(timeoutSeconds: TimeInterval = 30) {
        self.timeoutSeconds = timeoutSeconds
    }

    public func run(command: [String]) throws -> ProcessOutput {
        guard let executable = command.first else {
            throw SpeechEngineError.processFailure("empty command")
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(command.dropFirst())
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutCapture = PipeCapture(
            handle: stdoutPipe.fileHandleForReading,
            label: "AleVoiceCore.SystemProcessRunner.stdout"
        )
        let stderrCapture = PipeCapture(
            handle: stderrPipe.fileHandleForReading,
            label: "AleVoiceCore.SystemProcessRunner.stderr"
        )
        let exitSemaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            exitSemaphore.signal()
        }

        let start = Date()
        stdoutCapture.start()
        stderrCapture.start()

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForWriting.closeFile()
            stderrPipe.fileHandleForWriting.closeFile()
            _ = stdoutCapture.wait(timeout: .now() + 1)
            _ = stderrCapture.wait(timeout: .now() + 1)
            throw error
        }

        stdoutPipe.fileHandleForWriting.closeFile()
        stderrPipe.fileHandleForWriting.closeFile()

        let didExitBeforeTimeout = exitSemaphore.wait(timeout: .now() + timeoutSeconds) == .success
        if didExitBeforeTimeout == false {
            terminate(process: process, exitSemaphore: exitSemaphore)
        }

        let stdoutData = stdoutCapture.wait(timeout: .now() + 1)
        let stderrData = stderrCapture.wait(timeout: .now() + 1)

        let latencyMs = Int(Date().timeIntervalSince(start) * 1000)
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        if didExitBeforeTimeout == false {
            throw SpeechEngineError.processFailure("funasr timed out after \(timeoutSeconds)s")
        }

        guard process.terminationStatus == 0 else {
            let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.isEmpty {
                throw SpeechEngineError.processFailure("funasr exited \(process.terminationStatus)")
            }
            throw SpeechEngineError.processFailure(message)
        }

        return ProcessOutput(stdout: stdout, stderr: stderr, latencyMs: latencyMs)
    }

    private func terminate(process: Process, exitSemaphore: DispatchSemaphore) {
        guard process.isRunning else {
            return
        }

        process.terminate()
        if exitSemaphore.wait(timeout: .now() + 1) == .success {
            return
        }

        guard process.isRunning else {
            return
        }

        #if canImport(Darwin)
        Darwin.kill(process.processIdentifier, SIGKILL)
        #elseif canImport(Glibc)
        _ = Glibc.kill(process.processIdentifier, SIGKILL)
        #endif
        _ = exitSemaphore.wait(timeout: .now() + 1)
    }
}

private final class PipeCapture: @unchecked Sendable {
    private let handle: FileHandle
    private let queue: DispatchQueue
    private let stateQueue = DispatchQueue(label: "AleVoiceCore.SystemProcessRunner.capture-state")
    private let semaphore = DispatchSemaphore(value: 0)
    private var data = Data()

    init(handle: FileHandle, label: String) {
        self.handle = handle
        self.queue = DispatchQueue(label: label)
    }

    func start() {
        queue.async { [self] in
            let captured = handle.readDataToEndOfFile()
            stateQueue.sync {
                data = captured
            }
            semaphore.signal()
        }
    }

    func wait(timeout: DispatchTime) -> Data {
        _ = semaphore.wait(timeout: timeout)
        return stateQueue.sync { data }
    }
}
