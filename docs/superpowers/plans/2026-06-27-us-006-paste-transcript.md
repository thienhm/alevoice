# US-006 Paste Transcript Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Paste successful recording transcripts into the currently focused macOS app.

**Architecture:** Add a pure `TranscriptOutputService` in `AleVoiceCore` that validates output text and delegates delivery to an injected async closure. Add an AppKit adapter in `AleVoiceApp` that checks Accessibility trust, writes the transcript to `NSPasteboard`, posts `Cmd+V`, and restores the prior string clipboard value after a short delay. Wire `TranscriptionDebugViewModel` so only recording transcription, not sample transcription, calls the output service.

**Tech Stack:** Swift 6, XCTest, SwiftUI, AppKit, CoreGraphics, Harness CLI.

---

### Task 1: Story And Product Contract

**Files:**
- Create: `docs/stories/epics/E01-local-stt/US-006-paste-transcript-into-focused-app.md`
- Create: `docs/validation/us-006-paste-transcript-into-focused-app.md`
- Modify: `docs/product/local-dictation-workflow.md`

- [x] **Step 1: Create US-006 story and validation report**

Record acceptance criteria for paste output, Accessibility visibility, sample-transcription exclusion, and no overlay or formatting behavior.

- [x] **Step 2: Update product workflow**

Move paste from out-of-scope into the current workflow contract while leaving overlay and formatting-command normalization out of scope.

### Task 2: Transcript Output Service

**Files:**
- Create: `Sources/AleVoiceCore/TranscriptOutputService.swift`
- Create: `tests/AleVoiceCoreTests/TranscriptOutputServiceTests.swift`

- [x] **Step 1: Write failing tests**

Cover successful delivery, whitespace-only rejection, and driver failure propagation.

- [x] **Step 2: Run focused tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptOutputServiceTests`

Expected before implementation: compile failure because `TranscriptOutputService` does not exist.

- [x] **Step 3: Implement minimal service**

Add `TranscriptOutputService` with `deliver(_:)` and `TranscriptOutputError.emptyTranscript`.

- [x] **Step 4: Run focused tests again**

Expected after implementation: focused tests pass.

### Task 3: View Model Integration

**Files:**
- Modify: `Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift`
- Modify: `tests/AleVoiceAppUITests/TranscriptionDebugViewModelTests.swift`
- Modify: `tests/AleVoiceAppUITests/GlobalHotkeyDebugViewModelTests.swift`

- [x] **Step 1: Write failing integration tests**

Cover recording transcription calls `deliverTranscript`, sample transcription does not call it, output failure leaves transcript visible and shows error, and global hotkey release uses the same output path.

- [x] **Step 2: Run focused UI tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptionDebugViewModelTests --filter GlobalHotkeyDebugViewModelTests`

Expected before implementation: compile failure because `deliverTranscript` injection does not exist.

- [x] **Step 3: Implement minimal view-model wiring**

Inject `deliverTranscript`, call it after successful recording transcription, and preserve transcript/latency if output fails.

- [x] **Step 4: Run focused UI tests again**

Expected after implementation: focused tests pass.

### Task 4: AppKit Paste Adapter And Accessibility UI

**Files:**
- Create: `Sources/AleVoiceApp/AccessibilityPermission.swift`
- Create: `Sources/AleVoiceApp/ClipboardPasteTranscriptOutput.swift`
- Modify: `Sources/AleVoiceApp/AleVoiceApp.swift`
- Modify: `Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift`
- Modify: `Sources/AleVoiceAppUI/ContentView.swift`

- [x] **Step 1: Write failing app adapter tests where practical**

Use injectable closures for Accessibility status and paste driver behavior. Avoid posting real key events in automated tests.

- [x] **Step 2: Implement Accessibility status and request closures**

Expose UI text `Accessibility: <status>` with refresh and request buttons.

- [x] **Step 3: Implement clipboard-backed paste adapter**

Save current plain string, clear and set transcript, post `Cmd+V`, and restore prior plain string after a short delay.

- [x] **Step 4: Wire app**

Pass Accessibility closures and `TranscriptOutputService(deliver: pasteOutput.deliver)` into `TranscriptionDebugViewModel`.

### Task 5: Validation And Harness

**Files:**
- Modify: `docs/stories/epics/E01-local-stt/US-006-paste-transcript-into-focused-app.md`
- Modify: `docs/validation/us-006-paste-transcript-into-focused-app.md`
- Modify: `docs/product/local-dictation-workflow.md`

- [x] **Step 1: Run full Swift suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`

- [x] **Step 2: Run app smoke if feasible**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app`

- [x] **Step 3: Update story, validation report, and durable matrix**

Use `scripts/bin/harness-cli story add` or `story update` with proof flags and evidence.

- [x] **Step 4: Record trace**

Use `scripts/bin/harness-cli trace` with read files, changed files, validation, and friction.

## Self-Review

- Spec coverage: the plan covers paste output, Accessibility visibility, sample exclusion, error surfacing, and clipboard limits.
- Placeholder scan: no placeholder task remains; platform manual proof remains explicitly marked as validation work.
- Type consistency: `TranscriptOutputService`, `deliverTranscript`, and Accessibility status names are consistent across tasks.
