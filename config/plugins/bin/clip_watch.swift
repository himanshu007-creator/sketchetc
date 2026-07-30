// clip_watch — two jobs, both about never missing something you copied:
//  1. poll NSPasteboard.changeCount and trigger clip_captured on any change
//  2. watch the macOS screenshot folder, because ⌘⇧4 / ⌘⇧5 write a file and
//     never touch the pasteboard — so without this, screenshots would never
//     appear in clipboard history.
import AppKit

let store = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : NSString(string: "~/.local/share/sketchetc/data/clipboard").expandingTildeInPath

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

func sketchybar(_ args: [String]) {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    t.arguments = ["sketchybar"] + args
    try? t.run()
}

// ---------- 1. pasteboard ----------
var lastCount = NSPasteboard.general.changeCount
Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
    let current = NSPasteboard.general.changeCount
    if current != lastCount {
        lastCount = current
        sketchybar(["--trigger", "clip_captured"])
    }
}

// ---------- 2. screenshot folder ----------
func screenshotDir() -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    p.arguments = ["read", "com.apple.screencapture", "location"]
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
    try? p.run(); p.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let dir = out.isEmpty ? "~/Desktop" : out
    return NSString(string: dir).expandingTildeInPath
}

let fm = FileManager.default
let shotDir = screenshotDir()
try? fm.createDirectory(atPath: store, withIntermediateDirectories: true)

// remember what was already there so we only import genuinely new shots
var known = Set((try? fm.contentsOfDirectory(atPath: shotDir)) ?? [])

func isImage(_ name: String) -> Bool {
    let l = name.lowercased()
    // shot-*.png is the shot widget's own output, and shot_do.sh already puts it in
    // the store itself. Importing it here too produced two entries for one snip:
    // this copies the file's bytes while the pasteboard path stores pngpaste's
    // re-encode of the same image, so the md5 dedupe can never match the two.
    // This watcher exists for captures that never reach the store any other way,
    // which means the native Cmd+Shift+4/5 screenshots.
    if l.hasPrefix("shot-") { return false }
    return l.hasSuffix(".png") || l.hasSuffix(".jpg") || l.hasSuffix(".jpeg")
}

func md5(_ path: String) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/sbin/md5")
    p.arguments = ["-q", path]
    let pipe = Pipe(); p.standardOutput = pipe
    try? p.run(); p.waitUntilExit()
    return (String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func importShot(_ path: String) {
    // skip anything already in the store (same bytes)
    let hash = md5(path)
    guard !hash.isEmpty else { return }
    for f in (try? fm.contentsOfDirectory(atPath: store)) ?? [] where f.hasSuffix(".png") {
        if md5(store + "/" + f) == hash {
            // same image copied again: make it newest
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: store + "/" + f)
            sketchybar(["--update"])
            return
        }
    }
    let dest = "\(store)/\(Int(Date().timeIntervalSince1970))-img.png"
    // normalise jpg to png so the picker's thumbnails stay uniform
    if path.lowercased().hasSuffix(".png") {
        try? fm.copyItem(atPath: path, toPath: dest)
    } else if let img = NSImage(contentsOfFile: path),
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: dest))
    }
    // keep only the newest five entries, same rule as the shell side
    let files = ((try? fm.contentsOfDirectory(atPath: store)) ?? [])
        .filter { !$0.hasPrefix(".") }
        .map { (name: $0, date: (try? fm.attributesOfItem(atPath: store + "/" + $0)[.modificationDate] as? Date) ?? nil) }
        .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    for old in files.dropFirst(5) { try? fm.removeItem(atPath: store + "/" + old.name) }
    sketchybar(["--update"])
}

// Polled rather than watched on purpose: a DispatchSource here needs a live fd
// and a strong reference, and when either lapses the widget fails silently with
// no symptom except "my screenshot never showed up". A 1s directory diff costs
// nothing and cannot die quietly.
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    let now = Set((try? fm.contentsOfDirectory(atPath: shotDir)) ?? [])
    var deferred = Set<String>()
    for name in now.subtracting(known) where isImage(name) {
        let full = shotDir + "/" + name
        // only fresh files, and only once they have finished being written
        guard let d = (try? fm.attributesOfItem(atPath: full)[.modificationDate] as? Date) ?? nil,
              Date().timeIntervalSince(d) < 30 else { continue }
        let size = (try? fm.attributesOfItem(atPath: full)[.size] as? Int) ?? 0
        if size == 0 { deferred.insert(name); continue }   // still writing, retry next tick
        importShot(full)
    }
    known = now.subtracting(deferred)
}

app.run()
