import XCTest
@testable import AleVoiceCore

final class GlobalHotkeyStateMachineTests: XCTestCase {
    func test_modifierAndPrimaryKeyActivateOnce() throws {
        let shortcut = try DictationShortcut(modifiers: [.control], primaryKey: .space)
        var machine = GlobalHotkeyStateMachine(shortcut: shortcut)

        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .flagsChanged, keyCode: nil, modifiers: [.control])),
            []
        )
        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .keyDown, keyCode: 49, modifiers: [.control])),
            [.activated]
        )
        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .keyDown, keyCode: 49, modifiers: [.control])),
            []
        )
    }

    func test_releaseAnyRequiredInputEmitsReleasedOnce() throws {
        let shortcut = try DictationShortcut(modifiers: [.control, .shift], primaryKey: .space)
        var machine = GlobalHotkeyStateMachine(shortcut: shortcut)

        _ = machine.handle(GlobalKeyEvent(kind: .flagsChanged, keyCode: nil, modifiers: [.control, .shift]))
        _ = machine.handle(GlobalKeyEvent(kind: .keyDown, keyCode: 49, modifiers: [.control, .shift]))

        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .flagsChanged, keyCode: nil, modifiers: [.control])),
            [.released]
        )
        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .keyUp, keyCode: 49, modifiers: [.control])),
            []
        )
    }

    func test_unrelatedPrimaryKeyDoesNotReleaseActiveShortcut() throws {
        let shortcut = try DictationShortcut(modifiers: [.control], primaryKey: .space)
        var machine = GlobalHotkeyStateMachine(shortcut: shortcut)

        _ = machine.handle(GlobalKeyEvent(kind: .flagsChanged, keyCode: nil, modifiers: [.control]))
        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .keyDown, keyCode: 49, modifiers: [.control])),
            [.activated]
        )

        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .keyDown, keyCode: 0, modifiers: [.control])),
            []
        )
        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .keyUp, keyCode: 0, modifiers: [.control])),
            []
        )
        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .keyUp, keyCode: 49, modifiers: [.control])),
            [.released]
        )
        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .flagsChanged, keyCode: nil, modifiers: [])),
            []
        )
    }

    func test_modifierOnlyShortcutUsesFlagsChangedLifecycle() throws {
        let shortcut = try DictationShortcut(modifiers: [.option], primaryKey: nil)
        var machine = GlobalHotkeyStateMachine(shortcut: shortcut)

        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .flagsChanged, keyCode: nil, modifiers: [.option])),
            [.activated]
        )
        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .flagsChanged, keyCode: nil, modifiers: [])),
            [.released]
        )
    }
}
