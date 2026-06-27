import AleVoiceCore
import AppKit
import CoreGraphics
import Foundation

@MainActor
final class QuartzHotkeyMonitor {
    var onTransition: (@Sendable (GlobalHotkeyTransition) -> Void)?

    private var shortcut: DictationShortcut?
    private var stateMachine: GlobalHotkeyStateMachine?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retainedUserInfo: UnsafeMutableRawPointer?

    func updateShortcut(_ shortcut: DictationShortcut?) {
        self.shortcut = shortcut
        stateMachine = shortcut.map(GlobalHotkeyStateMachine.init)
    }

    func start() {
        guard eventTap == nil else {
            return
        }

        stateMachine = shortcut.map(GlobalHotkeyStateMachine.init)

        let eventMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue) |
            (CGEventMask(1) << CGEventType.keyUp.rawValue) |
            (CGEventMask(1) << CGEventType.flagsChanged.rawValue)

        let retainedUserInfo = Unmanaged.passRetained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<QuartzHotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            monitor.processTapCallback(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: retainedUserInfo
        ) else {
            Unmanaged<QuartzHotkeyMonitor>.fromOpaque(retainedUserInfo).release()
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let source else {
            Self.teardown(eventTap: tap, runLoopSource: nil, retainedUserInfo: retainedUserInfo)
            return
        }

        eventTap = tap
        runLoopSource = source
        self.retainedUserInfo = retainedUserInfo

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        Self.teardown(
            eventTap: eventTap,
            runLoopSource: runLoopSource,
            retainedUserInfo: retainedUserInfo
        )
        eventTap = nil
        runLoopSource = nil
        retainedUserInfo = nil
        stateMachine = nil
    }

    func handle(type: CGEventType, event: CGEvent) {
        guard let keyEvent = Self.globalKeyEvent(for: type, event: event) else {
            return
        }

        handle(keyEvent)
    }

    private func handle(_ keyEvent: GlobalKeyEvent) {
        guard shortcut != nil, var stateMachine else {
            return
        }

        let transitions = stateMachine.handle(keyEvent)
        self.stateMachine = stateMachine

        for transition in transitions {
            onTransition?(transition)
        }
    }

    nonisolated private func processTapCallback(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Task { @MainActor [weak self] in
                if let tap = self?.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return
        }

        guard let keyEvent = Self.globalKeyEvent(for: type, event: event) else {
            return
        }

        Task { @MainActor [weak self] in
            self?.handle(keyEvent)
        }
    }

    nonisolated private static func globalKeyEvent(for type: CGEventType, event: CGEvent) -> GlobalKeyEvent? {
        let kind: GlobalKeyEvent.Kind
        switch type {
        case .keyDown:
            kind = .keyDown
        case .keyUp:
            kind = .keyUp
        case .flagsChanged:
            kind = .flagsChanged
        default:
            return nil
        }

        let keyCode: UInt16? = if kind == .flagsChanged {
            nil
        } else {
            UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        }

        return GlobalKeyEvent(
            kind: kind,
            keyCode: keyCode,
            modifiers: DictationShortcut.ModifierSet(cgEventFlags: event.flags)
        )
    }

    nonisolated private static func teardown(
        eventTap: CFMachPort?,
        runLoopSource: CFRunLoopSource?,
        retainedUserInfo: UnsafeMutableRawPointer?
    ) {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        if let retainedUserInfo {
            Unmanaged<QuartzHotkeyMonitor>.fromOpaque(retainedUserInfo).release()
        }
    }
}

@MainActor
final class QuartzShortcutCaptureController {
    private var localMonitor: Any?
    private var continuation: CheckedContinuation<Result<DictationShortcut, DictationShortcutError>, Never>?
    private var modifierCandidate: DictationShortcut.ModifierSet = []

    func captureShortcut() async -> Result<DictationShortcut, DictationShortcutError> {
        finishCapture(.failure(.missingModifier))

        modifierCandidate = []

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.localMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.flagsChanged, .keyDown]
            ) { [weak self] event in
                self?.handleCapturedEvent(event) ?? event
            }
        }
    }

    private func handleCapturedEvent(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .flagsChanged:
            let modifiers = DictationShortcut.ModifierSet(nsEventModifiers: event.modifierFlags)
            if modifiers.isEmpty {
                if !modifierCandidate.isEmpty {
                    finishCapture(makeShortcutResult(modifiers: modifierCandidate, primaryKey: nil))
                    return nil
                }
            } else if modifiers.rawValue > modifierCandidate.rawValue || modifierCandidate.isSubset(of: modifiers) {
                modifierCandidate = modifiers
            }

            return nil
        case .keyDown:
            let modifiers = DictationShortcut.ModifierSet(nsEventModifiers: event.modifierFlags)
            let primaryKey = DictationShortcut.PrimaryKey(keyCode: UInt16(event.keyCode))
            finishCapture(makeShortcutResult(modifiers: modifiers, primaryKey: primaryKey, keyCode: UInt16(event.keyCode)))
            return nil
        default:
            return event
        }
    }

    private func makeShortcutResult(
        modifiers: DictationShortcut.ModifierSet,
        primaryKey: DictationShortcut.PrimaryKey?,
        keyCode: UInt16? = nil
    ) -> Result<DictationShortcut, DictationShortcutError> {
        if modifiers.isEmpty {
            return .failure(.missingModifier)
        }

        if let keyCode, primaryKey == nil {
            return .failure(.unsupportedPrimaryKey(keyCode))
        }

        do {
            return .success(try DictationShortcut(modifiers: modifiers, primaryKey: primaryKey))
        } catch let error as DictationShortcutError {
            return .failure(error)
        } catch {
            return .failure(.missingModifier)
        }
    }

    private func finishCapture(_ result: Result<DictationShortcut, DictationShortcutError>) {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        modifierCandidate = []

        if let continuation {
            self.continuation = nil
            continuation.resume(returning: result)
        }
    }
}

private extension DictationShortcut.ModifierSet {
    init(cgEventFlags: CGEventFlags) {
        var modifiers: Self = []
        if cgEventFlags.contains(.maskCommand) {
            modifiers.insert(.command)
        }
        if cgEventFlags.contains(.maskShift) {
            modifiers.insert(.shift)
        }
        if cgEventFlags.contains(.maskAlternate) {
            modifiers.insert(.option)
        }
        if cgEventFlags.contains(.maskControl) {
            modifiers.insert(.control)
        }
        if cgEventFlags.contains(.maskSecondaryFn) {
            modifiers.insert(.function)
        }
        self = modifiers
    }

    init(nsEventModifiers: NSEvent.ModifierFlags) {
        var modifiers: Self = []
        if nsEventModifiers.contains(.command) {
            modifiers.insert(.command)
        }
        if nsEventModifiers.contains(.shift) {
            modifiers.insert(.shift)
        }
        if nsEventModifiers.contains(.option) {
            modifiers.insert(.option)
        }
        if nsEventModifiers.contains(.control) {
            modifiers.insert(.control)
        }
        if nsEventModifiers.contains(.function) {
            modifiers.insert(.function)
        }
        self = modifiers
    }
}
