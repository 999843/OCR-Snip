#!/bin/bash
# 构建 OCR Snip.app。只依赖 Command Line Tools，不需要完整 Xcode。
# 用法: ./build.sh [--universal]
#   默认只编译当前架构（本机开发快）；--universal 出 arm64 + x86_64 胖二进制（发布用）。
set -euo pipefail
cd "$(dirname "$0")"

APP="build/OCR Snip.app"
MACOS="$APP/Contents/MacOS"
DEPLOY_TARGET="macosx13.0"

rm -rf "$APP"
mkdir -p "$MACOS" "$APP/Contents/Resources"

compile() { # $1=arch $2=输出路径
	swiftc -O \
		-target "$1-apple-$DEPLOY_TARGET" \
		Sources/*.swift \
		-o "$2" \
		-framework AppKit -framework Vision -framework Carbon
}

if [ "${1:-}" = "--universal" ]; then
	compile arm64 "$MACOS/OCRSnip-arm64"
	compile x86_64 "$MACOS/OCRSnip-x86_64"
	lipo -create -output "$MACOS/OCRSnip" "$MACOS/OCRSnip-arm64" "$MACOS/OCRSnip-x86_64"
	rm "$MACOS/OCRSnip-arm64" "$MACOS/OCRSnip-x86_64"
	echo "📦 universal: $(lipo -archs "$MACOS/OCRSnip")"
else
	compile "$(uname -m)" "$MACOS/OCRSnip"
fi

cp Resources/Info.plist "$APP/Contents/Info.plist"

# 图标：icns 是生成物（不进版本库），SVG 有改动时重新生成
if [ ! -f Icon/AppIcon.icns ] || [ Icon/icon.svg -nt Icon/AppIcon.icns ]; then
	swift Icon/make-icon.swift Icon/icon.svg Icon/AppIcon.icns
fi
cp Icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

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
