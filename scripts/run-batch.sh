#!/bin/bash
# 用法: run-batch.sh <inbox目录> <输出目录> [并行数=2]
set -uo pipefail
SRC="${1:?}"; OUT="${2:?}"; W="${3:-2}"
T="$(dirname "$(readlink -f "$0")")"
SKIPDIR="${4:-/nonexistent}"
mkdir -p "$OUT"
find "$SRC" -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.mov' \) -print0 \
| xargs -0 -P "$W" -I{} bash -c '
  f="$1"; OUT="$2"; T="$3"
  slug="$(basename "$f")"; slug="${slug%.*}"
  if [ -f "$OUT/$slug.txt" ] || [ -f "$OUT/$slug.md" ]; then
    echo "[skip] $slug"; exit 0
  fi
  if compgen -G "$SKIPDIR/*$slug*" >/dev/null 2>&1; then
    echo "[skip-dup] $slug"; exit 0
  fi
  "$T/process-video.sh" "$f" "$OUT" >> "$OUT/.batch.log" 2>&1
  echo "[done] $slug"
' _ {} "$OUT" "$T"
