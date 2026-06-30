# Remove Installed Model CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an interactive `AleVoiceCLI remove` command that removes an installed engine from config and deletes its managed runtime/model directory.

**Architecture:** Keep prompting in `CLIProgram` and put config/filesystem mutation in a small `InstalledModelRemover` service. Reuse `SpeechEngineSettings` for config parsing and saving.

**Tech Stack:** SwiftPM, XCTest, AleVoiceCLI, AleVoiceCore config models.

---

### Task 1: Add Remover Service With Tests

**Files:**
- Create: `Sources/AleVoiceCLI/InstalledModelRemover.swift`
- Modify: `tests/AleVoiceCoreTests/TranscriptionCoordinatorTests.swift`

- [ ] Write failing tests for confirmed removal, selected fallback, cancel/no-op, and last-engine rejection.
- [ ] Run targeted Swift tests and confirm failure because `InstalledModelRemover` is undefined.
- [ ] Implement `InstalledModelRemover.remove(engineID:configURL:installRoot:)`.
- [ ] Run targeted Swift tests and confirm pass.

### Task 2: Wire Interactive CLI Command

**Files:**
- Modify: `Sources/AleVoiceCLI/CLIProgram.swift`
- Modify: `tests/AleVoiceCoreTests/TranscriptionCoordinatorTests.swift`

- [ ] Write failing tests for help text, list output, invalid selection, cancel, and confirm.
- [ ] Run targeted Swift tests and confirm failure because `remove` is unknown.
- [ ] Add `remove` parser branch, context dependencies, prompt readers, and output.
- [ ] Run targeted Swift tests and confirm pass.

### Task 3: Update Docs And Harness

**Files:**
- Modify: `README.md`
- Modify: `docs/product/local-dictation-workflow.md`
- Create: `docs/stories/epics/E01-local-stt/US-010-remove-installed-model-cli.md`

- [ ] Document `swift run AleVoiceCLI remove`.
- [ ] Add story acceptance criteria and validation proof.
- [ ] Run full Swift test suite.
- [ ] Update Harness story proof and trace.

### Self-Review

- Spec coverage: interactive list, confirmation, config mutation, filesystem delete, fallback selection, last-engine protection, docs, tests.
- Placeholder scan: no deferred requirements.
- Type consistency: service/result names match the intended Swift implementation.
