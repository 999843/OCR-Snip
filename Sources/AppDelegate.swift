import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private var hotKeyConfig = HotKeyStore.load()
    private var hotKeyMenuItem: NSMenuItem?

    private let resultWindow = ResultWindow()
    private let settingsWindow = SettingsWindow()
    private var isCapturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()
        wireSettings()

        if !registerHotKey(hotKeyConfig) {
            alert(
                "快捷键 \(hotKeyConfig.displayName) 注册失败",
                info: "可能已被其他 App 占用。可以从菜单栏「设置…」换一个，或直接点菜单栏图标触发。"
            )
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

        let hotKeyItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        hotKeyItem.isEnabled = false
        menu.addItem(hotKeyItem)
        hotKeyMenuItem = hotKeyItem
        updateHotKeyMenuItem()

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )

        item.menu = menu
        statusItem = item
    }

    private func updateHotKeyMenuItem() {
        hotKeyMenuItem?.title = "快捷键 \(hotKeyConfig.displayName)"
    }

    // MARK: - 快捷键

    private func wireSettings() {
        settingsWindow.onChange = { [weak self] in self?.apply($0) }
        settingsWindow.onRecordingChange = { [weak self] isRecording in
            // 录制期间必须注销：否则按下当前快捷键会直接触发截图，新组合永远录不进来
            if isRecording {
                self?.hotKey = nil
            } else {
                self?.restoreHotKeyIfNeeded()
            }
        }
    }

    private func apply(_ config: HotKeyConfig) {
        let previous = hotKeyConfig
        guard config != previous else {
            restoreHotKeyIfNeeded()
            return
        }

        guard registerHotKey(config) else {
            _ = registerHotKey(previous) // 注册不上就退回原来那个，不能让用户失去快捷键
            settingsWindow.revert(to: previous)
            alert("\(config.displayName) 无法注册", info: "这个组合可能已被系统或其他 App 占用，换一个试试。")
            return
        }

        hotKeyConfig = config
        HotKeyStore.save(config)
        updateHotKeyMenuItem()
    }

    /// 先释放旧的再注册，否则注册同一组合必然失败
    private func registerHotKey(_ config: HotKeyConfig) -> Bool {
        hotKey = nil
        hotKey = HotKey(keyCode: config.keyCode, modifiers: config.modifiers) { [weak self] in
            self?.startCapture()
        }
        return hotKey != nil
    }

    private func restoreHotKeyIfNeeded() {
        guard hotKey == nil else { return }
        _ = registerHotKey(hotKeyConfig)
    }

    @objc private func openSettings() {
        settingsWindow.show(current: hotKeyConfig)
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
