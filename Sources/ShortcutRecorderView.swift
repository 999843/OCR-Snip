import AppKit
import Carbon.HIToolbox

/// 快捷键录制框：点一下进入录制态，按下组合即捕获，Esc 取消。
final class ShortcutRecorderView: NSView {
    /// 捕获到合法组合时调用
    var onCapture: ((HotKeyConfig) -> Void)?
    /// 录制态开关。录制期间外部必须临时注销全局热键，
    /// 否则按下当前快捷键会直接触发截图，永远录不进来。
    var onRecordingChange: ((Bool) -> Void)?

    private var config: HotKeyConfig
    private var isRecording = false

    init(config: HotKeyConfig) {
        self.config = config
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("不从 xib 加载") }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 160, height: 26) }

    func update(_ config: HotKeyConfig) {
        self.config = config
        needsDisplay = true
    }

    // MARK: - 输入

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        setRecording(true)
    }

    override func resignFirstResponder() -> Bool {
        setRecording(false)
        return true
    }

    /// ⌘ 组合会先走 key equivalent 派发（被窗口/菜单吃掉），录制时必须在这里截住
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == UInt16(kVK_Escape) {
            endRecording()
            return
        }
        guard let captured = HotKeyConfig(event: event) else {
            NSSound.beep() // 缺 ⌃⌥⌘，会拦截正常打字
            return
        }
        endRecording()
        onCapture?(captured)
    }

    private func endRecording() {
        setRecording(false)
        window?.makeFirstResponder(nil)
    }

    private func setRecording(_ value: Bool) {
        guard isRecording != value else { return }
        isRecording = value
        needsDisplay = true
        onRecordingChange?(value)
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)

        if isRecording {
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 2
        } else {
            NSColor.controlBackgroundColor.setFill()
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
        }
        path.fill()
        path.stroke()

        let text = isRecording ? "按下快捷键…" : config.displayName
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: isRecording ? .regular : .medium),
            .foregroundColor: isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
            withAttributes: attributes
        )
    }
}
