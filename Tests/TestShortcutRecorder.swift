import AppKit
import Carbon.HIToolbox

private func keyDown(_ keyCode: UInt16, _ chars: String,
                     _ flags: NSEvent.ModifierFlags) -> NSEvent? {
    NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
        windowNumber: 0, context: nil, characters: chars,
        charactersIgnoringModifiers: chars, isARepeat: false, keyCode: keyCode)
}

private func leftMouseDown() -> NSEvent? {
    NSEvent.mouseEvent(
        with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
        windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
}

/// 录制控件与外部（AppDelegate）之间的契约：何时进出录制态、何时上报捕获。
/// 录制控件是 NSView，可以直接驱动，不需要窗口或 GUI 会话。
private final class RecorderSpy {
    let recorder = ShortcutRecorderView(config: .fallback)
    private(set) var captures: [HotKeyConfig] = []
    private(set) var recordingStates: [Bool] = []

    init() {
        recorder.onCapture = { [weak self] in self?.captures.append($0) }
        recorder.onRecordingChange = { [weak self] in self?.recordingStates.append($0) }
    }

    /// 点击进入录制态
    @discardableResult
    func beginRecording() -> Bool {
        guard let event = leftMouseDown() else { return false }
        recorder.mouseDown(with: event)
        return true
    }

    func press(_ keyCode: UInt16, _ chars: String, _ flags: NSEvent.ModifierFlags) -> Bool {
        guard let event = keyDown(keyCode, chars, flags) else { return false }
        recorder.keyDown(with: event)
        return true
    }
}

func testShortcutRecorder() {
    // ——— 初始状态：不应有任何回调 ———
    do {
        let spy = RecorderSpy()
        check(spy.captures.isEmpty && spy.recordingStates.isEmpty, "初始不触发任何回调")
    }

    // ——— 未录制时 cancelRecording 应当是空操作（幂等）———
    do {
        let spy = RecorderSpy()
        spy.recorder.cancelRecording()
        check(spy.recordingStates.isEmpty, "未录制时 cancelRecording 无副作用")
    }

    // ——— 点击进入录制态 ———
    do {
        let spy = RecorderSpy()
        guard spy.beginRecording() else { check(false, "无法构造鼠标事件"); return }
        eq(spy.recordingStates, [true], "mouseDown 进入录制态")
    }

    // ——— 合法组合：上报捕获并退出录制态 ———
    do {
        let spy = RecorderSpy()
        guard spy.beginRecording(),
              spy.press(UInt16(kVK_ANSI_T), "t", [.control, .shift]) else {
            check(false, "无法构造事件"); return
        }
        eq(spy.captures.count, 1, "合法组合触发一次捕获")
        eq(spy.captures.first?.displayName ?? "", "⌃⇧T", "捕获到的组合正确")
        eq(spy.recordingStates, [true, false], "捕获后退出录制态")
    }

    // ——— 非法组合：不上报，且留在录制态等用户重按 ———
    do {
        let spy = RecorderSpy()
        guard spy.beginRecording(), spy.press(0, "a", []) else {
            check(false, "无法构造事件"); return
        }
        check(spy.captures.isEmpty, "缺 ⌃⌥⌘ 的组合不上报")
        eq(spy.recordingStates, [true], "非法组合后仍在录制态")
    }

    // ——— Esc 取消 ———
    do {
        let spy = RecorderSpy()
        guard spy.beginRecording(), spy.press(UInt16(kVK_Escape), "\u{1b}", []) else {
            check(false, "无法构造事件"); return
        }
        check(spy.captures.isEmpty, "Esc 不上报捕获")
        eq(spy.recordingStates, [true, false], "Esc 退出录制态")
    }

    // ——— ⌘ 组合会被菜单 key equivalent 派发吃掉，录制时必须在这里截住 ———
    do {
        let spy = RecorderSpy()
        guard spy.beginRecording(), let event = keyDown(UInt16(kVK_ANSI_T), "t", [.command]) else {
            check(false, "无法构造事件"); return
        }
        check(spy.recorder.performKeyEquivalent(with: event), "录制中 performKeyEquivalent 截住事件")
        eq(spy.captures.first?.displayName ?? "", "⌘T", "⌘ 组合能被录制到")
    }

    // ——— 非录制态不应拦截 key equivalent ———
    do {
        let spy = RecorderSpy()
        guard let event = keyDown(UInt16(kVK_ANSI_T), "t", [.command]) else {
            check(false, "无法构造事件"); return
        }
        check(!spy.recorder.performKeyEquivalent(with: event), "非录制态不截住 key equivalent")
        check(spy.captures.isEmpty, "非录制态不产生捕获")
    }

    // ——— 回归：录制中直接关窗 ———
    // 旧实现在这里漏了收尾：view 不会主动交出 first responder，
    // onRecordingChange(false) 永不触发，AppDelegate 为录制而注销的全局热键
    // 就再也恢复不了（重启 App 前没有截图快捷键）。
    do {
        let spy = RecorderSpy()
        guard spy.beginRecording() else { check(false, "无法构造鼠标事件"); return }
        spy.recorder.cancelRecording()
        eq(spy.recordingStates, [true, false], "[回归] cancelRecording 收尾录制态")
        check(spy.captures.isEmpty, "[回归] cancelRecording 不产生捕获")

        spy.recorder.cancelRecording()
        eq(spy.recordingStates, [true, false], "[回归] 重复 cancelRecording 幂等")
    }

    // ——— resignFirstResponder 也应退出录制态 ———
    do {
        let spy = RecorderSpy()
        guard spy.beginRecording() else { check(false, "无法构造鼠标事件"); return }
        _ = spy.recorder.resignFirstResponder()
        eq(spy.recordingStates, [true, false], "resignFirstResponder 退出录制态")
    }
}
