#!/bin/bash
# 跑单元测试。不联网、不改动系统设置（不注册登录项）、不需要 GUI 会话。
# 用法: ./test.sh
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build/tests

# 排除 Sources/main.swift：测试二进制自带 main.swift，两者会冲突
SOURCES=$(ls Sources/*.swift | grep -v '/main\.swift$')

swiftc \
	-target "$(uname -m)-apple-macosx13.0" \
	-module-cache-path build/tests/mcache \
	$SOURCES Tests/*.swift \
	-o build/tests/run-tests \
	-framework AppKit -framework Vision -framework Carbon -framework ServiceManagement

exec build/tests/run-tests
