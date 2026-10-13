import AppKit
import Carbon.HIToolbox

private func allSubviews(of view: NSView) -> [NSView] {
    view.subviews + view.subviews.flatMap { allSubviews(of: $0) }
}

/// 把控件离屏渲染成 PNG，用于比对「方框上到底显示了什么」。
private func renderPNG(_ view: NSView) -> Data? {
    guard view.bounds.width > 0, view.bounds.height > 0,
          let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
    view.cacheDisplay(in: view.bounds, to: rep)
    return rep.representation(using: .png, properties: [:])
}

/// 造一个「显示指定组合」的参照控件，外观与目标控件对齐后渲染，
/// 用来证明方框显示的就是期望值，而不只是「变了」。
///
/// 必须挂进同一个窗口再渲染：`bitmapImageRepForCachingDisplay` 按视图的
/// backingScaleFactor 出图，游离的视图拿不到窗口的缩放比（Retina 上会是 1x 而非 2x），
/// 那样比出来的像素数都不一样，断言必然假失败。
private func referencePNG(
    config: HotKeyConfig, like recorder: ShortcutRecorderView, host: NSView
) -> Data? {
    let view = ShortcutRecorderView(config: config)
    view.frame = recorder.frame
    host.addSubview(view)
    defer { view.removeFromSuperview() }
    return renderPNG(view)
}

/// 回归「快捷键改不了」：成功路径上方框必须已经显示新组合。
/// 旧实现只有打开窗口和注册失败回滚两处会刷新方框，于是快捷键其实已注册并存盘，
/// 用户看到的却还是旧值 —— 表现为「改了没反应」。
func testSettingsWindow() {
    let settings = SettingsWindow()
    var changed: [HotKeyConfig] = []
    var recordingChanges: [Bool] = []
    settings.onChange = { changed.append($0) }
    settings.onRecordingChange = { recordingChanges.append($0) }
    settings.show(hotKey: .fallback, launchAtLogin: false)

    guard let window = NSApp.windows.first(where: { $0.title == "设置" }),
          let content = window.contentView else {
        check(false, "未能取得设置窗口")
        return
    }

    let subviews = allSubviews(of: content)
    guard let recorder = subviews.first(where: { $0 is ShortcutRecorderView })
        as? ShortcutRecorderView else {
        check(false, "设置窗口里找不到录制控件")
        return
    }
    guard let checkbox = subviews.first(where: {
        ($0 as? NSButton)?.title == "登录时自动启动"
    }) as? NSButton else {
        check(false, "设置窗口里找不到开机启动勾选框")
        return
    }

    // ——— 开机启动勾选框的三态映射（只测 UI 反射，不真的注册登录项）———
    settings.setLaunchAtLogin(true)
    eq(checkbox.state, .on, "setLaunchAtLogin(true) 勾上")
    settings.setLaunchAtLogin(false)
    eq(checkbox.state, .off, "setLaunchAtLogin(false) 取消勾选")

    // ——— 核心回归：捕获成功后，方框显示必须已经是新组合 ———
    guard let before = renderPNG(recorder) else {
        check(false, "无法离屏渲染录制控件")
        return
    }
    guard let down = NSEvent.mouseEvent(
            with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1),
          let key = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.option, .command], timestamp: 0,
            windowNumber: 0, context: nil, characters: "t",
            charactersIgnoringModifiers: "t", isARepeat: false, keyCode: UInt16(kVK_ANSI_T)) else {
        check(false, "无法构造合成事件")
        return
    }

    recorder.mouseDown(with: down)
    recorder.keyDown(with: key)

    eq(changed.count, 1, "捕获后 onChange 被调用一次")
    eq(changed.first?.displayName ?? "", "⌥⌘T", "onChange 收到新组合")

    guard let after = renderPNG(recorder) else {
        check(false, "无法离屏渲染录制控件（刷新后）")
        return
    }
    check(before != after, "[回归] 捕获后方框已重绘（旧实现此处不变）")

    if let expected = referencePNG(config: changed.first!, like: recorder, host: content) {
        check(after == expected, "[回归] 方框显示的正是新组合（与参照渲染一致）")
    }

    // ——— 注册失败时 AppDelegate 会调 revert(to:)，方框必须拨回旧组合 ———
    settings.revert(to: .fallback)
    if let reverted = renderPNG(recorder),
       let expected = referencePNG(config: .fallback, like: recorder, host: content) {
        check(reverted == expected, "revert(to:) 把方框拨回指定组合")
    }

    // ——— 录制态变化必须转发出去 ———
    // AppDelegate 依赖它：录制期间注销全局热键，结束再恢复。
    // 这条链断了 = 录制时按当前快捷键会直接触发截图，新组合永远录不进来。
    // 注意此时录制态序列里已经有上面「进入录制 → 捕获退出」那一轮，
    // 所以期望值是它后面再追加一对 true/false。
    recorder.mouseDown(with: down)
    eq(recordingChanges, [true, false, true], "进入录制态被转发给 AppDelegate")
    recorder.cancelRecording()
    eq(recordingChanges, [true, false, true, false], "退出录制态被转发给 AppDelegate")

    // ——— 回归：录制中直接关窗 ———
    // 必须由 SettingsWindow.windowWillClose 收尾。旧实现缺这一步：关窗时 view
    // 不会主动交出 first responder，onRecordingChange(false) 永不触发，
    // AppDelegate 为录制而注销的全局热键就再也恢复不了。
    recorder.mouseDown(with: down)
    eq(recordingChanges.last, true, "关窗前确实处于录制态")
    settings.windowWillClose(
        Notification(name: NSWindow.willCloseNotification, object: window))
    eq(recordingChanges, [true, false, true, false, true, false],
       "[回归] 关窗收尾录制态，热键得以恢复")
}
