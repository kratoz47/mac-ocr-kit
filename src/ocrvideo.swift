import Foundation
import AVFoundation
import AppKit
import Vision

// usage: ocrvideo <video> <intervalSec> <out.json>
let args = CommandLine.arguments
guard args.count >= 4 else {
    FileHandle.standardError.write("usage: ocrvideo <video> <intervalSec> <out.json>\n".data(using: .utf8)!)
    exit(2)
}
let path = args[1]
let interval = max(0.5, Double(args[2]) ?? 2.0)
let outPath = args[3]

let asset = AVURLAsset(url: URL(fileURLWithPath: path))
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero

let duration = asset.duration.seconds
var records: [[String: Any]] = []
var t = 0.0

while t < duration {
    let cm = CMTime(seconds: t, preferredTimescale: 600)
    guard let cg = try? gen.copyCGImage(at: cm, actualTime: nil) else {
        t += interval
        continue
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["zh-Hans", "en-US"]
    request.usesLanguageCorrection = true
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try? handler.perform([request])

    var lines: [[String: Any]] = []
    if let obs = request.results {
        for o in obs {
            guard let c = o.topCandidates(1).first else { continue }
            let bb = o.boundingBox
            lines.append([
                "text": c.string,
                "conf": Double(c.confidence),
                "x": Double(bb.origin.x),
                "y": Double(bb.origin.y),
                "w": Double(bb.size.width),
                "h": Double(bb.size.height),
            ])
        }
    }
    records.append(["t": t, "lines": lines])
    t += interval
}

let payload: [String: Any] = [
    "video": URL(fileURLWithPath: path).lastPathComponent,
    "duration": duration,
    "interval": interval,
    "frames": records,
]
let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
try data.write(to: URL(fileURLWithPath: outPath))
print("frames: \(records.count), duration: \(String(format: "%.1f", duration))s -> \(outPath)")
