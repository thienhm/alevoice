import AleVoiceCore
import Combine
import Foundation

@MainActor
public final class TranscriptionDebugViewModel: ObservableObject {
    @Published public private(set) var transcript: String = ""
    @Published public private(set) var latencyText: String = ""
    @Published public private(set) var errorText: String?
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var recordingStatusText: String = "Recorder idle"
    @Published public private(set) var permissionStatusText: String = "Microphone permission: unknown"

    private let microphonePermissionStatusClosure: @Sendable () async -> MicrophonePermissionStatus
    private let startRecordingClosure: @Sendable () async throws -> Void
    private let stopRecordingClosure: @Sendable () async throws -> AudioRecordingResult
    private let transcribeClosure: @Sendable (URL, URL, SpeechLanguageMode) async throws -> SpeechTranscriptionResult
    private var requestToken = 0

    public init(
        microphonePermissionStatus: @escaping @Sendable () async -> MicrophonePermissionStatus = { .unknown },
        startRecording: @escaping @Sendable () async throws -> Void = {
            throw AudioRecorderError.captureFailed("recorder not configured")
        },
        stopRecording: @escaping @Sendable () async throws -> AudioRecordingResult = {
            throw AudioRecorderError.notRecording
        },
        transcribe: @escaping @Sendable (URL, URL, SpeechLanguageMode) async throws -> SpeechTranscriptionResult
    ) {
        self.microphonePermissionStatusClosure = microphonePermissionStatus
        self.startRecordingClosure = startRecording
        self.stopRecordingClosure = stopRecording
        self.transcribeClosure = transcribe
    }

    public func refreshPermissionStatus() async {
        let status = await microphonePermissionStatusClosure()
        permissionStatusText = "Microphone permission: \(Self.displayText(for: status))"
    }

    public func startRecording() async {
        isRunning = true
        do {
            try await startRecordingClosure()
            await refreshPermissionStatus()
            isRecording = true
            isRunning = false
            recordingStatusText = "Recording in progress"
            errorText = nil
        } catch {
            await refreshPermissionStatus()
            isRecording = false
            isRunning = false
            recordingStatusText = "Recorder idle"
            applyError(error)
        }
    }

    public func stopRecordingAndTranscribe(configURL: URL, mode: SpeechLanguageMode) async {
        guard isRecording else {
            applyError(AudioRecorderError.notRecording)
            return
        }

        requestToken += 1
        let token = requestToken
        isRunning = true

        do {
            let recording = try await stopRecordingClosure()
            guard token == requestToken else {
                return
            }
            isRecording = false
            recordingStatusText = "Transcribing recording"

            let result = try await transcribeClosure(configURL, recording.audioURL, mode)
            guard token == requestToken else {
                return
            }
            transcript = result.transcript
            latencyText = "\(result.latencyMs) ms"
            errorText = nil
            recordingStatusText = "Last recording ready"
            isRunning = false
        } catch {
            guard token == requestToken else {
                return
            }
            isRecording = false
            recordingStatusText = "Recorder idle"
            transcript = ""
            latencyText = ""
            applyError(error)
            isRunning = false
        }
    }

    public func runSample(configURL: URL, audioURL: URL, mode: SpeechLanguageMode) async {
        guard !isRecording else {
            applyError(AudioRecorderError.alreadyRecording)
            isRunning = false
            return
        }

        requestToken += 1
        let token = requestToken
        isRunning = true

        do {
            let result = try await transcribeClosure(configURL, audioURL, mode)
            guard token == requestToken else {
                return
            }
            transcript = result.transcript
            latencyText = "\(result.latencyMs) ms"
            errorText = nil
            isRunning = false
        } catch {
            guard token == requestToken else {
                return
            }
            transcript = ""
            latencyText = ""
            applyError(error)
            isRunning = false
        }
    }

    private func applyError(_ error: Error) {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            errorText = description
            return
        }

        errorText = String(describing: error)
    }

    private static func displayText(for status: MicrophonePermissionStatus) -> String {
        switch status {
        case .authorized:
            return "authorized"
        case .notDetermined:
            return "not determined"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        case .unknown:
            return "unknown"
        }
    }
}
