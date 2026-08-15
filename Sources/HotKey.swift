import AppKit
import Carbon.HIToolbox

/// Carbon 全局热键。相比 NSEvent 全局监听，它不需要「辅助功能」权限。
final class HotKey {
    private static var registry: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    private var ref: EventHotKeyRef?
    private let id: UInt32

    /// - Parameters:
    ///   - keyCode: Carbon 虚拟键码，如 `UInt32(kVK_ANSI_T)`
    ///   - modifiers: Carbon 修饰键掩码，如 `controlKey | optionKey | cmdKey`
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        HotKey.installHandlerIfNeeded()

        id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.registry[id] = action

        let hotKeyID = EventHotKeyID(signature: OSType(0x4F43_524B), id: id) // 'OCRK'
        let status = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref
        )
        guard status == noErr, ref != nil else {
            HotKey.registry[id] = nil
            return nil
        }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        HotKey.registry[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
                )
                guard status == noErr else { return status }
                HotKey.registry[hotKeyID.id]?()
                return noErr
            },
            1, &spec, nil, nil
        )
    }
}
