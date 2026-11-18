#!/bin/bash
# 构建两个 Swift 工具到 ./bin
# 要求: macOS 13+，Xcode Command Line Tools（swiftc）
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin
echo "building bin/ocrvideo ..."
swiftc -O src/ocrvideo.swift -o bin/ocrvideo
echo "building bin/grab ..."
swiftc -O src/grab.swift -o bin/grab
echo "ok:"
./bin/ocrvideo 2>&1 | head -1 || true
./bin/grab 2>&1 | head -1 || true
