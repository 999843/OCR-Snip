import AppKit
import Carbon.HIToolbox

/// 一组全局快捷键的按键与修饰键。`modifiers` 用 Carbon 掩码，直接喂给 RegisterEventHotKey。
struct HotKeyConfig: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let displayName: String

    static let fallback = HotKeyConfig(
        keyCode: UInt32(kVK_ANSI_T),
        modifiers: UInt32(controlKey | shiftKey),
        displayName: "⌃⇧T"
    )

    /// 从按键事件构造。
    /// - Returns: 未包含 ⌃⌥⌘ 中任意一个时为 nil —— 那种组合（如单独字母、⇧+字母）
    ///   会把正常打字也一起拦下来，不能作为全局快捷键。
    init?(event: NSEvent) {
        let flags = event.modifierFlags
        guard flags.contains(.control) || flags.contains(.option) || flags.contains(.command)
        else { return nil }

        keyCode = UInt32(event.keyCode)
        modifiers = HotKeyConfig.carbonModifiers(from: flags)
        displayName = HotKeyConfig.symbols(for: flags) + HotKeyConfig.keyLabel(for: event)
    }

    fileprivate init(keyCode: UInt32, modifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName
    }

    // MARK: - 转换

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        return result
    }

    /// Apple 的修饰键显示顺序固定为 ⌃⌥⇧⌘
    private static func symbols(for flags: NSEvent.ModifierFlags) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result
    }

    /// 优先用事件自带的字符，省掉反查键盘布局；功能键等没有可打印字符的走映射表。
    private static func keyLabel(for event: NSEvent) -> String {
        if let characters = event.charactersIgnoringModifiers,
           let first = characters.unicodeScalars.first,
           CharacterSet.alphanumerics.union(.punctuationCharacters).contains(first) {
            return characters.uppercased()
        }
        return specialKeyNames[UInt32(event.keyCode)] ?? "Key\(event.keyCode)"
    }

    private static let specialKeyNames: [UInt32: String] = [
        UInt32(kVK_Space): "Space", UInt32(kVK_Return): "↩", UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Delete): "⌫", UInt32(kVK_ForwardDelete): "⌦",
        UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_Home): "↖", UInt32(kVK_End): "↘",
        UInt32(kVK_PageUp): "⇞", UInt32(kVK_PageDown): "⇟",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
    ]
}

/// UserDefaults 持久化。三个字段一起读写，缺任一就回落到默认值。
enum HotKeyStore {
    private static let keyCodeKey = "hotKey.keyCode"
    private static let modifiersKey = "hotKey.modifiers"
    private static let displayNameKey = "hotKey.displayName"

    static func load() -> HotKeyConfig {
        let defaults = UserDefaults.standard
        guard let name = defaults.string(forKey: displayNameKey),
              defaults.object(forKey: keyCodeKey) != nil
        else { return .fallback }

        return HotKeyConfig(
            keyCode: UInt32(defaults.integer(forKey: keyCodeKey)),
            modifiers: UInt32(defaults.integer(forKey: modifiersKey)),
            displayName: name
        )
    }

    static func save(_ config: HotKeyConfig) {
        let defaults = UserDefaults.standard
        defaults.set(Int(config.keyCode), forKey: keyCodeKey)
        defaults.set(Int(config.modifiers), forKey: modifiersKey)
        defaults.set(config.displayName, forKey: displayNameKey)
    }

    static func reset() {
        let defaults = UserDefaults.standard
        [keyCodeKey, modifiersKey, displayNameKey].forEach(defaults.removeObject(forKey:))
    }
}
