import AppKit

/// 设置窗口。目前只有一项：全局快捷键。
/// 只管 UI —— 持久化和热键注册由 AppDelegate 负责，注册失败时它会回调 `revert`。
final class SettingsWindow: NSObject {
    var onChange: ((HotKeyConfig) -> Void)?
    var onRecordingChange: ((Bool) -> Void)?

    private var window: NSWindow?
    private var recorder: ShortcutRecorderView?

    func show(current: HotKeyConfig) {
        if window == nil { build(current: current) }
        recorder?.update(current)

        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// 新快捷键注册失败时，把显示回滚成实际生效的那个
    func revert(to config: HotKeyConfig) {
        recorder?.update(config)
    }

    private func build(current: HotKeyConfig) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 148),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        window.isReleasedWhenClosed = false

        let content = NSView()
        window.contentView = content

        let title = NSTextField(labelWithString: "截图识别快捷键")
        title.font = .systemFont(ofSize: 13)

        let recorder = ShortcutRecorderView(config: current)
        recorder.onCapture = { [weak self] in self?.onChange?($0) }
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

        for view in [title, recorder, reset, hint] {
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
        ])

        self.window = window
        self.recorder = recorder
    }

    @objc private func resetToDefault() {
        onChange?(.fallback)
    }
}
