#!/bin/bash
# 构建 OCR Snip.app。只依赖 Command Line Tools，不需要完整 Xcode。
set -euo pipefail
cd "$(dirname "$0")"

APP="build/OCR Snip.app"
MACOS="$APP/Contents/MacOS"

rm -rf "$APP"
mkdir -p "$MACOS" "$APP/Contents/Resources"

swiftc -O \
	-target "$(uname -m)-apple-macosx13.0" \
	Sources/*.swift \
	-o "$MACOS/OCRSnip" \
	-framework AppKit -framework Vision -framework Carbon

cp Resources/Info.plist "$APP/Contents/Info.plist"

# TCC 对 ad-hoc 签名按 cdhash 认人，每次重建都算「新 App」，屏幕录制权限随之失效。
# 用一张自签名证书就能让签名身份稳定下来，跨重建保留授权。见 README。
SIGN_ID="${OCRSNIP_SIGN_ID:-OCR Snip Signing}"

if security find-identity -v -p codesigning 2>/dev/null | grep -qF "$SIGN_ID"; then
	codesign --force --sign "$SIGN_ID" "$APP"
	echo "🔏 稳定证书签名: $SIGN_ID（权限可跨重建保留）"
else
	codesign --force --sign - "$APP"
	echo "⚠️  ad-hoc 签名：重建后需重新授权屏幕录制。根治办法见 README。"
fi

echo "✅ 构建完成: $APP"
