# Menu Bar Feedback Without Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace floating overlay feedback with a red menu bar recording indicator and copyable last-error affordances.

**Architecture:** Keep `DictationSessionState` as the source of truth. `MenuBarController` translates session state into `MenuBarShellModel` presentation state, and `MenuBarMenuView` owns menu actions such as copying the current error. `AleVoiceApp` stops rendering the overlay on session-state changes.

**Tech Stack:** Swift, SwiftUI `MenuBarExtra`, AppKit `NSPasteboard`, XCTest, Harness CLI.

---

## File Map

- Modify `Sources/AleVoiceApp/MenuBarShellModel.swift`: add icon/tint state used by `MenuBarExtra`.
- Modify `Sources/AleVoiceApp/MenuBarController.swift`: render title plus recording indicator state.
- Modify `Sources/AleVoiceApp/AleVoiceApp.swift`: bind menu icon from `MenuBarShellModel`; remove overlay render call.
- Modify `Sources/AleVoiceApp/MenuBarMenuView.swift`: add `Copy Last Error` action.
- Modify `Sources/AleVoiceAppUI/ContentView.swift`: make error text selectable.
- Modify `Sources/AleVoiceApp/OverlayWindowController.swift`: make render inert or remove show path.
- Modify `tests/AleVoiceAppTests/MenuBarControllerTests.swift`: assert recording indicator mapping.
- Modify `tests/AleVoiceAppTests/OverlayWindowControllerTests.swift`: assert overlay never shows.
- Add `tests/AleVoiceAppTests/MenuBarMenuViewTests.swift` for the menu error helper.
- Update docs/story evidence after verification.

## Task 1: Menu Bar Presentation State

**Files:**
- Modify: `Sources/AleVoiceApp/MenuBarShellModel.swift`
- Modify: `Sources/AleVoiceApp/MenuBarController.swift`
- Test: `tests/AleVoiceAppTests/MenuBarControllerTests.swift`

- [ ] **Step 1: Replace menu bar controller tests with failing state assertions**

Use the test file below:

```swift
import XCTest
@testable import AleVoiceApp
import AleVoiceCore

final class MenuBarControllerTests: XCTestCase {
    @MainActor
    func test_recordingStateUsesRedRecordingIndicator() {
        let model = MenuBarShellModel()
        let controller = MenuBarController(
            statusItem: nil,
            updateShell: { presentation in
                model.title = presentation.title
                model.isRecordingIndicatorVisible = presentation.isRecordingIndicatorVisible
            }
        )

        controller.render(
            state: .recording,
            microphoneText: "Microphone permission: authorized",
            accessibilityText: "Accessibility: authorized",
            inputMonitoringText: "Input Monitoring: authorized",
            shortcutText: "Dictation shortcut: Control+Space"
        )

        XCTAssertEqual(model.title, "AleVoice • Recording")
        XCTAssertTrue(model.isRecordingIndicatorVisible)
    }

    @MainActor
    func test_nonRecordingStatesUseDefaultIndicator() {
        let states: [DictationSessionState] = [
            .idle,
            .processing,
            .success("done"),
            .error("failed")
        ]

        for state in states {
            let model = MenuBarShellModel()
            let controller = MenuBarController(
                statusItem: nil,
                updateShell: { presentation in
                    model.title = presentation.title
                    model.isRecordingIndicatorVisible = presentation.isRecordingIndicatorVisible
                }
            )

            controller.render(
                state: state,
                microphoneText: "Microphone permission: authorized",
                accessibilityText: "Accessibility: authorized",
                inputMonitoringText: "Input Monitoring: authorized",
                shortcutText: "Dictation shortcut: Control+Space"
            )

            XCTAssertFalse(model.isRecordingIndicatorVisible, "Expected default icon for \(state)")
        }
    }
}
```

- [ ] **Step 2: Run failing menu bar tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter MenuBarControllerTests
```

Expected: compile fails because `MenuBarPresentation`, `updateShell`, and `isRecordingIndicatorVisible` do not exist.

- [ ] **Step 3: Implement presentation model**

Update `Sources/AleVoiceApp/MenuBarShellModel.swift`:

```swift
import Foundation

@MainActor
final class MenuBarShellModel: ObservableObject {
    @Published var title: String
    @Published var isRecordingIndicatorVisible: Bool

    init(
        title: String = "AleVoice",
        isRecordingIndicatorVisible: Bool = false
    ) {
        self.title = title
        self.isRecordingIndicatorVisible = isRecordingIndicatorVisible
    }
}
```

Update `Sources/AleVoiceApp/MenuBarController.swift`:

```swift
import AleVoiceCore
import AppKit
import Foundation

struct MenuBarPresentation: Equatable {
    let title: String
    let isRecordingIndicatorVisible: Bool
}

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem?
    private let updateShell: (MenuBarPresentation) -> Void

    init(
        statusItem: NSStatusItem? = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
        updateShell: ((MenuBarPresentation) -> Void)? = nil
    ) {
        self.statusItem = statusItem
        self.updateShell = updateShell ?? { [weak statusItem] presentation in
            statusItem?.button?.title = presentation.title
            statusItem?.button?.contentTintColor = presentation.isRecordingIndicatorVisible ? .systemRed : nil
        }
    }

    func render(
        state: DictationSessionState,
        microphoneText: String,
        accessibilityText: String,
        inputMonitoringText: String,
        shortcutText: String
    ) {
        updateShell(Self.presentation(for: state))
    }

    static func presentation(for state: DictationSessionState) -> MenuBarPresentation {
        switch state {
        case .idle:
            return MenuBarPresentation(title: "AleVoice", isRecordingIndicatorVisible: false)
        case .recording:
            return MenuBarPresentation(title: "AleVoice • Recording", isRecordingIndicatorVisible: true)
        case .processing:
            return MenuBarPresentation(title: "AleVoice • Processing", isRecordingIndicatorVisible: false)
        case .success:
            return MenuBarPresentation(title: "AleVoice • Ready", isRecordingIndicatorVisible: false)
        case .error:
            return MenuBarPresentation(title: "AleVoice • Error", isRecordingIndicatorVisible: false)
        }
    }
}
```

- [ ] **Step 4: Run menu bar tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter MenuBarControllerTests
```

Expected: `MenuBarControllerTests` pass.

## Task 2: Render Red Icon In `MenuBarExtra`

**Files:**
- Modify: `Sources/AleVoiceApp/AleVoiceApp.swift`
- Test: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter MenuBarControllerTests`

- [ ] **Step 1: Update app shell callback**

In `AleVoiceApp.init`, replace the controller construction with:

```swift
let menuBarController = MenuBarController(
    statusItem: nil,
    updateShell: { presentation in
        shellModel.title = presentation.title
        shellModel.isRecordingIndicatorVisible = presentation.isRecordingIndicatorVisible
    }
)
```

- [ ] **Step 2: Update `MenuBarExtra` label**

Replace:

```swift
MenuBarExtra(shellModel.title, systemImage: "waveform") {
    MenuBarMenuView(viewModel: viewModel)
}
```

with:

```swift
MenuBarExtra {
    MenuBarMenuView(viewModel: viewModel)
} label: {
    Label {
        Text(shellModel.title)
    } icon: {
        Image(systemName: "waveform")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(shellModel.isRecordingIndicatorVisible ? Color.red : Color.primary)
    }
}
```

- [ ] **Step 3: Run compile/tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter MenuBarControllerTests
```

Expected: pass.

## Task 3: Disable Overlay Rendering

**Files:**
- Modify: `Sources/AleVoiceApp/AleVoiceApp.swift`
- Modify: `Sources/AleVoiceApp/OverlayWindowController.swift`
- Test: `tests/AleVoiceAppTests/OverlayWindowControllerTests.swift`

- [ ] **Step 1: Replace overlay tests with failing no-show assertions**

Use:

```swift
import XCTest
@testable import AleVoiceApp
import AleVoiceCore

final class OverlayWindowControllerTests: XCTestCase {
    @MainActor
    func test_renderNeverShowsOverlayForAnyState() {
        let states: [DictationSessionState] = [
            .idle,
            .recording,
            .processing,
            .success("done"),
            .error("failed")
        ]
        var showCount = 0
        var hideCount = 0
        let controller = OverlayWindowController(
            showWindow: { showCount += 1 },
            hideWindow: { hideCount += 1 }
        )

        for state in states {
            controller.render(state: state)
        }

        XCTAssertEqual(showCount, 0)
        XCTAssertEqual(hideCount, states.count)
    }
}
```

- [ ] **Step 2: Run failing overlay test**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter OverlayWindowControllerTests
```

Expected: fail because recording/processing/success/error call `showWindow`.

- [ ] **Step 3: Make overlay controller inert**

Update `OverlayWindowController.render`:

```swift
func render(state: DictationSessionState) {
    hideWindowAction()
    panel?.orderOut(nil)
}
```

Leave `showPanel`, `makePanel`, and `position` in place for now unless the compiler flags them as unused warnings. Swift permits unused private methods.

- [ ] **Step 4: Stop calling overlay from app flow**

In `AleVoiceApp.init`, remove this line from the `viewModel.$sessionState.sink` block:

```swift
overlayController.render(state: state)
```

Remove the `overlayController` stored property and local initialization from
`AleVoiceApp`, because the app flow no longer uses it.

- [ ] **Step 5: Run overlay tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter OverlayWindowControllerTests
```

Expected: pass.

## Task 4: Copyable Error In Menu And Settings

**Files:**
- Modify: `Sources/AleVoiceApp/MenuBarMenuView.swift`
- Modify: `Sources/AleVoiceAppUI/ContentView.swift`
- Test: `tests/AleVoiceAppTests/MenuBarMenuViewTests.swift`
- Test: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`

- [ ] **Step 1: Add failing menu error helper tests**

Create `tests/AleVoiceAppTests/MenuBarMenuViewTests.swift`:

```swift
import XCTest
@testable import AleVoiceApp
import AleVoiceCore

final class MenuBarMenuViewTests: XCTestCase {
    @MainActor
    func test_lastErrorMessageReturnsErrorPayload() {
        XCTAssertEqual(lastErrorMessage(from: .error("paste failed")), "paste failed")
    }

    @MainActor
    func test_lastErrorMessageReturnsNilForNonErrorStates() {
        XCTAssertNil(lastErrorMessage(from: .idle))
        XCTAssertNil(lastErrorMessage(from: .recording))
        XCTAssertNil(lastErrorMessage(from: .processing))
        XCTAssertNil(lastErrorMessage(from: .success("done")))
    }
}
```

- [ ] **Step 2: Run failing menu helper tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter MenuBarMenuViewTests
```

Expected: compile fails because `lastErrorMessage(from:)` does not exist.

- [ ] **Step 3: Add pure error extraction helper**

At the bottom of `MenuBarMenuView.swift`, add:

```swift
@MainActor
func lastErrorMessage(from state: DictationSessionState) -> String? {
    guard case .error(let message) = state else {
        return nil
    }
    return message
}
```

- [ ] **Step 4: Add menu copy action**

In `MenuBarMenuView.body`, after the status/permission `VStack` and before `Divider()`, add:

```swift
if let errorMessage = lastErrorMessage(from: viewModel.sessionState) {
    Button("Copy Last Error") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(errorMessage, forType: .string)
    }
}
```

- [ ] **Step 5: Make settings error selectable**

In `ContentView.swift`, change:

```swift
if let errorText = viewModel.errorText {
    Text(errorText)
        .foregroundStyle(.red)
}
```

to:

```swift
if let errorText = viewModel.errorText {
    Text(errorText)
        .foregroundStyle(.red)
        .textSelection(.enabled)
}
```

- [ ] **Step 6: Run menu helper tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter MenuBarMenuViewTests
```

Expected: `MenuBarMenuViewTests` pass.

- [ ] **Step 7: Run full Swift tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test
```

Expected: all tests pass.

## Task 5: Product And Story Docs

**Files:**
- Modify: `docs/product/local-dictation-workflow.md`
- Modify: `docs/stories/epics/E01-local-stt/US-007-menu-bar-mvp/overview.md`
- Modify: `docs/stories/epics/E01-local-stt/US-007-menu-bar-mvp/design.md`
- Modify: `docs/stories/epics/E01-local-stt/US-007-menu-bar-mvp/validation.md`

- [ ] **Step 1: Update product contract**

In `docs/product/local-dictation-workflow.md`, replace the overlay bullet:

```markdown
- App shows small overlay feedback while recording, processing, succeeding, or
  failing.
```

with:

```markdown
- App indicates active recording by turning the menu bar waveform icon red while
  the configured shortcut is held.
- App does not show floating overlay feedback for recording, processing,
  success, or error states.
- Error text remains copyable from the settings/debug window and from the menu
  bar error action.
```

- [ ] **Step 2: Update US-007 docs**

Change US-007 overview/design/validation references from overlay feedback to
menu bar icon feedback:

```markdown
- red menu bar waveform icon while recording
- no floating overlay for recording, processing, success, or error
- copyable last-error action from the menu and selectable settings error text
```

In validation, replace overlay platform proof with:

```markdown
- Hold configured shortcut and confirm the waveform icon turns red while
  recording.
- Release shortcut and confirm the waveform icon returns to default styling.
- Confirm no floating overlay appears for recording, processing, success, or
  error states.
- Trigger an error and confirm it can be copied from Settings or `Copy Last
  Error`.
```

- [ ] **Step 3: Update durable story evidence after tests/platform attempt**

Run after validation:

```bash
rtk ./scripts/bin/harness-cli story update --id US-007 --unit 1 --integration 1 --e2e 0 --platform 0 --evidence "2026-06-27: Replaced overlay feedback with red menu bar waveform recording indicator and copyable last-error affordances. Swift tests passed. Platform icon/paste proof remains pending local TCC approval."
```

Keep `platform 0` unless local TCC approval is completed and live platform proof is observed.

## Task 6: Harness Trace And Final Verification

**Files:**
- Read: `docs/TRACE_SPEC.md`
- Durable: Harness trace row

- [ ] **Step 1: Run final automated proof**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app --print-bundle-path
rtk ./scripts/bin/harness-cli story verify US-007
```

Expected: tests pass, app bundle path prints, story verify passes.

- [ ] **Step 2: Record trace**

Use a normal-lane standard trace:

```bash
rtk ./scripts/bin/harness-cli trace \
  --summary "Replaced overlay feedback with red menu bar recording indicator and copyable error affordances" \
  --intake 43 \
  --story US-007 \
  --agent codex \
  --outcome completed \
  --actions "read approved spec,wrote failing tests,implemented menu bar recording indicator,disabled overlay rendering,added copy last error,updated docs,ran swift test" \
  --read "docs/superpowers/specs/2026-06-27-menu-bar-feedback-no-overlay-design.md,Sources/AleVoiceApp/AleVoiceApp.swift,Sources/AleVoiceApp/MenuBarController.swift,Sources/AleVoiceApp/MenuBarMenuView.swift,Sources/AleVoiceApp/OverlayWindowController.swift,Sources/AleVoiceAppUI/ContentView.swift,docs/TRACE_SPEC.md" \
  --changed "Sources/AleVoiceApp/MenuBarShellModel.swift,Sources/AleVoiceApp/MenuBarController.swift,Sources/AleVoiceApp/AleVoiceApp.swift,Sources/AleVoiceApp/MenuBarMenuView.swift,Sources/AleVoiceApp/OverlayWindowController.swift,Sources/AleVoiceAppUI/ContentView.swift,tests/AleVoiceAppTests/MenuBarControllerTests.swift,tests/AleVoiceAppTests/OverlayWindowControllerTests.swift,docs/product/local-dictation-workflow.md,docs/stories/epics/E01-local-stt/US-007-menu-bar-mvp/overview.md,docs/stories/epics/E01-local-stt/US-007-menu-bar-mvp/design.md,docs/stories/epics/E01-local-stt/US-007-menu-bar-mvp/validation.md" \
  --friction "none"
```

- [ ] **Step 3: Final status**

Run:

```bash
rtk git status --short
rtk ./scripts/bin/harness-cli query matrix --numeric
```

Expected: only intended files changed; US-007 unit/integration remain `1`, platform remains `0` unless local platform proof was completed.
