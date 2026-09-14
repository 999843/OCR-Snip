import AppKit

/// 设置窗口：全局快捷键 + 开机启动。
/// 只管 UI —— 持久化、热键注册、登录项都由 AppDelegate 负责，
/// 操作失败时它会回调 `revert(to:)` / `setLaunchAtLogin(_:)` 把显示拨回真实状态。
final class SettingsWindow: NSObject {
    var onChange: ((HotKeyConfig) -> Void)?
    var onRecordingChange: ((Bool) -> Void)?
    var onToggleLaunchAtLogin: ((Bool) -> Void)?

    private var window: NSWindow?
    private var recorder: ShortcutRecorderView?
    private var launchAtLoginCheckbox: NSButton?

    func show(hotKey: HotKeyConfig, launchAtLogin: Bool) {
        if window == nil { build(current: hotKey) }
        recorder?.update(hotKey)
        setLaunchAtLogin(launchAtLogin)

        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// 新快捷键注册失败时，把显示回滚成实际生效的那个
    func revert(to config: HotKeyConfig) {
        recorder?.update(config)
    }

    /// 把勾选框拨到系统里的真实状态。打开窗口时刷新，操作失败时回滚。
    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginCheckbox?.state = enabled ? .on : .off
    }

    private func build(current: HotKeyConfig) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        window.isReleasedWhenClosed = false
        window.delegate = self

        let content = NSView()
        window.contentView = content

        let title = NSTextField(labelWithString: "截图识别快捷键")
        title.font = .systemFont(ofSize: 13)

        let recorder = ShortcutRecorderView(config: current)
        recorder.onCapture = { [weak self] in self?.propose($0) }
        recorder.onRecordingChange = { [weak self] in self?.onRecordingChange?($0) }

        let reset = NSButton(title: "恢复默认", target: self, action: #selector(resetToDefault))
        reset.bezelStyle = .rounded

        let hint = NSTextField(
            wrappingLabelWithString: """
            点击右侧方框后按下想用的组合键。必须包含 ⌃ ⌥ ⌘ 中至少一个——\
            只有 ⇧ 或纯字母会把正常打字一起拦下来。录制中按 Esc 取消。
            """
        )
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        let launchAtLogin = NSButton(
            checkboxWithTitle: "登录时自动启动", target: self, action: #selector(toggleLaunchAtLogin)
        )

        let launchHint = NSTextField(
            wrappingLabelWithString: """
            登记为系统登录项，可在「系统设置 → 通用 → 登录项」里统一管理。\
            在那里手动改动后，重新打开本窗口会同步过来。
            """
        )
        launchHint.font = .systemFont(ofSize: 11)
        launchHint.textColor = .secondaryLabelColor

        for view in [title, recorder, reset, hint, launchAtLogin, launchHint] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            title.centerYAnchor.constraint(equalTo: recorder.centerYAnchor),

            recorder.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            recorder.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 12),

            reset.leadingAnchor.constraint(equalTo: recorder.trailingAnchor, constant: 8),
            reset.centerYAnchor.constraint(equalTo: recorder.centerYAnchor),
            reset.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),

            hint.topAnchor.constraint(equalTo: recorder.bottomAnchor, constant: 18),
            hint.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            hint.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            launchAtLogin.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 20),
            launchAtLogin.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            launchHint.topAnchor.constraint(equalTo: launchAtLogin.bottomAnchor, constant: 6),
            launchHint.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            launchHint.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
        ])

        self.window = window
        self.recorder = recorder
        self.launchAtLoginCheckbox = launchAtLogin
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        onToggleLaunchAtLogin?(sender.state == .on)
    }

    @objc private func resetToDefault() {
        propose(.fallback)
    }

    /// 先把新组合显示出来，再往外报。注册失败时 AppDelegate 会调 `revert(to:)` 回滚。
    /// 不在这里显示的话，成功那条路径上没有任何人刷新方框，它会一直停在旧值——
    /// 看起来就像快捷键改不了。
    private func propose(_ config: HotKeyConfig) {
        recorder?.update(config)
        onChange?(config)
    }
}

extension SettingsWindow: NSWindowDelegate {
    /// 关窗时录制态必须收尾。否则 view 不会交出 first responder，
    /// `onRecordingChange(false)` 永远不触发，AppDelegate 为录制注销的热键就再也回不来。
    func windowWillClose(_ notification: Notification) {
        recorder?.cancelRecording()
    }
}
