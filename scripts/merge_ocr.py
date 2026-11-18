#!/usr/bin/env python3
"""把 ocrvideo 的逐帧 OCR 结果压成「字幕时间轴」。

用法: python3 merge_ocr.py <ocr.json> <out.md> [--min-conf 0.4]
"""
import json
import re
import sys
from difflib import SequenceMatcher

STOP_PUNCT = re.compile(r"[\s，。！？、：；,.!?:;“”\"'（）()《》\-—…·•]+")


def norm(s: str) -> str:
    return STOP_PUNCT.sub("", s).lower()


def frame_lines(frame, min_conf):
    lines = [l for l in frame["lines"] if l["conf"] >= min_conf and l["text"].strip()]
    # 从上到下（Vision 的 y 原点在左下），同一行从左到右
    lines.sort(key=lambda l: (-round(l["y"], 2), l["x"]))
    return lines


def similar(a: str, b: str) -> float:
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, a, b).ratio()


def main():
    src, out = sys.argv[1], sys.argv[2]
    min_conf = 0.4
    if "--min-conf" in sys.argv:
        min_conf = float(sys.argv[sys.argv.index("--min-conf") + 1])

    data = json.load(open(src, encoding="utf-8"))
    frames = data["frames"]
    total = len(frames)

    # 1) 常驻行（水印/栏目标签）：出现率 > 60%
    freq = {}
    for fr in frames:
        seen = {norm(l["text"]) for l in fr["lines"] if l["conf"] >= min_conf}
        for s in seen:
            if s:
                freq[s] = freq.get(s, 0) + 1
    persistent = {s for s, c in freq.items() if c > total * 0.6}

    # 2) 每帧剔掉常驻行后，按行排序拼成签名
    sigs = []
    for fr in frames:
        ls = [l["text"].strip() for l in frame_lines(fr, min_conf) if norm(l["text"]) not in persistent]
        sigs.append((fr["t"], ls))

    # 3) 连续相似帧合并
    segments = []
    cur = None
    gap = 0
    for t, ls in sigs:
        joined = "\n".join(ls)
        if not ls:
            # 空帧：结束当前段，但允许 2 帧以内的空档不切段
            gap += 1
            if cur is not None and gap > 2:
                segments.append(cur)
                cur = None
            continue
        gap = 0
        if cur is None:
            cur = {"start": t, "end": t, "text": joined, "frames": 1}
            continue
        if similar(norm(joined), norm(cur["text"])) >= 0.75:
            if len(norm(joined)) > len(norm(cur["text"])):
                cur["text"] = joined
            cur["end"] = t
            cur["frames"] += 1
        else:
            segments.append(cur)
            cur = {"start": t, "end": t, "text": joined, "frames": 1}
    if cur:
        segments.append(cur)

    # 4) 丢掉空段与过短段（<2 秒且只有 1 帧）
    segments = [s for s in segments if s["text"].strip() and (s["end"] - s["start"] >= 2 or s["frames"] > 1)]

    def fmt(x):
        m, s = divmod(int(x), 60)
        return f"{m:02d}:{s:02d}"

    with open(out, "w", encoding="utf-8") as f:
        f.write(f"# 画面文字（OCR）：{data.get('video','')}\n\n")
        f.write(f"- 时长：{data['duration']:.1f}s｜采样：每 {data['interval']}s 一帧｜帧数：{total}\n")
        if persistent:
            f.write("- 常驻元素（每帧都在，已剔除）：" + "、".join(sorted(persistent)[:10]) + "\n")
        f.write("\n## 时间轴\n\n")
        f.write("| 时间 | 画面文字 |\n|---|---|\n")
        for s in segments:
            txt = s["text"].replace("\n", " ／ ").replace("|", "\\|")
            f.write(f"| {fmt(s['start'])}–{fmt(s['end'])} | {txt} |\n")
        f.write("\n## 全文（去重后，按出现顺序）\n\n")
        seen = set()
        for s in segments:
            for line in s["text"].split("\n"):
                k = norm(line)
                if k and k not in seen:
                    seen.add(k)
                    f.write(line + "\n")
    print(f"segments: {len(segments)} -> {out}")


if __name__ == "__main__":
    main()
