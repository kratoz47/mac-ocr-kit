# mac-ocr-kit

在 macOS 上把视频里的**画面文字**整段抽出来：逐帧 OCR → 合并成带时间轴的字幕文本。纯本地，用 Apple Vision，不联网、不要 API key。

适合：没有字幕轨的录屏、教程、信息图类视频、PPT 讲解、影视剧硬字幕。有旁白的视频可以走 whisper ASR，本仓库的 `process-video.sh` 会自动判断该用哪条路。

## 组件

| 文件 | 作用 |
|---|---|
| `src/ocrvideo.swift` | `AVAssetImageGenerator` 按固定间隔抽帧 → `VNRecognizeTextRequest`（zh-Hans + en-US）识别 → 输出逐帧 JSON（文字、置信度、归一化坐标） |
| `src/grab.swift` | 在指定时间点抽帧存 PNG，用来人工核对某一秒到底写了什么 |
| `scripts/merge_ocr.py` | 把逐帧 JSON 压成时间轴：剔常驻水印、相邻相似帧合并、丢空段 |
| `scripts/ocr-video.sh` | 上面两步的一键封装 |
| `scripts/process-video.sh` | 有音轨先跑 whisper ASR，质量闸门不过自动转 OCR |
| `scripts/run-batch.sh` | 目录批量处理，`xargs -P` 并行，已处理过的跳过 |
| `scripts/intake.sh` | 列出目录里还没转录的视频 |

## 构建

需要 macOS 13+ 和 Xcode Command Line Tools。

```bash
./build.sh          # 生成 bin/ocrvideo、bin/grab
```

不想建 `bin/` 也行，把 `bin/` 加进 `PATH`，或直接调 `scripts/ocr-video.sh`（它会自己找）。

> 如果 `swiftc` 报 `this SDK is not supported by the compiler`，是 Command Line Tools 与 SDK 版本错位，不是代码问题：重装匹配版本的 CLT（`softwareupdate --list` 看有没有 Command Line Tools 更新），或用 Xcode 里的 toolchain。

## 用法

```bash
# 单条视频：默认每 2 秒抽一帧
scripts/ocr-video.sh video.mp4
# -> video.json（逐帧原始结果） + video.md（时间轴）

# 字幕密集的片子：1 秒一帧
scripts/ocr-video.sh video.mp4 1

# 指定输出前缀
scripts/ocr-video.sh video.mp4 2 /tmp/out

# 只要某几秒的截图
bin/grab video.mp4 ./frames 12.5,48,90

# 整目录批量，2 路并行
scripts/run-batch.sh ~/inbox ~/transcripts 2
```

`video.md` 长这样：

```markdown
# 画面文字（OCR）：video.mp4

- 时长：312.0s｜采样：每 2s 一帧｜帧数：156
- 常驻元素（每帧都在，已剔除）：某某工作室

## 时间轴

| 时间 | 画面文字 |
|---|---|
| 00:00–00:04 | 第一行 ／ 第二行 |
| 00:06–00:12 | … |
```

## 合并逻辑（`merge_ocr.py`）

1. 统计每行文字的出现率，**>60% 的帧**都出现 → 判为水印/栏目标签，全局剔除；
2. 每帧剩余文字按「从上到下、从左到右」排序（Vision 的 y 原点在左下，代码里已反转）；
3. 相邻帧文字相似度（`difflib`）≥ 0.75 → 合并成一段，保留更长的那版；
4. 空帧最多容忍 2 帧，超过就切段；
5. 丢掉不足 2 秒且只有 1 帧的段。

参数可调：`merge_ocr.py in.json out.md --min-conf 0.4`（默认 0.4）。

## 测试

```bash
python3 -m unittest discover -s tests -v
```

5 个用例覆盖 `merge_ocr.py` 的合并行为：常驻水印剔除、相邻相似帧合并、切段、低置信丢弃、单帧丢弃。CI 在 Ubuntu 跑测试，在 macOS runner 上跑 `build.sh` 验证 Swift 能编译。

## 已知限制

- Vision 对**艺术字、竖排、低分辨率、快闪字幕**识别不稳，会漏字或错字；重要引用要回看原片。
- 每帧独立识别，不做时序平滑；同一句话可能前后帧略有出入，合并靠相似度，不保证一字不差。
- 抽帧是均匀间隔的，一句字幕如果只停留 0.5 秒、而间隔是 2 秒，就可能整句丢失。字幕快的片子把间隔调到 1 秒。
- `AVAssetImageGenerator` 对某些编码（如部分 HEVC 变体）会抽帧失败，代码里是跳过该时间点继续，不报错。
- **一行文字如果全片都在同一个位置出现，会被当成水印剔除**。整段固定不动的静态字幕（比如讲师名牌）会误判；这种情况用 `--min-conf` 把阈值调高也救不回来，得手动改常驻判定逻辑。
- 只在 macOS 上可用（Vision + AVFoundation）。

## 许可

MIT，见 [LICENSE](LICENSE)。
