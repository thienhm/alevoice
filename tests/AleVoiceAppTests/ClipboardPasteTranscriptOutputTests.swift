import AleVoiceCore
import XCTest
@testable import AleVoiceApp

@MainActor
final class ClipboardPasteTranscriptOutputTests: XCTestCase {
    func test_deliverWritesTranscriptPostsPasteAndRestoresPreviousString() async throws {
        let probe = ClipboardPasteProbe(initialString: "previous")
        let output = ClipboardPasteTranscriptOutput(
            accessibilityStatus: { .authorized },
            currentString: { probe.currentString },
            clearContents: { probe.clear() },
            setString: { probe.set($0) },
            postPasteShortcut: { probe.postPaste() },
            restoreString: { probe.restore($0) },
            restoreDelayNanoseconds: 0
        )

        try await output.deliver("hello")

        XCTAssertEqual(probe.events, [
            "clear",
            "set:hello",
            "paste",
            "restore:previous"
        ])
        XCTAssertEqual(probe.currentString, "previous")
    }

    func test_deliverThrowsWhenAccessibilityIsNotAuthorized() async {
        let probe = ClipboardPasteProbe(initialString: "previous")
        let output = ClipboardPasteTranscriptOutput(
            accessibilityStatus: { .denied },
            currentString: { probe.currentString },
            clearContents: { probe.clear() },
            setString: { probe.set($0) },
            postPasteShortcut: { probe.postPaste() },
            restoreString: { probe.restore($0) },
            restoreDelayNanoseconds: 0
        )

        do {
            try await output.deliver("hello")
            XCTFail("expected accessibility error")
        } catch {
            XCTAssertEqual(error as? ClipboardPasteTranscriptOutputError, .accessibilityDenied)
        }

        XCTAssertTrue(probe.events.isEmpty)
        XCTAssertEqual(probe.currentString, "previous")
    }
}

@MainActor
private final class ClipboardPasteProbe {
    var currentString: String?
    private(set) var events: [String] = []

    init(initialString: String?) {
        self.currentString = initialString
    }

    func clear() {
        events.append("clear")
        currentString = nil
    }

    func set(_ string: String) -> Bool {
        events.append("set:\(string)")
        currentString = string
        return true
    }

    func postPaste() -> Bool {
        events.append("paste")
        return true
    }

    func restore(_ string: String?) {
        events.append("restore:\(string ?? "nil")")
        currentString = string
    }
}
