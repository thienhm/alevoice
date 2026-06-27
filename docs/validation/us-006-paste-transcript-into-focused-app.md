# US-006 Validation Report

## Summary

Validation report for pasting successful dictation transcripts into the
currently focused macOS app.

## Commands Run

| Command | Result |
| --- | --- |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptOutputServiceTests` | Failed before implementation because `TranscriptOutputService` did not exist, then passed after adding transcript output validation and delivery behavior. |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptionDebugViewModelTests --filter GlobalHotkeyDebugViewModelTests` | Failed before implementation because `deliverTranscript` and Accessibility status hooks did not exist, then passed after view-model wiring and UI permission status support were added. |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter ClipboardPasteTranscriptOutputTests` | Failed before implementation because `ClipboardPasteTranscriptOutput` did not exist, then passed after adding clipboard-backed paste adapter coverage. |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test` | Passed on 2026-06-27 with 78 tests and 0 failures. |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app --print-bundle-path` | Built, ad-hoc signed, and reported `/Users/alex/workspace/Projects/alevoice/.build/debug/AleVoiceApp.app`. |
| `rtk scripts/bin/harness-cli story verify US-006` | Passed; ran `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` with 78 tests and 0 failures. |

## Expected Results

| Check | Expected proof |
| --- | --- |
| Unit | Transcript output service and clipboard adapter tests pass. |
| Integration | Debug view model calls paste output after successful recording transcription and skips paste for sample or failure paths. |
| E2E | Not required for this slice; overlay and formatting remain out of scope. |
| Platform | Manual local proof in a focused text input after Accessibility approval. Pending in this run. |
| Release | Commands, observed proof, and clipboard limitations are recorded here. |

## Platform Proof

Automated proof completed on 2026-06-27:

- `TranscriptOutputService` rejects whitespace-only output but preserves non-empty transcript text verbatim.
- `ClipboardPasteTranscriptOutput` requires Accessibility authorization before side effects, writes transcript to clipboard, posts paste, and restores the prior plain-string clipboard value in tests through injected seams.
- `TranscriptionDebugViewModel` now delivers only successful recording transcription through the output path.
- Sample transcription remains display-only.
- Output-delivery failure leaves transcript and latency visible while surfacing the error.

Manual focused-text-field proof is still pending for this slice.

## Known Limits

- Overlay UI is out of scope.
- Formatting-command normalization is out of scope.
- Clipboard preservation is best-effort for plain string contents in this
  slice.
- Manual validation in TextEdit or another focused text field has not yet been
  rerun after this implementation.
