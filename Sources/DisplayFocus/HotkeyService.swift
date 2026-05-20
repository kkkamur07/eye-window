import Carbon
import DisplayFocusCore
import Foundation

/// Global hotkeys (⌘⌥1, ⌘⌥2). ⌘1/⌘2 conflicts with Arc; ⌥1 alone types ¡™£.
@MainActor
final class HotkeyService {
    enum Action: UInt32 {
        case focusDisplay1 = 1
        case focusDisplay2 = 2
    }

    private static let bindings: [(keyCode: UInt32, action: Action)] = [
        (UInt32(kVK_ANSI_1), .focusDisplay1),
        (UInt32(kVK_ANSI_2), .focusDisplay2),
    ]

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlerRef: EventHandlerRef?
    private let handlers: [Action: () -> Void]
    private static let signature = OSType(0x44664663) // 'DFoc'
    private static let modifiers = UInt32(cmdKey | optionKey)

    init(handlers: [Action: () -> Void]) {
        self.handlers = handlers
    }

    func start() {
        guard handlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyCallback,
            1,
            &eventType,
            userData,
            &handlerRef
        )

        for binding in Self.bindings {
            register(keyCode: binding.keyCode, action: binding.action)
        }
    }

    func stop() {
        for ref in hotKeyRefs.values { UnregisterEventHotKey(ref) }
        hotKeyRefs.removeAll()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    private func register(keyCode: UInt32, action: Action) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: action.rawValue)
        let status = RegisterEventHotKey(keyCode, Self.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            Log.info("hotkey register failed action=\(action.rawValue) err=\(status)")
            return
        }
        hotKeyRefs[action.rawValue] = ref
    }

    fileprivate func handleHotKey(id: UInt32) {
        guard let action = Action(rawValue: id) else { return }
        handlers[action]?()
    }
}

private func hotKeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ theEvent: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let theEvent, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    guard GetEventParameter(
        theEvent,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    ) == noErr else { return OSStatus(eventNotHandledErr) }

    let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in service.handleHotKey(id: hotKeyID.id) }
    return noErr
}
