import AppKit

/// 识别结果确认窗：复制前先看一眼，可直接改掉误识别的字。
final class ResultWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var textView: NSTextView?
    private var countLabel: NSTextField?

    func show(text: String) {
        if window == nil { build() }
        guard let window, let textView else { return }

        textView.string = text
        updateCount()
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
    }

    // MARK: - 构建

    private func build() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "识别结果"
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.delegate = self

        let content = NSView()
        window.contentView = content

        let hint = label("确认无误后复制，也可以直接在下面改：", secondary: true)
        let scrollView = buildTextArea()
        let count = label("", secondary: true)
        let cancel = button(title: "取消", key: "\u{1b}", action: #selector(dismiss))
        let copy = button(title: "复制", key: "\r", action: #selector(copyAndClose))

        for view in [hint, scrollView, count, cancel, copy] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }

        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            hint.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),

            scrollView.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: copy.topAnchor, constant: -12),

            count.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            count.centerYAnchor.constraint(equalTo: copy.centerYAnchor),

            copy.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            copy.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
            copy.widthAnchor.constraint(greaterThanOrEqualToConstant: 88),

            cancel.trailingAnchor.constraint(equalTo: copy.leadingAnchor, constant: -8),
            cancel.centerYAnchor.constraint(equalTo: copy.centerYAnchor),
        ])

        self.window = window
        self.countLabel = count
    }

    private func buildTextArea() -> NSScrollView {
        // 必须用工厂方法：手工 NSTextView() 的 frame / containerSize 都是 zero，
        // 结果是有文字但排不出版，窗口里一片空白。
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.isEditable = true
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.delegate = self

        self.textView = textView
        return scrollView
    }

    private func label(_ text: String, secondary: Bool) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 11)
        if secondary { field.textColor = .secondaryLabelColor }
        return field
    }

    private func button(title: String, key: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.keyEquivalent = key
        return button
    }

    // MARK: - 动作

    @objc private func copyAndClose() {
        guard let text = textView?.string, !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        dismiss()
    }

    @objc private func dismiss() {
        window?.orderOut(nil)
        // 交还焦点，免得挡住刚才在用的 App
        NSApp.hide(nil)
    }

    private func updateCount() {
        let n = textView?.string.count ?? 0
        countLabel?.stringValue = n == 0 ? "未识别到文字" : "\(n) 个字符"
    }
}

extension ResultWindow: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        updateCount()
    }
}
