#!/usr/bin/env python3
"""merge_ocr.py 的行为测试。运行: python3 -m unittest discover -s tests"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE.parent / "scripts" / "merge_ocr.py"


def frame(t, lines, watermark=True):
    ls = [{"text": "某某频道", "conf": 0.9, "x": 0.1, "y": 0.9, "w": 0.2, "h": 0.05}] if watermark else []
    for i, (txt, c) in enumerate(lines):
        ls.append({"text": txt, "conf": c, "x": 0.1, "y": 0.8 - i * 0.1, "w": 0.5, "h": 0.05})
    return {"t": t, "lines": ls}


class MergeTest(unittest.TestCase):
    def run_merge(self, frames, duration=26.0):
        with tempfile.TemporaryDirectory() as d:
            src = Path(d) / "in.json"
            out = Path(d) / "out.md"
            src.write_text(json.dumps({
                "video": "t.mp4", "duration": duration, "interval": 2, "frames": frames,
            }, ensure_ascii=False), encoding="utf-8")
            r = subprocess.run([sys.executable, str(SCRIPT), str(src), str(out)],
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            return out.read_text(encoding="utf-8")

    def test_persistent_watermark_removed_from_timeline(self):
        frames = [frame(t, [(f"字幕第{t}帧", 0.9)]) for t in range(0, 10, 2)]
        md = self.run_merge(frames)
        header, timeline = md.split("## 时间轴")
        self.assertIn("某某频道", header)          # 头部列出被剔除的常驻元素
        self.assertNotIn("某某频道", timeline)     # 时间轴里不再出现

    def test_adjacent_similar_frames_merge(self):
        # 连续 2 帧几乎相同（只差一个空格）→ 合并成一段
        frames = [frame(0, [("同一句话", 0.9)]), frame(2, [("同一句话 ", 0.9)]),
                  frame(4, [("另一句", 0.9)]), frame(6, [("另一句 ", 0.9)])]
        md = self.run_merge(frames, duration=8.0)
        rows = [l for l in md.splitlines() if l.startswith("| 00:")]
        self.assertEqual(len(rows), 2, md)
        self.assertIn("00:00–00:02 | 同一句话", rows[0])
        self.assertIn("00:04–00:06 | 另一句", rows[1])

    def test_change_splits_segment(self):
        frames = [frame(t, [("开头一句", 0.9)]) for t in range(0, 10, 2)]
        frames += [frame(t, [("换了说法", 0.9)]) for t in range(10, 20, 2)]
        md = self.run_merge(frames, duration=22.0)
        rows = [l for l in md.splitlines() if l.startswith("| 00:")]
        self.assertEqual(len(rows), 2, md)
        self.assertIn("00:00–00:08", rows[0])
        self.assertIn("00:10–00:18", rows[1])

    def test_low_conf_dropped(self):
        frames = [frame(t, [("模糊", 0.2)], watermark=False) for t in range(0, 6, 2)]
        md = self.run_merge(frames, duration=6.0)
        self.assertNotIn("模糊", md)

    def test_single_frame_segment_dropped(self):
        # 只出现 1 帧（<2 秒）的零散文字不进时间轴
        frames = [frame(0, [("长句", 0.9)]), frame(2, [("长句 ", 0.9)]), frame(4, [("一闪而过", 0.9)])]
        md = self.run_merge(frames, duration=6.0)
        self.assertNotIn("一闪而过", md)


if __name__ == "__main__":
    unittest.main()
