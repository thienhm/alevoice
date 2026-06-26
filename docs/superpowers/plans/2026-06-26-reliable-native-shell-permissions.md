# Reliable Native Shell And Permissions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the native macOS debug shell launch reliably from a local command and show microphone permission state without changing recorder/transcription behavior.

**Architecture:** Keep `AleVoiceApp` as a thin SwiftUI shell. Add explicit microphone permission status as a recorder query, surface it in the existing debug view model and UI, and add a scriptable local app-bundle launcher for platform proof instead of relying on repeated raw SwiftPM executable launches.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, XCTest, shell launch script, Harness story/validation docs.

---

## Acceptance Criteria

- App launches consistently as a native macOS debug shell from local command.
- Microphone permission state is detectable and shown in UI.
- Recorder start/stop can be validated with real mic path or documented blocker.
- US-003 recorder/transcription behavior remains unchanged.
- No hotkey, overlay, paste, or formatting work in this slice.

## Files

- Modify: `Sources/AleVoiceCore/AudioRecorder.swift`
- Modify: `Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift`
- Modify: `Sources/AleVoiceAppUI/ContentView.swift`
- Modify: `Sources/AleVoiceApp/AleVoiceApp.swift`
- Modify: `tests/AleVoiceCoreTests/AudioRecorderTests.swift`
- Modify: `tests/AleVoiceAppUITests/TranscriptionDebugViewModelTests.swift`
- Create: `scripts/run-alevoice-app`
- Create: `docs/stories/epics/E01-local-stt/US-004-reliable-native-app-shell-and-permissions.md`
- Create: `docs/validation/us-004-reliable-native-app-shell-and-permissions.md`

## Tasks

### Task 1: Permission State Query

- [ ] Add a failing core test that a fake driver status of `denied` maps to a public microphone permission status.
- [ ] Add `MicrophonePermissionStatus` and `microphonePermissionStatus()` to `AudioRecordingDriver`.
- [ ] Implement AVFoundation mapping for `.authorized`, `.notDetermined`, `.denied`, `.restricted`, and unknown defaults.
- [ ] Keep `start()` behavior unchanged by still requesting access only through `requestRecordPermission()`.
- [ ] Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter AudioRecorderTests`.

### Task 2: UI State Surface

- [ ] Add a failing app UI test for initial permission refresh text.
- [ ] Add a failing app UI test for denied permission text after refresh.
- [ ] Inject permission-status closure into `TranscriptionDebugViewModel`.
- [ ] Surface `permissionStatusText` and refresh it on demand.
- [ ] Render permission status in `ContentView`.
- [ ] Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter TranscriptionDebugViewModelTests`.

### Task 3: Stable Local App Launcher

- [ ] Add a failing script smoke check for `scripts/run-alevoice-app --print-bundle-path` after script creation.
- [ ] Create `scripts/run-alevoice-app` that builds `AleVoiceApp`, assembles a minimal `.app` bundle under `.build/debug/AleVoiceApp.app`, writes `Info.plist`, and opens it with `open -n`.
- [ ] Use `CFBundleExecutable` pointing at the built `AleVoiceApp` binary and include `NSMicrophoneUsageDescription`.
- [ ] Do not add hotkey, overlay, paste, or formatting behavior.
- [ ] Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/run-alevoice-app --print-bundle-path`.

### Task 4: Harness Docs And Verification

- [ ] Add US-004 story packet with acceptance criteria and validation ladder.
- [ ] Add US-004 validation report with exact commands and platform proof or blocker.
- [ ] Add or update durable US-004 story row.
- [ ] Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.
- [ ] Run `.venv/bin/python -m pytest tests/benchmarks -v`.
- [ ] Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto`.
- [ ] Run `./scripts/bin/harness-cli story verify US-004`.
