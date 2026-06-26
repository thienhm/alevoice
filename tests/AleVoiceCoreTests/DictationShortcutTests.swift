import XCTest
@testable import AleVoiceCore

final class DictationShortcutTests: XCTestCase {
    func test_initRejectsShortcutWithoutModifier() throws {
        XCTAssertThrowsError(
            try DictationShortcut(modifiers: [], primaryKey: .space)
        ) { error in
            XCTAssertEqual(error as? DictationShortcutError, .missingModifier)
        }
    }

    func test_initAcceptsModifierOnlyShortcut() throws {
        let shortcut = try DictationShortcut(modifiers: [.control], primaryKey: nil)

        XCTAssertEqual(shortcut.displayText, "Control")
    }

    func test_initAcceptsModifierAndPrimaryKeyShortcut() throws {
        let shortcut = try DictationShortcut(modifiers: [.control, .shift], primaryKey: .space)

        XCTAssertEqual(shortcut.displayText, "Control+Shift+Space")
    }

    func test_supportedPrimaryKeyRejectsUnknownCodes() {
        XCTAssertNil(DictationShortcut.PrimaryKey(keyCode: 255))
    }
}
