import AleVoiceCore
import AppKit
import CoreGraphics
import Foundation

enum ClipboardPasteTranscriptOutputError: Error, Equatable, LocalizedError {
    case accessibilityDenied
    case pasteboardWriteFailed
    case pasteEventCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            return "Accessibility permission denied"
        case .pasteboardWriteFailed:
            return "Failed to write transcript to clipboard"
        case .pasteEventCreationFailed:
            return "Failed to post paste shortcut"
        }
    }
}

@MainActor
struct ClipboardPasteTranscriptOutput {
    private let accessibilityStatus: () -> AccessibilityPermissionStatus
    private let currentString: () -> String?
    private let clearContents: () -> Void
    private let setString: (String) -> Bool
    private let postPasteShortcut: () -> Bool
    private let restoreString: (String?) -> Void
    private let restoreDelayNanoseconds: UInt64

    init(
        accessibilityStatus: @escaping () -> AccessibilityPermissionStatus,
        currentString: @escaping () -> String? = {
            NSPasteboard.general.string(forType: .string)
        },
        clearContents: @escaping () -> Void = {
            NSPasteboard.general.clearContents()
        },
        setString: @escaping (String) -> Bool = { string in
            NSPasteboard.general.setString(string, forType: .string)
        },
        postPasteShortcut: @escaping () -> Bool = {
            guard let source = CGEventSource(stateID: .combinedSessionState),
                  let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
                return false
            }

            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            return true
        },
        restoreString: @escaping (String?) -> Void = { string in
            NSPasteboard.general.clearContents()
            if let string {
                _ = NSPasteboard.general.setString(string, forType: .string)
            }
        },
        restoreDelayNanoseconds: UInt64 = 150_000_000
    ) {
        self.accessibilityStatus = accessibilityStatus
        self.currentString = currentString
        self.clearContents = clearContents
        self.setString = setString
        self.postPasteShortcut = postPasteShortcut
        self.restoreString = restoreString
        self.restoreDelayNanoseconds = restoreDelayNanoseconds
    }

    func deliver(_ transcript: String) async throws {
        guard accessibilityStatus() == .authorized else {
            throw ClipboardPasteTranscriptOutputError.accessibilityDenied
        }

        let previousString = currentString()
        clearContents()
        guard setString(transcript) else {
            throw ClipboardPasteTranscriptOutputError.pasteboardWriteFailed
        }
        guard postPasteShortcut() else {
            throw ClipboardPasteTranscriptOutputError.pasteEventCreationFailed
        }

        if restoreDelayNanoseconds == 0 {
            restoreString(previousString)
        } else {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: restoreDelayNanoseconds)
                restoreString(previousString)
            }
        }
    }
}
