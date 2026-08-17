# OCR Snip

给 macOS 补一个「截图取字」快捷键。框选屏幕任意区域 → Vision 识别 → 确认窗里看一眼 → 复制。

截图、标注、贴图这些交给 Snipaste，这里只做它没有的那一件事，两者互不干扰。

- **离线**：走系统 Vision 框架，不联网、不上传、无 API 费用
- **无依赖**：框选复用系统 `screencapture -i`，不自绘覆盖层
- **常驻菜单栏**：不占 Dock

## 下载

👉 [**最新版本**](https://github.com/999843/OCR-Snip/releases/latest) — universal（Apple Silicon + Intel），需要 macOS 13+

解压后把 `OCR Snip.app` 拖进「应用程序」，然后**在终端执行一次**：

```bash
xattr -dr com.apple.quarantine "/Applications/OCR Snip.app"
```

这一步不能省：本 App 未经 Apple 公证（公证要 99 美元/年的开发者账号，自用工具不值当），
从浏览器下载的文件带 quarantine 标记，不解除会被 macOS 拦成「已损坏」。

之后打开 App、按 `⌃⇧T`，按提示授权屏幕录制，再退出重开一次即可。

## 构建

只需要 Command Line Tools，不需要完整 Xcode：

```bash
./build.sh              # 当前架构
./build.sh --universal  # arm64 + x86_64 胖二进制
```

产物在 `build/OCR Snip.app`，拖进 `/Applications` 即可。

打 tag 会触发 GitHub Actions 自动构建并发布 Release：

```bash
git tag v0.3.0 && git push origin v0.3.0
```

## 使用

按 **⌃⇧T**（默认，可在设置里改）→ 框选 → 结果窗弹出。

- 结果**可直接编辑**，改掉误识别再复制
- **「合并段落」**：OCR 是按图像上的视觉行返回的，一段话会被切成好几行。点一下接回段落，`⌘Z` 可撤销。
  刻意做成手动按钮而不是自动执行——代码块、列表、表格需要保留换行，自动猜必然猜错
- `Enter` 复制并关闭，`Esc` 取消
- 也可以点菜单栏图标手动触发

## 设置

菜单栏图标 → **设置…**（或 `⌘,`）。目前只有快捷键这一项。

点一下方框，按下想用的组合，立即生效并记住。三条规则：

- **必须包含 `⌃` `⌥` `⌘` 中至少一个**。只有 `⇧` 或纯字母会把正常打字也一起拦下来，会被拒绝（响一声）
- 录制中按 `Esc` 取消
- 组合被别的 App 占用时会提示，并**自动退回原来那个** —— 不会让你落到没有快捷键可用的状态

## 首次运行

系统会要求**屏幕录制**权限：系统设置 → 隐私与安全性 → 屏幕录制，勾上 OCR Snip，然后**重启 App**。

## 让权限不再反复失效

默认 ad-hoc 签名（`codesign --sign -`）下，**每次重建都会重新索要屏幕录制权限**：TCC 对 ad-hoc App 按 cdhash 认人，代码一变 cdhash 就变，系统当成一个新 App。系统设置里那条旧记录会残留、看着是开的，实际对不上。

只在你还要继续改代码时才需要根治。做一张自签名证书即可：

1. 打开「钥匙串访问」→ 菜单栏「钥匙串访问 → 证书助理 → 创建证书…」
2. 名称填 **`OCR Snip Signing`**，身份类型「自签名根证书」，证书类型 **「代码签名」**
3. 创建完成后验证：`security find-identity -v -p codesigning` 应能看到它

之后 `./build.sh` 会自动改用它签名（输出 `🔏 稳定证书签名`），权限跨重建保留。
证书名想换的话，用 `OCRSNIP_SIGN_ID=你的名字 ./build.sh`。

**权限已经乱掉时的清理**：在系统设置 → 隐私与安全性 → 录屏与系统录音里，选中 OCR Snip 点 `−` 删除旧记录，再重启 App 重新授权一次。

## 其他限制

- 不做长截图、不做标注 —— 那是 Snipaste 的活。

## 改配置

| 想改什么 | 改哪里 |
|---|---|
| 快捷键 | 菜单栏 → 设置…（**不用改代码**） |
| 默认快捷键 | `Sources/HotKeyConfig.swift` 的 `fallback` |
| 识别语言 | `Sources/TextRecognizer.swift` 的 `defaultLanguages` |

## 结构

```
Sources/
├── main.swift                 入口
├── AppDelegate.swift          菜单栏 + 快捷键注册 + 流程编排
├── HotKey.swift               Carbon 全局热键（不需要辅助功能权限）
├── HotKeyConfig.swift         快捷键模型 + UserDefaults 持久化
├── ShortcutRecorderView.swift 快捷键录制控件
├── SettingsWindow.swift       设置窗口
├── ScreenCapture.swift        调用 screencapture -i
├── TextRecognizer.swift       Vision OCR
├── TextCleanup.swift          段落合并
└── ResultWindow.swift         确认窗
```

## License

MIT
