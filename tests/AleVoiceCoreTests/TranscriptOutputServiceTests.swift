import XCTest
@testable import AleVoiceCore

final class TranscriptOutputServiceTests: XCTestCase {
    func test_deliverPassesThroughTranscript() async throws {
        let probe = TranscriptDeliveryProbe()
        let service = TranscriptOutputService { transcript in
            await probe.record(transcript)
        }

        try await service.deliver("hello world")

        let delivered = await probe.transcripts()
        XCTAssertEqual(delivered, ["hello world"])
    }

    func test_deliverPreservesNonEmptyTranscriptWhitespace() async throws {
        let probe = TranscriptDeliveryProbe()
        let service = TranscriptOutputService { transcript in
            await probe.record(transcript)
        }

        try await service.deliver("  hello world\n")

        let delivered = await probe.transcripts()
        XCTAssertEqual(delivered, ["  hello world\n"])
    }

    func test_deliverRejectsWhitespaceOnlyTranscript() async {
        let probe = TranscriptDeliveryProbe()
        let service = TranscriptOutputService { transcript in
            await probe.record(transcript)
        }

        do {
            try await service.deliver("   \n\t  ")
            XCTFail("expected empty transcript error")
        } catch {
            XCTAssertEqual(error as? TranscriptOutputError, .emptyTranscript)
        }

        let delivered = await probe.transcripts()
        XCTAssertTrue(delivered.isEmpty)
    }

    func test_deliverPropagatesDriverFailure() async {
        enum StubError: Error, Equatable {
            case failed
        }

        let service = TranscriptOutputService { _ in
            throw StubError.failed
        }

        do {
            try await service.deliver("hello")
            XCTFail("expected driver failure")
        } catch {
            XCTAssertEqual(error as? StubError, .failed)
        }
    }
}

private actor TranscriptDeliveryProbe {
    private var storedTranscripts: [String] = []

    func record(_ transcript: String) {
        storedTranscripts.append(transcript)
    }

    func transcripts() -> [String] {
        storedTranscripts
    }
}
