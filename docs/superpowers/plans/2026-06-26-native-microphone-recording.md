# Native Microphone Recording Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let native debug shell record microphone audio and transcribe captured clips through existing FunASR-first core.

**Architecture:** Add small `AudioRecording` boundary in `AleVoiceCore` that owns AVFoundation capture and temp-file lifecycle, then extend debug view model/UI to drive start/stop/transcribe state without changing engine-selection or language-mode rules. Keep recorder isolated from future hotkey, overlay, and paste layers.

**Tech Stack:** Swift 6, AVFoundation, SwiftUI, XCTest, existing `AleVoiceCore` and `AleVoiceAppUI` targets.

---

## Acceptance Criteria Map

- AC1: add reusable recorder service that produces engine-ready WAV file.
- AC2: wire debug UI start/stop flow into existing coordinator.
- AC3: surface permission/capture/empty-recording failures in tests and UI.
- AC4: prove target Mac can transcribe microphone-captured audio.
- AC5: keep hotkey/overlay/paste work out of recorder boundary.

## Tasks

- [ ] Task 1: write failing recorder + view-model tests for start/stop state, produced file URL, and surfaced errors.
- [ ] Task 2: implement recorder boundary in `Sources/AleVoiceCore` with temp-file output and clear error mapping.
- [ ] Task 3: extend `TranscriptionDebugViewModel` and `ContentView` with record/stop/transcribe flow while keeping sample button.
- [ ] Task 4: update story + validation docs with exact proof, then refresh durable story status.
