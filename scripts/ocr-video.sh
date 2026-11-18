#!/bin/bash
# 用法: ocr-video.sh <video> [间隔秒=2] [输出前缀]
# 输出: <前缀>.json（逐帧 OCR 原始结果）+ <前缀>.md（合并后的字幕时间轴）
set -euo pipefail
V="${1:?用法: ocr-video.sh <video> [间隔秒] [输出前缀]}"
IV="${2:-2}"
OUT="${3:-${V%.*}}"
T="$(cd "$(dirname "$(readlink -f "$0")")" && pwd -P)"
ROOT="$(dirname "$T")"

# 优先用 PATH 里的 ocrvideo，其次用仓库内构建产物
OCRVIDEO="$(command -v ocrvideo || echo "$ROOT/bin/ocrvideo")"
[ -x "$OCRVIDEO" ] || { echo "找不到 ocrvideo，先跑 ./build.sh" >&2; exit 1; }

"$OCRVIDEO" "$V" "$IV" "$OUT.json"
python3 "$T/merge_ocr.py" "$OUT.json" "$OUT.md"
echo "-> $OUT.md"
