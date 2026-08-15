import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 默认 ⌃⇧T，避开 Snipaste 的 F1。改这里即可换键。
    private static let hotKeyCode = UInt32(kVK_ANSI_T)
    private static let hotKeyModifiers = UInt32(controlKey | shiftKey)
    private static let hotKeyLabel = "⌃⇧T"

    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private let resultWindow = ResultWindow()
    private var isCapturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()

        hotKey = HotKey(
            keyCode: Self.hotKeyCode,
            modifiers: Self.hotKeyModifiers,
            action: { [weak self] in self?.startCapture() }
        )
        if hotKey == nil {
            alert("快捷键 \(Self.hotKeyLabel) 注册失败", info: "可能已被其他 App 占用。仍可从菜单栏图标手动触发。")
        }
    }

    // MARK: - 菜单栏

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "text.viewfinder", accessibilityDescription: "OCR Snip"
        )

        let menu = NSMenu()
        let capture = NSMenuItem(
            title: "截图识别文字", action: #selector(startCapture), keyEquivalent: ""
        )
        capture.target = self
        menu.addItem(capture)
        menu.addItem(NSMenuItem(title: "快捷键 \(Self.hotKeyLabel)", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )

        item.menu = menu
        statusItem = item
    }

    // MARK: - 主流程

    @objc private func startCapture() {
        guard !isCapturing else { return }
        isCapturing = true

        // screencapture 会阻塞到用户框选结束，不能占着主线程
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let url = ScreenCapture.interactiveRegion() else {
                DispatchQueue.main.async { self?.isCapturing = false } // 用户按 ESC 取消
                return
            }
            defer { try? FileManager.default.removeItem(at: url) }

            let result = Result { try TextRecognizer.recognize(imageAt: url) }

            DispatchQueue.main.async {
                self?.isCapturing = false
                self?.present(result)
            }
        }
    }

    private func present(_ result: Result<String, Error>) {
        switch result {
        case .success(let text):
            // 空结果也进确认窗，窗内会显示「未识别到文字」，比弹 alert 打断轻
            resultWindow.show(text: text)
        case .failure(let error):
            alert("识别失败", info: error.localizedDescription)
        }
    }

    private func alert(_ message: String, info: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.runModal()
    }
}
