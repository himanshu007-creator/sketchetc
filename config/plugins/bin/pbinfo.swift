// pbinfo — print the pasteboard's type identifiers, one per line.
//
// Replaces `osascript -e 'clipboard info'`, which measured ~275ms per call
// because every invocation spins up the AppleScript runtime. This does the same
// job through NSPasteboard directly in a few milliseconds, which matters because
// the answer is needed on every capture and after every screenshot.
//
// Prints PNGf / TIFF style aliases too, so existing string matches keep working.
import AppKit

let pb = NSPasteboard.general
// changeCount first, so callers can skip the expensive part (pbpaste, hashing)
// entirely when the pasteboard has not moved since they last looked
var out: [String] = ["changeCount:\(pb.changeCount)"]

for t in pb.types ?? [] {
    out.append(t.rawValue)
    switch t {
    case .png:    out.append("PNGf")
    case .tiff:   out.append("TIFF")
    case .string: out.append("utf8")
    case .fileURL: out.append("furl")
    default: break
    }
}

print(out.joined(separator: "\n"))
