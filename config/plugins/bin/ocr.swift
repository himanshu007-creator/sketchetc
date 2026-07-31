// ocr — read the text out of an image file and print it.
//
// Uses Vision's on-device text recogniser: no API key, no network, nothing
// leaves the machine, which is the same promise the rest of sketchetc makes.
// Pulling text off the screen is how most people get a screenshot into an LLM,
// and it is the one thing a screenshot tool can do that pasting an image cannot.
//
// usage: ocr <image-path>   → recognised text on stdout, empty if none found
import Foundation
import Vision
import AppKit

guard CommandLine.arguments.count > 1,
      let image = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("ocr: cannot read image\n".data(using: .utf8)!)
    exit(1)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true

do {
    try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
} catch {
    FileHandle.standardError.write("ocr: \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}

// Vision returns observations in reading order already; keep the top candidate
// for each line and join them so the result pastes as the block it looked like.
let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
guard !lines.isEmpty else { exit(2) }
print(lines.joined(separator: "\n"))
