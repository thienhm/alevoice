import XCTest
@testable import AleVoiceCore

final class TranscriptFormatterTests: XCTestCase {
    func test_formats_english_newline_and_punctuation_commands() {
        let formatter = TranscriptFormatter()

        let output = formatter.format("new line benchmark summary colon faster period")

        XCTAssertEqual(output, "\nbenchmark summary: faster.")
    }

    func test_formats_vietnamese_commands() {
        let formatter = TranscriptFormatter()

        let output = formatter.format("xuống dòng ghi chú dấu hai chấm xong dấu chấm")

        XCTAssertEqual(output, "\nghi chú: xong.")
    }

    func test_preserves_normal_bilingual_prompt_text() {
        let formatter = TranscriptFormatter()

        let output = formatter.format("viet mot prompt about Swift concurrency")

        XCTAssertEqual(output, "viet mot prompt about Swift concurrency")
    }
}
