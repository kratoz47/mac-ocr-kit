import Foundation
import AVFoundation
import AppKit

let args = CommandLine.arguments
guard args.count >= 4 else { FileHandle.standardError.write("usage: grab <video> <outdir> <sec,sec>\n".data(using: .utf8)!); exit(2) }
let path = args[1], outDir = args[2]
let times = args[3].split(separator: ",").compactMap { Double($0) }
let asset = AVURLAsset(url: URL(fileURLWithPath: path))
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
for (i, t) in times.enumerated() {
    let cm = CMTime(seconds: t, preferredTimescale: 600)
    do {
        let cg = try gen.copyCGImage(at: cm, actualTime: nil)
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { continue }
        let out = URL(fileURLWithPath: outDir).appendingPathComponent("f\(i).png")
        try data.write(to: out)
        print("ok f\(i).png @\(t)s  \(cg.width)x\(cg.height)")
    } catch {
        print("fail @\(t)s: \(error.localizedDescription)")
    }
}
