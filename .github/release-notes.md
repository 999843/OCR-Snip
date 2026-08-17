下载 `OCR-Snip.zip`，解压后把 `OCR Snip.app` 拖进「应用程序」。

想核对完整性，用同一个 Release 里的 `OCR-Snip.zip.sha256`：

```bash
shasum -a 256 -c OCR-Snip.zip.sha256
```

## ⚠️ 首次打开必读

这个 App **没有经过 Apple 公证**（公证要 99 美元/年的开发者账号，一个自用小工具不值当），
所以从浏览器下载后 macOS 会直接拦下来，提示「已损坏」或「无法验证开发者」。

终端执行一次即可解除：

```bash
xattr -dr com.apple.quarantine "/Applications/OCR Snip.app"
```

介意的话，源码就在仓库里，`./build.sh` 自己编一份，不需要完整 Xcode。

## 授权

首次按快捷键会要**屏幕录制**权限：系统设置 → 隐私与安全性 → 录屏与系统录音，
勾上 OCR Snip，然后**退出 App 重开**（不重开不生效）。

## 用法

App 常驻菜单栏，没有 Dock 图标。

按 **⌃⇧T**（默认快捷键，可改）→ 框选 → 确认窗里检查文字 → `Enter` 复制，`Esc` 取消。
也可以点菜单栏图标选「截图识别文字」。

确认窗里的文字能直接编辑，「合并段落」把被 OCR 按视觉行切断的文字接回段落，`⌘Z` 撤销。

快捷键在菜单栏「设置…」（`⌘,`）里改。启动时若提示快捷键注册失败，多半是被别的 App 占了，换一个即可。

支持 Apple Silicon 与 Intel（universal binary），需要 macOS 13 及以上。
