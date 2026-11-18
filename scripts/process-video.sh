#!/bin/bash
# 单条视频 → 文字稿（有旁白走 ASR，无旁白自动转 OCR）
# 用法: process-video.sh <视频> [输出目录]
#
# 依赖:
#   ffmpeg / ffprobe
#   whisper-cli（whisper.cpp），模型路径用 WHISPER_MODEL 指定
#   同目录的 ocr-video.sh（无旁白时自动转 OCR）
set -uo pipefail
V="${1:?用法: process-video.sh <视频> [输出目录]}"
OUT="${2:-$(dirname "$V")}"
MODEL="${WHISPER_MODEL:-$HOME/.models/whisper/ggml-large-v3.bin}"
BIN="${WHISPER_BIN:-whisper-cli}"
T="$(cd "$(dirname "$(readlink -f "$0")")" && pwd -P)"
NAME="$(basename "$V")"; SLUG="${NAME%.*}"
TMP="/tmp/pv_$$.wav"

dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$V" 2>/dev/null | cut -d. -f1)
dur=${dur:-0}
[ "$dur" -lt 1 ] && { echo "!! 读不到时长: $NAME"; exit 1; }

echo "=== $NAME  (${dur}s) ==="
ffmpeg -y -loglevel error -i "$V" -ar 16000 -ac 1 -c:a pcm_s16le "$TMP" 2>/dev/null || {
  echo "  无音轨 -> OCR"; rm -f "$TMP"
  ocr_interval=1; [ "$dur" -gt 240 ] && ocr_interval=2
  "$T/ocr-video.sh" "$V" "$ocr_interval" "$OUT/$SLUG"
  exit 0
}

# 1) 先跑 ASR
"$BIN" -m "$MODEL" -l zh -f "$TMP" -otxt -osrt -of "$OUT/$SLUG" -np >/dev/null 2>&1
chars=$(wc -m < "$OUT/$SLUG.txt" 2>/dev/null | tr -d ' '); chars=${chars:-0}
cpm=$(( chars * 60 / dur ))

# 2) 质量闸门：幻觉标记 / 语速过低 / 字数过少 → 判定为无旁白，转 OCR
if [ "$cpm" -lt 40 ] || grep -qE '请不吝点赞|明镜与点点|订阅 ?转发 ?打赏' "$OUT/$SLUG.txt" 2>/dev/null; then
  rm -f "$OUT/$SLUG.txt" "$OUT/$SLUG.srt" "$OUT/$SLUG.json"; rm -f "$TMP"
  echo "  ASR 无效（${chars} 字 / ${cpm} 字每分）-> OCR"
  ocr_interval=1; [ "$dur" -gt 240 ] && ocr_interval=2
  "$T/ocr-video.sh" "$V" "$ocr_interval" "$OUT/$SLUG"
else
  rm -f "$TMP"
  echo "  ASR 完成：${chars} 字（${cpm} 字每分）-> $OUT/$SLUG.txt"
fi
