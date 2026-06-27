import Foundation

public struct TranscriptFormatter {
    public init() {}

    public func format(_ transcript: String) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        let replacements: [(String, String)] = [
            ("dấu hai chấm", ":"),
            ("question mark", "?"),
            ("new line", "\n"),
            ("newline", "\n"),
            ("xuong dong", "\n"),
            ("xuống dòng", "\n"),
            ("dấu phẩy", ","),
            ("dấu chấm", "."),
            ("dấu hỏi", "?"),
            ("comma", ","),
            ("period", "."),
            ("colon", ":"),
        ]

        var output = trimmed
        for (source, target) in replacements.sorted(by: { $0.0.count > $1.0.count }) {
            output = output.replacingOccurrences(of: source, with: target)
        }

        output = output.replacingOccurrences(of: " \n", with: "\n")
        output = output.replacingOccurrences(of: "\n ", with: "\n")
        output = output.replacingOccurrences(of: " :", with: ":")
        output = output.replacingOccurrences(of: " ,", with: ",")
        output = output.replacingOccurrences(of: " .", with: ".")
        output = output.replacingOccurrences(of: " ?", with: "?")

        return output
    }
}
