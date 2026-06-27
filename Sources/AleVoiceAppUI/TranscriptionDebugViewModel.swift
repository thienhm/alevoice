import AleVoiceCore
import Combine
import Foundation

@MainActor
public final class TranscriptionDebugViewModel: ObservableObject {
    @Published public private(set) var sessionState: DictationSessionState = .idle
    @Published public private(set) var transcript: String = ""
    @Published public private(set) var latencyText: String = ""
    @Published public private(set) var errorText: String?
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var recordingStatusText: String = "Recorder idle"
    @Published public private(set) var permissionStatusText: String = "Microphone permission: unknown"
    @Published public private(set) var accessibilityStatusText: String = "Accessibility: unknown"
    @Published public var selectedMode: SpeechLanguageMode = .auto
    @Published public private(set) var inputMonitoringStatusText: String = "Input Monitoring: unknown"
    @Published public private(set) var shortcutDisplayText: String = "Dictation shortcut: not set"
    @Published public private(set) var shortcutCaptureText: String = ""
    @Published public private(set) var isCapturingShortcut: Bool = false

    private let microphonePermissionStatusClosure: @Sendable () async -> MicrophonePermissionStatus
    private let requestMicrophonePermissionClosure: @Sendable () async -> MicrophonePermissionStatus
    private let accessibilityPermissionStatusClosure: @Sendable () async -> AccessibilityPermissionStatus
    private let requestAccessibilityPermissionClosure: @Sendable () async -> AccessibilityPermissionStatus
    private let inputMonitoringPermissionStatusClosure: @Sendable () async -> InputMonitoringPermissionStatus
    private let requestInputMonitoringPermissionClosure: @Sendable () async -> InputMonitoringPermissionStatus
    private let openAccessibilitySettingsClosure: @Sendable () async -> Void
    private let openInputMonitoringSettingsClosure: @Sendable () async -> Void
    private let loadShortcutClosure: @Sendable () -> DictationShortcut?
    private let saveShortcutClosure: @Sendable (DictationShortcut) throws -> Void
    private let beginShortcutCaptureClosure: @Sendable () async -> Result<DictationShortcut, DictationShortcutError>
    private let onShortcutChangeClosure: @Sendable (DictationShortcut?) -> Void
    private let startRecordingClosure: @Sendable () async throws -> Void
    private let stopRecordingClosure: @Sendable () async throws -> AudioRecordingResult
    private let transcriptFormatter: TranscriptFormatter
    private let transcribeClosure: @Sendable (URL, URL, SpeechLanguageMode) async throws -> SpeechTranscriptionResult
    private let deliverTranscriptClosure: @Sendable (String) async throws -> Void
    private var requestToken = 0
    private var pendingGlobalShortcutReleaseConfigURL: URL?
    private var isGlobalShortcutActivationStarting = false

    public init(
        microphonePermissionStatus: @escaping @Sendable () async -> MicrophonePermissionStatus = { .unknown },
        requestMicrophonePermission: @escaping @Sendable () async -> MicrophonePermissionStatus = { .unknown },
        accessibilityPermissionStatus: @escaping @Sendable () async -> AccessibilityPermissionStatus = { .unknown },
        requestAccessibilityPermission: @escaping @Sendable () async -> AccessibilityPermissionStatus = { .unknown },
        inputMonitoringPermissionStatus: @escaping @Sendable () async -> InputMonitoringPermissionStatus = { .unknown },
        requestInputMonitoringPermission: @escaping @Sendable () async -> InputMonitoringPermissionStatus = { .unknown },
        openAccessibilitySettings: @escaping @Sendable () async -> Void = {},
        openInputMonitoringSettings: @escaping @Sendable () async -> Void = {},
        loadShortcut: @escaping @Sendable () -> DictationShortcut? = { nil },
        beginShortcutCapture: @escaping @Sendable () async -> Result<DictationShortcut, DictationShortcutError> = {
            .failure(.missingModifier)
        },
        saveShortcut: @escaping @Sendable (DictationShortcut) throws -> Void = { _ in },
        onShortcutChange: @escaping @Sendable (DictationShortcut?) -> Void = { _ in },
        startRecording: @escaping @Sendable () async throws -> Void = {
            throw AudioRecorderError.captureFailed("recorder not configured")
        },
        stopRecording: @escaping @Sendable () async throws -> AudioRecordingResult = {
            throw AudioRecorderError.notRecording
        },
        transcriptFormatter: TranscriptFormatter = TranscriptFormatter(),
        transcribe: @escaping @Sendable (URL, URL, SpeechLanguageMode) async throws -> SpeechTranscriptionResult,
        deliverTranscript: @escaping @Sendable (String) async throws -> Void = { _ in }
    ) {
        self.microphonePermissionStatusClosure = microphonePermissionStatus
        self.requestMicrophonePermissionClosure = requestMicrophonePermission
        self.accessibilityPermissionStatusClosure = accessibilityPermissionStatus
        self.requestAccessibilityPermissionClosure = requestAccessibilityPermission
        self.inputMonitoringPermissionStatusClosure = inputMonitoringPermissionStatus
        self.requestInputMonitoringPermissionClosure = requestInputMonitoringPermission
        self.openAccessibilitySettingsClosure = openAccessibilitySettings
        self.openInputMonitoringSettingsClosure = openInputMonitoringSettings
        self.loadShortcutClosure = loadShortcut
        self.saveShortcutClosure = saveShortcut
        self.beginShortcutCaptureClosure = beginShortcutCapture
        self.onShortcutChangeClosure = onShortcutChange
        self.startRecordingClosure = startRecording
        self.stopRecordingClosure = stopRecording
        self.transcriptFormatter = transcriptFormatter
        self.transcribeClosure = transcribe
        self.deliverTranscriptClosure = deliverTranscript
    }

    public func refreshPermissionStatus() async {
        let status = await microphonePermissionStatusClosure()
        permissionStatusText = "Microphone permission: \(Self.displayText(for: status))"
    }

    public func requestMicrophonePermission() async {
        let status = await requestMicrophonePermissionClosure()
        permissionStatusText = "Microphone permission: \(Self.displayText(for: status))"
    }

    public func refreshAccessibilityStatus() async {
        let status = await accessibilityPermissionStatusClosure()
        accessibilityStatusText = "Accessibility: \(Self.displayText(for: status))"
    }

    public func requestAccessibilityPermission() async {
        let status = await requestAccessibilityPermissionClosure()
        accessibilityStatusText = "Accessibility: \(Self.displayText(for: status))"
    }

    public func openAccessibilitySettings() async {
        await openAccessibilitySettingsClosure()
    }

    public func refreshInputMonitoringStatus() async {
        let status = await inputMonitoringPermissionStatusClosure()
        inputMonitoringStatusText = "Input Monitoring: \(Self.displayText(for: status))"
    }

    public func requestInputMonitoringPermission() async {
        let status = await requestInputMonitoringPermissionClosure()
        inputMonitoringStatusText = "Input Monitoring: \(Self.displayText(for: status))"
    }

    public func openInputMonitoringSettings() async {
        await openInputMonitoringSettingsClosure()
    }

    public func loadShortcut() {
        let shortcut = loadShortcutClosure()
        applyShortcut(shortcut)
        onShortcutChangeClosure(shortcut)
    }

    public func captureShortcut() async {
        pendingGlobalShortcutReleaseConfigURL = nil
        isCapturingShortcut = true
        shortcutCaptureText = "Press shortcut keys"

        let result = await beginShortcutCaptureClosure()
        switch result {
        case .success(let shortcut):
            do {
                try saveShortcutClosure(shortcut)
                applyShortcut(shortcut)
                onShortcutChangeClosure(shortcut)
                errorText = nil
            } catch {
                applyError(error)
            }
        case .failure(let error):
            applyError(error)
        }

        isCapturingShortcut = false
        shortcutCaptureText = ""
    }

    public func handleGlobalShortcutActivation() async {
        guard !isCapturingShortcut, !isRecording, !isRunning else {
            return
        }

        isGlobalShortcutActivationStarting = true
        await startRecording()
    }

    public func handleGlobalShortcutRelease(configURL: URL) async {
        guard !isCapturingShortcut else {
            return
        }

        if isGlobalShortcutActivationStarting {
            pendingGlobalShortcutReleaseConfigURL = configURL
            return
        }

        guard isRecording else {
            return
        }

        await stopRecordingAndTranscribe(configURL: configURL)
    }

    public func startRecording() async {
        guard !isCapturingShortcut else {
            return
        }

        isRunning = true
        do {
            try await startRecordingClosure()
            await refreshPermissionStatus()
            isRecording = true
            isRunning = false
            recordingStatusText = "Recording in progress"
            errorText = nil
            isGlobalShortcutActivationStarting = false
            sessionState = .recording

            if let pendingConfigURL = pendingGlobalShortcutReleaseConfigURL {
                pendingGlobalShortcutReleaseConfigURL = nil
                await stopRecordingAndTranscribe(configURL: pendingConfigURL)
            }
        } catch {
            pendingGlobalShortcutReleaseConfigURL = nil
            await refreshPermissionStatus()
            isRecording = false
            isRunning = false
            recordingStatusText = "Recorder idle"
            isGlobalShortcutActivationStarting = false
            applyError(error)
        }
    }

    public func stopRecordingAndTranscribe(configURL: URL, mode: SpeechLanguageMode = .auto) async {
        guard !isCapturingShortcut else {
            return
        }

        guard isRecording else {
            applyError(AudioRecorderError.notRecording)
            return
        }

        requestToken += 1
        let token = requestToken
        isRunning = true
        sessionState = .processing

        do {
            let recording = try await stopRecordingClosure()
            guard token == requestToken else {
                return
            }
            isRecording = false
            recordingStatusText = "Transcribing recording"

            let result = try await transcribeClosure(configURL, recording.audioURL, .auto)
            guard token == requestToken else {
                return
            }
            let formattedTranscript = transcriptFormatter.format(result.transcript)
            transcript = formattedTranscript
            latencyText = "\(result.latencyMs) ms"
            recordingStatusText = "Last recording ready"
            do {
                try await deliverTranscriptClosure(formattedTranscript)
            } catch {
                applyError(error)
                isRunning = false
                return
            }
            errorText = nil
            isRunning = false
            sessionState = .success(formattedTranscript)
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
        guard !isCapturingShortcut else {
            return
        }

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
            sessionState = .error(description)
            return
        }

        errorText = String(describing: error)
        sessionState = .error(errorText ?? String(describing: error))
    }

    private func applyShortcut(_ shortcut: DictationShortcut?) {
        if let shortcut {
            shortcutDisplayText = "Dictation shortcut: \(shortcut.displayText)"
        } else {
            shortcutDisplayText = "Dictation shortcut: not set"
        }
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

    private static func displayText(for status: InputMonitoringPermissionStatus) -> String {
        switch status {
        case .authorized:
            return "authorized"
        case .notDetermined:
            return "not determined"
        case .denied:
            return "denied"
        case .unknown:
            return "unknown"
        }
    }

    private static func displayText(for status: AccessibilityPermissionStatus) -> String {
        switch status {
        case .authorized:
            return "authorized"
        case .notDetermined:
            return "not determined"
        case .denied:
            return "denied"
        case .unknown:
            return "unknown"
        }
    }
}
