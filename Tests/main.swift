import Foundation

// 极简断言框架：不引第三方依赖，跑完给出非零退出码供 CI/脚本判断。

var passedCount = 0
var failedCount = 0
var failureLines: [String] = []

func check(_ condition: Bool, _ label: String, detail: String = "") {
    if condition {
        passedCount += 1
    } else {
        failedCount += 1
        failureLines.append(detail.isEmpty ? "✗ \(label)" : "✗ \(label)\n      \(detail)")
    }
}

func eq<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
    check(actual == expected, label, detail: "期望 \(expected)，实际 \(actual)")
}

/// 把一组断言归到具名分组下，失败时便于定位
func group(_ name: String, _ body: () -> Void) {
    let before = failedCount
    body()
    print("\(failedCount == before ? "✅" : "❌") \(name)")
}

// MARK: - 运行

group("TextCleanup 段落合并") { testTextCleanup() }
group("HotKeyConfig 快捷键模型") { testHotKeyConfig() }
group("ShortcutRecorderView 录制状态机") { testShortcutRecorder() }
group("SettingsWindow 显示刷新") { testSettingsWindow() }

print("")
if failedCount > 0 {
    print("——— 失败明细 ———")
    failureLines.forEach { print($0) }
    print("")
}
print("断言 \(passedCount + failedCount) 项：通过 \(passedCount)，失败 \(failedCount)")
exit(failedCount == 0 ? 0 : 1)
