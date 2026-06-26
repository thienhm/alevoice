import AleVoiceCore
import Combine
import Foundation

@MainActor
public final class TranscriptionDebugViewModel: ObservableObject {
    @Published public private(set) var transcript: String = ""
    @Published public private(set) var latencyText: String = ""
    @Published public private(set) var errorText: String?
    @Published public private(set) var isRunning: Bool = false

    private let transcribeClosure: @Sendable (URL, URL, SpeechLanguageMode) async throws -> SpeechTranscriptionResult
    private var requestToken = 0

    public init(
        transcribe: @escaping @Sendable (URL, URL, SpeechLanguageMode) async throws -> SpeechTranscriptionResult
    ) {
        self.transcribeClosure = transcribe
    }

    public func runSample(configURL: URL, audioURL: URL, mode: SpeechLanguageMode) async {
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
            errorText = String(describing: error)
            isRunning = false
        }
    }
}
