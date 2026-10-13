import AppKit
import Carbon.HIToolbox

private func keyEvent(
    _ keyCode: UInt16, _ chars: String, _ flags: NSEvent.ModifierFlags
) -> NSEvent? {
    NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
        windowNumber: 0, context: nil, characters: chars,
        charactersIgnoringModifiers: chars, isARepeat: false, keyCode: keyCode)
}

/// 快捷键模型：合法性判定、显示名生成、Carbon 掩码转换、UserDefaults 往返。
func testHotKeyConfig() {
    // ——— 默认值 ———
    eq(HotKeyConfig.fallback.displayName, "⌃⇧T", "默认组合显示名")
    eq(HotKeyConfig.fallback.keyCode, UInt32(kVK_ANSI_T), "默认组合键码")
    eq(HotKeyConfig.fallback.modifiers, UInt32(controlKey | shiftKey), "默认组合修饰键掩码")

    // ——— 必须含 ⌃⌥⌘ 之一，否则拒绝（否则会拦下正常打字）———
    check(HotKeyConfig(event: keyEvent(0, "a", [])!) == nil, "纯字母被拒绝")
    check(HotKeyConfig(event: keyEvent(0, "a", [.shift])!) == nil, "仅 Shift 被拒绝")
    check(HotKeyConfig(event: keyEvent(0, "a", [.capsLock])!) == nil, "仅 CapsLock 被拒绝")

    // ——— 含其一即接受 ———
    let ctrlShiftT = HotKeyConfig(
        event: keyEvent(UInt16(kVK_ANSI_T), "t", [.control, .shift])!)
    check(ctrlShiftT != nil, "⌃⇧T 被接受")
    eq(ctrlShiftT?.displayName ?? "", "⌃⇧T", "⌃⇧T 显示名")
    eq(ctrlShiftT?.modifiers ?? 0, UInt32(controlKey | shiftKey), "⌃⇧ 的 Carbon 掩码")

    // ——— 修饰键显示顺序固定为 ⌃⌥⇧⌘ ———
    let allModifiers = HotKeyConfig(
        event: keyEvent(UInt16(kVK_ANSI_T), "t", [.command, .shift, .option, .control])!)
    eq(allModifiers?.displayName ?? "", "⌃⌥⇧⌘T", "四个修饰键按 ⌃⌥⇧⌘ 排序")

    let cmdOnly = HotKeyConfig(event: keyEvent(UInt16(kVK_ANSI_T), "t", [.command])!)
    eq(cmdOnly?.displayName ?? "", "⌘T", "仅 ⌘ 合法且显示正确")

    // ——— 无可打印字符的键走特殊键名映射 ———
    let space = HotKeyConfig(event: keyEvent(UInt16(kVK_Space), " ", [.control])!)
    eq(space?.displayName ?? "", "⌃Space", "空格走特殊键名映射")

    // ——— Equatable ———
    check(ctrlShiftT != cmdOnly, "不同组合不相等")
    let ctrlShiftTAgain = HotKeyConfig(
        event: keyEvent(UInt16(kVK_ANSI_T), "t", [.control, .shift])!)
    check(ctrlShiftT == ctrlShiftTAgain, "相同组合相等")

    // ——— UserDefaults 持久化往返 ———
    let custom = HotKeyConfig(
        event: keyEvent(UInt16(kVK_ANSI_T), "t", [.option, .command])!)!
    HotKeyStore.save(custom)
    let loaded = HotKeyStore.load()
    eq(loaded.keyCode, custom.keyCode, "持久化 keyCode 往返")
    eq(loaded.modifiers, custom.modifiers, "持久化 modifiers 往返")
    eq(loaded.displayName, custom.displayName, "持久化 displayName 往返")

    HotKeyStore.reset()
    eq(HotKeyStore.load().displayName, HotKeyConfig.fallback.displayName, "reset 后回落到默认值")
}
