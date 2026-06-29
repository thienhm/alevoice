import AleVoiceCore
import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel: TranscriptionDebugViewModel
    private let configURL: URL
    private let sampleAudioURL: URL

    public init(
        viewModel: TranscriptionDebugViewModel,
        assetLocator: DebugAssetLocator = DebugAssetLocator()
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.configURL = assetLocator.speechEngineConfigURL()
        self.sampleAudioURL = assetLocator.englishSampleAudioURL()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enabled", isOn: Binding(
                get: { viewModel.isDictationEnabled },
                set: { viewModel.setDictationEnabled($0) }
            ))
            .disabled(!viewModel.canToggleDictationEnabled)

            HStack(spacing: 12) {
                Picker("Model", selection: Binding(
                    get: { viewModel.selectedEngineID },
                    set: { viewModel.selectEngine(id: $0) }
                )) {
                    ForEach(viewModel.availableEngines, id: \.id) { engine in
                        Text(engine.displayName).tag(engine.id)
                    }
                }
                .frame(width: 220)

                Picker("Language", selection: Binding(
                    get: { viewModel.selectedMode },
                    set: { viewModel.selectMode($0) }
                )) {
                    ForEach(viewModel.availableLanguageModes, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .frame(width: 180)
            }
            .disabled(viewModel.isCapturingShortcut || viewModel.isRunning || viewModel.isRecording)

            HStack(spacing: 12) {
                Text(viewModel.permissionStatusText)
                Button("Refresh permission status") {
                    Task {
                        await viewModel.refreshPermissionStatus()
                    }
                }
                Button("Request Microphone") {
                    Task {
                        await viewModel.requestMicrophonePermission()
                    }
                }
            }

            HStack(spacing: 12) {
                Text(viewModel.accessibilityStatusText)
                Button("Refresh Accessibility") {
                    Task {
                        await viewModel.refreshAccessibilityStatus()
                    }
                }
                Button("Request Accessibility") {
                    Task {
                        await viewModel.requestAccessibilityPermission()
                    }
                }
                Button("Open Settings") {
                    Task {
                        await viewModel.openAccessibilitySettings()
                    }
                }
            }

            HStack(spacing: 12) {
                Text(viewModel.inputMonitoringStatusText)
                Button("Refresh Input Monitoring") {
                    Task {
                        await viewModel.refreshInputMonitoringStatus()
                    }
                }
                Button("Request / Re-check") {
                    Task {
                        await viewModel.requestInputMonitoringPermission()
                    }
                }
                Button("Open Settings") {
                    Task {
                        await viewModel.openInputMonitoringSettings()
                    }
                }
            }

            HStack(spacing: 12) {
                Text(viewModel.shortcutDisplayText)
                Button("Record shortcut") {
                    Task {
                        await viewModel.captureShortcut()
                    }
                }
                .disabled(viewModel.isCapturingShortcut || viewModel.isRunning || viewModel.isRecording)
            }

            if !viewModel.shortcutCaptureText.isEmpty {
                Text(viewModel.shortcutCaptureText)
            }

            HStack(spacing: 12) {
                Button("Start microphone capture") {
                    Task {
                        await viewModel.startRecording()
                    }
                }
                .disabled(viewModel.isCapturingShortcut || viewModel.isRunning || viewModel.isRecording || !viewModel.isDictationEnabled)

                Button("Stop and transcribe recording") {
                    Task {
                        await viewModel.stopRecordingAndTranscribe(configURL: configURL)
                    }
                }
                .disabled(viewModel.isCapturingShortcut || viewModel.isRunning || !viewModel.isRecording || !viewModel.isDictationEnabled)
            }

            Button("Transcribe en-001 sample") {
                Task {
                    await viewModel.runSample(
                        configURL: configURL,
                        audioURL: sampleAudioURL,
                        mode: viewModel.selectedMode
                    )
                }
            }
            .disabled(viewModel.isCapturingShortcut || viewModel.isRunning || viewModel.isRecording)

            Text(viewModel.recordingStatusText)
            Text(viewModel.latencyText)
            Text(viewModel.transcript)
                .textSelection(.enabled)

            if let errorText = viewModel.errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 260)
        .task {
            if let settings = try? SpeechEngineSettings.load(from: configURL) {
                viewModel.applySpeechEngineSettings(settings)
            }
            viewModel.loadShortcut()
            await viewModel.refreshPermissionStatus()
            await viewModel.refreshAccessibilityStatus()
            await viewModel.refreshInputMonitoringStatus()
        }
    }
}
