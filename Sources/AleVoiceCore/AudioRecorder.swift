import AVFoundation
import Foundation

public struct AudioRecordingResult: Equatable, Sendable {
    public let audioURL: URL
    public let byteCount: Int

    public init(audioURL: URL, byteCount: Int) {
        self.audioURL = audioURL
        self.byteCount = byteCount
    }
}

public enum MicrophonePermissionStatus: Equatable, Sendable {
    case authorized
    case notDetermined
    case denied
    case restricted
    case unknown
}

public enum AudioRecorderError: Error, Equatable, LocalizedError, Sendable {
    case permissionDenied
    case alreadyRecording
    case notRecording
    case emptyRecording
    case captureFailed(String)
    case finalizeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone permission denied"
        case .alreadyRecording:
            "Recording is already in progress"
        case .notRecording:
            "No recording is in progress"
        case .emptyRecording:
            "Recording produced no audio"
        case .captureFailed(let message):
            "Microphone capture failed: \(message)"
        case .finalizeFailed(let message):
            "Recording could not be finalized: \(message)"
        }
    }
}

public struct AudioRecordingFinalizeResult: Equatable, Sendable {
    public let durationSeconds: TimeInterval

    public init(durationSeconds: TimeInterval) {
        self.durationSeconds = durationSeconds
    }
}

public protocol AudioRecordingDriver: Sendable {
    func microphonePermissionStatus() async -> MicrophonePermissionStatus
    func requestRecordPermission() async -> Bool
    func startRecording(to url: URL) throws
    func stopRecording() throws -> AudioRecordingFinalizeResult
}

public actor AudioRecorder {
    private let driver: AudioRecordingDriver
    private let fileManager: FileManager

    private enum State {
        case idle
        case starting
        case recording(URL)
    }

    private var state: State = .idle

    public var isRecording: Bool {
        if case .recording = state {
            return true
        }
        return false
    }

    public init(
        driver: AudioRecordingDriver = AVFoundationAudioRecordingDriver(),
        fileManager: FileManager = .default
    ) {
        self.driver = driver
        self.fileManager = fileManager
    }

    public func microphonePermissionStatus() async -> MicrophonePermissionStatus {
        await driver.microphonePermissionStatus()
    }

    public func start() async throws {
        guard case .idle = state else {
            throw AudioRecorderError.alreadyRecording
        }
        state = .starting

        guard await driver.requestRecordPermission() else {
            state = .idle
            throw AudioRecorderError.permissionDenied
        }

        let url = temporaryWAVURL()
        do {
            try driver.startRecording(to: url)
            state = .recording(url)
        } catch {
            state = .idle
            try? fileManager.removeItem(at: url)
            throw AudioRecorderError.captureFailed(Self.message(for: error))
        }
    }

    public func stop() async throws -> AudioRecordingResult {
        guard case .recording(let url) = state else {
            throw AudioRecorderError.notRecording
        }

        do {
            let finalizeResult = try driver.stopRecording()
            state = .idle
            let byteCount = recordingByteCount(at: url)
            guard byteCount > 0, finalizeResult.durationSeconds > 0 else {
                try? fileManager.removeItem(at: url)
                throw AudioRecorderError.emptyRecording
            }

            return AudioRecordingResult(audioURL: url, byteCount: byteCount)
        } catch {
            state = .idle
            try? fileManager.removeItem(at: url)
            if let recordingError = error as? AudioRecorderError {
                throw recordingError
            }
            throw AudioRecorderError.finalizeFailed(Self.message(for: error))
        }
    }

    private func temporaryWAVURL() -> URL {
        fileManager.temporaryDirectory
            .appendingPathComponent("alevoice-recording-\(UUID().uuidString)")
            .appendingPathExtension("wav")
    }

    private func recordingByteCount(at url: URL) -> Int {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return attributes?[.size] as? Int ?? 0
    }

    private static func message(for error: Error) -> String {
        return String(describing: error)
    }
}

public final class AVFoundationAudioRecordingDriver: NSObject, AudioRecordingDriver, @unchecked Sendable {
    private var recorder: AVAudioRecorder?

    public func microphonePermissionStatus() async -> MicrophonePermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
    }

    public func requestRecordPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        @unknown default:
            return false
        }
    }

    public func startRecording(to url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw AudioRecorderError.captureFailed("AVAudioRecorder refused to start")
        }
        self.recorder = recorder
    }

    public func stopRecording() throws -> AudioRecordingFinalizeResult {
        guard let recorder else {
            throw AudioRecorderError.notRecording
        }
        let durationSeconds = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        return AudioRecordingFinalizeResult(durationSeconds: durationSeconds)
    }
}
