// bar_drop <listFile> — makes the whole topbar a drop target, and lets you drag
// the newest shelved file back off it.
//
// sketchybar is a separate process and its window accepts no pasteboard types, so
// the bar itself can never receive a drop. This puts our own transparent window
// over the bar strip instead. Two windows, because they want opposite things:
//
//   catcher — spans the bar. Must NOT take mouse events, or every widget click
//             would break. It is therefore inert (ignoresMouseEvents) until a
//             drag is actually in flight, and a global mouse monitor arms it.
//   grabber — sits only over the shelf widget. Always live, because dragging out
//             has to start from a mouse-down. It reproduces the widget's click
//             behaviour itself so nothing is lost by covering it.
//
// Arming is deliberately conditional: a drag that STARTS inside the bar is one of
// our own controls (the volume slider), and stealing that would break it. Only
// drags that begin elsewhere on screen can arm the catcher.
import AppKit

let listPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : NSString(string: "~/.local/share/sketchetc/data/shelf/list.txt").expandingTildeInPath
let shelfRect: NSRect = {
    // "x,y,w,h" in sketchybar's top-left origin coordinates
    guard CommandLine.arguments.count > 2 else { return .zero }
    let p = CommandLine.arguments[2].split(separator: ",").compactMap { Double($0) }
    guard p.count == 4 else { return .zero }
    return NSRect(x: p[0], y: p[1], width: p[2], height: p[3])
}()
let barHeight: CGFloat = CommandLine.arguments.count > 3
    ? CGFloat(Double(CommandLine.arguments[3]) ?? 30) : 30

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let accent = NSColor(calibratedRed: 1.0, green: 0.43, blue: 0.78, alpha: 1)

func shelfItems() -> [String] {
    guard let s = try? String(contentsOfFile: listPath, encoding: .utf8) else { return [] }
    return s.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
}
func addItems(_ paths: [String]) {
    var cur = shelfItems()
    for p in paths where !cur.contains(p) { cur.append(p) }
    try? FileManager.default.createDirectory(atPath: (listPath as NSString).deletingLastPathComponent,
                                             withIntermediateDirectories: true)
    try? cur.joined(separator: "\n").write(toFile: listPath, atomically: true, encoding: .utf8)
    sketchybar(["--trigger", "shelf_changed"])
}
func sketchybar(_ args: [String]) {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    t.arguments = ["sketchybar"] + args
    try? t.run()
}

// ---------- catcher ----------
final class CatchView: NSView {
    var lit = false { didSet { needsDisplay = true } }
    override func draw(_ r: NSRect) {
        guard lit else { return }
        // a soft accent underline: enough to say "let go here" without covering the bar
        let h: CGFloat = 3
        accent.withAlphaComponent(0.95).setFill()
        NSBezierPath(roundedRect: NSRect(x: 8, y: 0, width: bounds.width - 16, height: h),
                     xRadius: h / 2, yRadius: h / 2).fill()
        accent.withAlphaComponent(0.10).setFill()
        bounds.fill(using: .sourceOver)
    }
    override func draggingEntered(_ s: NSDraggingInfo) -> NSDragOperation {
        lit = true; return .copy
    }
    override func draggingUpdated(_ s: NSDraggingInfo) -> NSDragOperation { .copy }
    override func draggingExited(_ s: NSDraggingInfo?) { lit = false }
    override func draggingEnded(_ s: NSDraggingInfo) { lit = false }
    override func performDragOperation(_ s: NSDraggingInfo) -> Bool {
        lit = false
        guard let urls = s.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
              !urls.isEmpty else { return false }
        addItems(urls.map { $0.path })          // files and folders alike
        // a visible acknowledgement, so a drop never feels like it went nowhere
        sketchybar(["--animate", "sin", "18", "--set", "shelf", "icon.y_offset=5", "icon.y_offset=0"])
        return true
    }
}

let screen = NSScreen.screens.first ?? NSScreen.main!
let barFrame = NSRect(x: screen.frame.minX, y: screen.frame.maxY - barHeight,
                      width: screen.frame.width, height: barHeight)

let catcher = NSWindow(contentRect: barFrame, styleMask: .borderless, backing: .buffered, defer: false)
catcher.isOpaque = false
catcher.backgroundColor = .clear
catcher.hasShadow = false
catcher.level = .screenSaver          // above sketchybar while armed
catcher.ignoresMouseEvents = true     // inert by default: widget clicks must pass through
catcher.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
let catchView = CatchView(frame: NSRect(origin: .zero, size: barFrame.size))
catchView.registerForDraggedTypes([.fileURL])
catcher.contentView = catchView
catcher.orderFrontRegardless()

// ---------- grabber: drag the newest item back off the bar ----------
final class GrabView: NSView, NSDraggingSource {
    var down: NSPoint?
    func draggingSession(_ s: NSDraggingSession, sourceOperationMaskFor c: NSDraggingContext) -> NSDragOperation {
        c == .outsideApplication ? [.copy, .move, .generic] : []
    }
    override func mouseDown(with e: NSEvent) { down = e.locationInWindow }
    override func mouseDragged(with e: NSEvent) {
        guard let d = down else { return }
        let moved = hypot(e.locationInWindow.x - d.x, e.locationInWindow.y - d.y)
        guard moved > 4 else { return }
        // newest first, as chosen: one file per drag, the last thing you shelved
        guard let newest = shelfItems().last,
              FileManager.default.fileExists(atPath: newest) else { down = nil; return }
        down = nil
        let url = NSURL(fileURLWithPath: newest)
        let item = NSDraggingItem(pasteboardWriter: url)
        let icon = NSWorkspace.shared.icon(forFile: newest)
        item.setDraggingFrame(NSRect(x: 0, y: 0, width: 32, height: 32), contents: icon)
        beginDraggingSession(with: [item], event: e, source: self)
    }
    override func mouseUp(with e: NSEvent) {
        // no drag happened, so behave exactly like clicking the widget used to
        guard down != nil else { return }
        down = nil
        let t = Process()
        t.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        t.arguments = ["sketchybar", "--trigger", "shelf_clicked"]
        try? t.run()
    }
}

var grabber: NSWindow?
if shelfRect != .zero {
    // sketchybar reports top-left origin; AppKit windows are bottom-left
    let f = NSRect(x: screen.frame.minX + shelfRect.origin.x,
                   y: screen.frame.maxY - shelfRect.origin.y - shelfRect.height,
                   width: shelfRect.width, height: shelfRect.height)
    let g = NSWindow(contentRect: f, styleMask: .borderless, backing: .buffered, defer: false)
    g.isOpaque = false
    g.backgroundColor = .clear
    g.hasShadow = false
    g.level = .screenSaver
    g.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    g.contentView = GrabView(frame: NSRect(origin: .zero, size: f.size))
    g.orderFrontRegardless()
    grabber = g
}

// ---------- arming ----------
// A drag that begins inside the bar belongs to one of our own controls (the volume
// slider), so only drags starting elsewhere are allowed to arm the catcher.
var startedOutsideBar = false

NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { e in
    startedOutsideBar = !barFrame.contains(NSEvent.mouseLocation)
}
NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { _ in
    if startedOutsideBar && catcher.ignoresMouseEvents {
        catcher.ignoresMouseEvents = false
    }
}
NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { _ in
    // disarm a beat later: the drop is delivered on mouse-up and the window has to
    // still be live when it arrives
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        catcher.ignoresMouseEvents = true
        catchView.lit = false
    }
}

app.run()
