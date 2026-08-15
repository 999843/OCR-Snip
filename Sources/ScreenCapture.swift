import Foundation

enum ScreenCapture {
    /// 调起系统自带的框选 UI（等价 ⌘⇧4），复用系统实现，不自绘覆盖层。
    /// - Returns: 截图临时文件；用户按 ESC 取消时为 nil。
    /// - Note: 阻塞直到用户完成框选，必须在后台线程调用。
    static func interactiveRegion() -> URL? {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ocr-snip-\(UUID().uuidString).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", url.path] // -i 交互框选，-x 静音

        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()

        // 取消时 screencapture 退出码仍为 0，只能靠文件是否落盘判断
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
}
