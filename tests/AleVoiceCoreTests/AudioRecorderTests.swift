import XCTest
@testable import AleVoiceCore

final class AudioRecorderTests: XCTestCase {
    func test_microphonePermissionStatusReadsDriverStatus() async throws {
        let recorder = AudioRecorder(
            driver: FakeAudioRecordingDriver(permissionStatus: .denied)
        )

        let status = await recorder.microphonePermissionStatus()

        XCTAssertEqual(status, .denied)
    }

    func test_startThenStopWritesTemporaryWAVAndReturnsEngineReadyURL() async throws {
        let driver = FakeAudioRecordingDriver()
        let recorder = AudioRecorder(driver: driver)

        try await recorder.start()
        let isRecordingAfterStart = await recorder.isRecording
        XCTAssertTrue(isRecordingAfterStart)
        XCTAssertEqual(driver.startedURLs.count, 1)
        XCTAssertEqual(driver.startedURLs.first?.pathExtension, "wav")

        let result = try await recorder.stop()

        let isRecordingAfterStop = await recorder.isRecording
        XCTAssertFalse(isRecordingAfterStop)
        XCTAssertEqual(result.audioURL, driver.startedURLs.first)
        XCTAssertEqual(result.byteCount, 64)
        XCTAssertEqual(driver.stopCallCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.audioURL.path))
    }

    func test_startThrowsPermissionDeniedWhenDriverDeniesAccess() async throws {
        let recorder = AudioRecorder(driver: FakeAudioRecordingDriver(permissionGranted: false))

        do {
            try await recorder.start()
            XCTFail("Expected permission denial")
        } catch let error as AudioRecorderError {
            XCTAssertEqual(error, .permissionDenied)
        }
    }

    func test_startMapsDriverFailureToCaptureFailure() async throws {
        let recorder = AudioRecorder(
            driver: FakeAudioRecordingDriver(startError: StubError(message: "device unavailable"))
        )

        do {
            try await recorder.start()
            XCTFail("Expected capture failure")
        } catch let error as AudioRecorderError {
            XCTAssertEqual(error, .captureFailed("device unavailable"))
            let isRecording = await recorder.isRecording
            XCTAssertFalse(isRecording)
        }
    }

    func test_startRejectsConcurrentCallerWhilePermissionRequestIsStillPending() async throws {
        let driver = FakeAudioRecordingDriver(permissionContinuationMode: .manual)
        let recorder = AudioRecorder(driver: driver)

        let firstStart = Task {
            try await recorder.start()
        }
        await driver.waitForPermissionRequest()

        do {
            try await recorder.start()
            XCTFail("Expected already recording while first start is in flight")
        } catch let error as AudioRecorderError {
            XCTAssertEqual(error, .alreadyRecording)
        }

        await driver.resumePermissionRequest(with: true)
        try await firstStart.value

        let isRecording = await recorder.isRecording
        XCTAssertTrue(isRecording)
        XCTAssertEqual(driver.startedURLs.count, 1)
    }

    func test_startThrowsAlreadyRecordingWhenCalledTwice() async throws {
        let recorder = AudioRecorder(driver: FakeAudioRecordingDriver())

        try await recorder.start()

        do {
            try await recorder.start()
            XCTFail("Expected already recording")
        } catch let error as AudioRecorderError {
            XCTAssertEqual(error, .alreadyRecording)
        }
    }

    func test_stopThrowsNotRecordingWhenIdle() async throws {
        let recorder = AudioRecorder(driver: FakeAudioRecordingDriver())

        do {
            _ = try await recorder.stop()
            XCTFail("Expected not recording")
        } catch let error as AudioRecorderError {
            XCTAssertEqual(error, .notRecording)
        }
    }

    func test_stopThrowsEmptyRecordingWhenDriverReportsZeroDuration() async throws {
        let driver = FakeAudioRecordingDriver(recordedByteCount: 4096, recordedDurationSeconds: 0)
        let recorder = AudioRecorder(driver: driver)

        try await recorder.start()
        let url = try XCTUnwrap(driver.startedURLs.first)

        do {
            _ = try await recorder.stop()
            XCTFail("Expected empty recording")
        } catch let error as AudioRecorderError {
            XCTAssertEqual(error, .emptyRecording)
            let isRecording = await recorder.isRecording
            XCTAssertFalse(isRecording)
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func test_stopMapsDriverFailureToFinalizeFailureAndClearsRecordingState() async throws {
        let driver = FakeAudioRecordingDriver(stopError: StubError(message: "disk full"))
        let recorder = AudioRecorder(driver: driver)

        try await recorder.start()
        let url = try XCTUnwrap(driver.startedURLs.first)

        do {
            _ = try await recorder.stop()
            XCTFail("Expected finalize failure")
        } catch let error as AudioRecorderError {
            XCTAssertEqual(error, .finalizeFailed("disk full"))
            let isRecording = await recorder.isRecording
            XCTAssertFalse(isRecording)
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func test_transcriptionCoordinatorReceivesRecordedAudioURLAndExplicitMode() async throws {
        let driver = FakeAudioRecordingDriver()
        let recorder = AudioRecorder(driver: driver)
        let engine = StubSpeechEngine(
            result: SpeechTranscriptionResult(
                engine: .funasr,
                modelIdentifier: "model",
                transcript: "recorded phrase",
                latencyMs: 42
            )
        )
        let coordinator = TranscriptionCoordinator(
            settings: SpeechEngineSettings(
                engine: .funasr,
                funasr: EnginePathConfig(
                    binaryPath: "/tmp/funasr",
                    modelPath: "/tmp/model",
                    defaultMode: .auto
                )
            ),
            engineFactory: { _ in engine }
        )

        try await recorder.start()
        let recording = try await recorder.stop()
        let result = try coordinator.transcribe(audioURL: recording.audioURL, overrideMode: .en)

        XCTAssertEqual(result.transcript, "recorded phrase")
        XCTAssertEqual(engine.lastRequest?.audioURL, recording.audioURL)
        XCTAssertEqual(engine.lastRequest?.mode, .en)
    }
}

private final class FakeAudioRecordingDriver: @unchecked Sendable, AudioRecordingDriver {
    enum PermissionContinuationMode {
        case immediate
        case manual
    }

    var permissionGranted: Bool
    var recordedByteCount: Int
    var recordedDurationSeconds: TimeInterval
    var startError: Error?
    var stopError: Error?
    var permissionStatus: MicrophonePermissionStatus
    var permissionContinuationMode: PermissionContinuationMode
    private(set) var startedURLs: [URL] = []
    private(set) var stopCallCount = 0
    private let permissionGate = AsyncPermissionGate()

    init(
        permissionGranted: Bool = true,
        recordedByteCount: Int = 64,
        recordedDurationSeconds: TimeInterval = 0.25,
        startError: Error? = nil,
        stopError: Error? = nil,
        permissionStatus: MicrophonePermissionStatus = .authorized,
        permissionContinuationMode: PermissionContinuationMode = .immediate
    ) {
        self.permissionGranted = permissionGranted
        self.recordedByteCount = recordedByteCount
        self.recordedDurationSeconds = recordedDurationSeconds
        self.startError = startError
        self.stopError = stopError
        self.permissionStatus = permissionStatus
        self.permissionContinuationMode = permissionContinuationMode
    }

    func microphonePermissionStatus() async -> MicrophonePermissionStatus {
        permissionStatus
    }

    func requestRecordPermission() async -> Bool {
        if permissionContinuationMode == .manual {
            await permissionGate.markRequested()
            await permissionGate.wait()
        }
        return permissionGranted
    }

    func startRecording(to url: URL) throws {
        if let startError {
            throw startError
        }
        startedURLs.append(url)
    }

    func stopRecording() throws -> AudioRecordingFinalizeResult {
        stopCallCount += 1
        if let stopError {
            throw stopError
        }
        guard let url = startedURLs.last else {
            return AudioRecordingFinalizeResult(durationSeconds: recordedDurationSeconds)
        }
        try Data(repeating: 1, count: recordedByteCount).write(to: url)
        return AudioRecordingFinalizeResult(durationSeconds: recordedDurationSeconds)
    }

    func waitForPermissionRequest() async {
        await permissionGate.waitForRequest()
    }

    func resumePermissionRequest(with value: Bool) async {
        permissionGranted = value
        await permissionGate.resume()
    }
}

private struct StubError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

private final class StubSpeechEngine: @unchecked Sendable, SpeechEngine {
    let result: SpeechTranscriptionResult
    private(set) var lastRequest: SpeechTranscriptionRequest?

    init(result: SpeechTranscriptionResult) {
        self.result = result
    }

    func transcribe(_ request: SpeechTranscriptionRequest) throws -> SpeechTranscriptionResult {
        lastRequest = request
        return result
    }
}

private actor AsyncPermissionGate {
    private var requestContinuation: CheckedContinuation<Void, Never>?
    private var resumeContinuation: CheckedContinuation<Void, Never>?
    private var didRequest = false

    func markRequested() {
        didRequest = true
        requestContinuation?.resume()
        requestContinuation = nil
    }

    func waitForRequest() async {
        if didRequest {
            return
        }
        await withCheckedContinuation { continuation in
            requestContinuation = continuation
        }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            resumeContinuation = continuation
        }
    }

    func resume() {
        resumeContinuation?.resume()
        resumeContinuation = nil
    }
}
