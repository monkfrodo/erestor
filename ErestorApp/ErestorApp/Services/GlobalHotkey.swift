import AppKit
import Carbon
import os

private let logger = Logger(subsystem: "org.integros.erestor", category: "GlobalHotkey")

/// Registers Cmd+Shift+E as a global hotkey to show/activate the Erestor window.
/// Uses Carbon RegisterEventHotKey which works without Accessibility permissions.
class GlobalHotkey {
    static let shared = GlobalHotkey()

    private var hotKeyRef: EventHotKeyRef?
    private var onTrigger: (() -> Void)?

    private init() {}

    func register(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger

        // Install Carbon event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))

        let handlerResult = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                GlobalHotkey.shared.onTrigger?()
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        guard handlerResult == noErr else {
            logger.error("Failed to install event handler: \(handlerResult)")
            return
        }

        // Register Cmd+Shift+E
        // Key code for 'E' is 14 (kVK_ANSI_E)
        let modifiers = UInt32(cmdKey | shiftKey)
        var hotKeyID = EventHotKeyID(signature: OSType(0x4552_5354), // "ERST"
                                      id: 1)

        let registerResult = RegisterEventHotKey(
            UInt32(kVK_ANSI_E),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerResult == noErr {
            logger.info("Global hotkey Cmd+Shift+E registered")
        } else {
            logger.error("Failed to register hotkey: \(registerResult)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            logger.info("Global hotkey unregistered")
        }
    }
}
