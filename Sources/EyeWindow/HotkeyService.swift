import Carbon
import Foundation

/// Registers Control+Option+grave as a global gaze-pause toggle.
@MainActor
final class HotkeyService {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onToggle: () -> Void

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
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

        let hotKeyID = EventHotKeyID(signature: OSType(0x477A5061), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_Grave),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    fileprivate func handleHotKey() {
        onToggle()
    }
}

private func hotKeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ theEvent: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        service.handleHotKey()
    }
    return noErr
}
