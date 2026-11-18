#!/bin/bash
# 列出目录里尚未处理过的视频（已有转录/OCR 的跳过）
# 用法: intake.sh <目录> [转录目录]
# 转录目录默认 $TRANSCRIPTS_DIR 或 ~/media/raw/transcripts
set -uo pipefail
DIR="${1:?用法: intake.sh <目录> [转录目录]}"
OUT="${2:-${TRANSCRIPTS_DIR:-$HOME/media/raw/transcripts}}"
[ -d "$DIR" ] || { echo "目录不存在: $DIR"; exit 1; }
n=0
while IFS= read -r f; do
  slug="$(basename "${f%.*}")"
  if compgen -G "$OUT/*$slug*" >/dev/null 2>&1 || compgen -G "$OUT/*/*$slug*" >/dev/null 2>&1; then
    continue
  fi
  echo "$f"; n=$((n+1))
done < <(find "$DIR" -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.mov' \) | sort)
echo "--- 待处理: $n 条" >&2
