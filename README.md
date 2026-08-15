# OCR Snip

给 macOS 补一个「截图取字」快捷键。框选屏幕任意区域 → Vision 识别 → 确认窗里看一眼 → 复制。

截图、标注、贴图这些交给 Snipaste，这里只做它没有的那一件事，两者互不干扰。

- **离线**：走系统 Vision 框架，不联网、不上传、无 API 费用
- **无依赖**：框选复用系统 `screencapture -i`，不自绘覆盖层
- **常驻菜单栏**：不占 Dock

## 构建

只需要 Command Line Tools，不需要完整 Xcode：

```bash
./build.sh              # 当前架构
./build.sh --universal  # arm64 + x86_64 胖二进制，要拷给别人时用
```

产物在 `build/OCR Snip.app`，拖进 `/Applications` 即可。

拷给别人时，对方需要先解除隔离标记（本 App 未经 Apple 公证）：

```bash
xattr -dr com.apple.quarantine "/Applications/OCR Snip.app"
```

## 使用

按 **⌃⇧T** → 框选 → 结果窗弹出。

- 结果**可直接编辑**，改掉误识别再复制
- `Enter` 复制并关闭，`Esc` 取消
- 也可以点菜单栏图标手动触发

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
| 快捷键 | `Sources/AppDelegate.swift` 顶部的 `hotKeyCode` / `hotKeyModifiers` |
| 识别语言 | `Sources/TextRecognizer.swift` 的 `defaultLanguages` |

## 结构

```
Sources/
├── main.swift            入口
├── AppDelegate.swift     菜单栏 + 快捷键 + 流程编排
├── HotKey.swift          Carbon 全局热键（不需要辅助功能权限）
├── ScreenCapture.swift   调用 screencapture -i
├── TextRecognizer.swift  Vision OCR
└── ResultWindow.swift    确认窗
```

## License

MIT
