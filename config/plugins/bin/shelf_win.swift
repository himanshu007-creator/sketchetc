// shelf_win <listFile> — a drop shelf: park files here, drag them out somewhere else.
//
// The point is moving files between apps and Spaces without keeping two Finder
// windows alive. It stores *references*, never copies: nothing is duplicated on
// disk and what you drag out is the real file. The cost of that choice is that
// moving or deleting the original leaves a stale row, so stale rows say so
// plainly rather than failing silently the moment you try to drag one.
//
// The list is a plain newline-delimited file, so the shell side can read and
// write it without needing this window to be running.
import AppKit

let listPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : NSString(string: "~/.local/share/sketchetc/data/shelf/list.txt").expandingTildeInPath

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let bg = NSColor(calibratedRed: 0.09, green: 0.05, blue: 0.16, alpha: 1)
let panel = NSColor(calibratedRed: 0.14, green: 0.09, blue: 0.25, alpha: 1)
let pink = NSColor(calibratedRed: 1.0, green: 0.43, blue: 0.78, alpha: 1)
let dimC = NSColor(calibratedWhite: 1, alpha: 0.42)
let textC = NSColor(calibratedWhite: 0.93, alpha: 1)
let mono = NSFont(name: "JetBrainsMono Nerd Font", size: 12.5) ?? .monospacedSystemFont(ofSize: 12.5, weight: .regular)

let W: CGFloat = 340, ROW: CGFloat = 40, HEAD: CGFloat = 52, FOOT: CGFloat = 34
let MIN_ROWS = 1, MAX_ROWS = 10
// A fixed-height panel left a large empty well under a short list. Sizing to the
// content means the shelf is exactly as big as what it holds.
func windowHeight(_ n: Int) -> CGFloat {
    let rows = CGFloat(max(MIN_ROWS, min(n, MAX_ROWS)))
    let want = rows * ROW + HEAD + FOOT
    // never taller than most of the screen, however much is shelved
    let cap = (NSScreen.main?.visibleFrame.height ?? 800) * 0.6
    return min(want, cap)
}

func loadList() -> [String] {
    guard let s = try? String(contentsOfFile: listPath, encoding: .utf8) else { return [] }
    var seen = Set<String>()
    return s.split(separator: "\n").map(String.init).filter { !$0.isEmpty && seen.insert($0).inserted }
}
func saveList(_ items: [String]) {
    try? FileManager.default.createDirectory(atPath: (listPath as NSString).deletingLastPathComponent,
                                             withIntermediateDirectories: true)
    try? items.joined(separator: "\n").write(toFile: listPath, atomically: true, encoding: .utf8)
    // the bar shows the count, so it has to hear about every change
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    t.arguments = ["sketchybar", "--trigger", "shelf_changed"]
    try? t.run()
}

final class Controller: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var items: [String] = loadList()
    var table: NSTableView!
    var countLabel: NSTextField!

    func refresh() {
        items = loadList()
        table.reloadData()
        countLabel.stringValue = items.isEmpty ? "" : "\(items.count) item\(items.count == 1 ? "" : "s")"
        resize?()
    }
    var resize: (() -> Void)?
    func add(_ paths: [String]) {
        var cur = loadList()
        for p in paths where !cur.contains(p) { cur.append(p) }
        saveList(cur); refresh()
    }
    @objc func clearAll() { saveList([]); refresh() }

    func numberOfRows(in t: NSTableView) -> Int { items.count }
    func tableView(_ t: NSTableView, heightOfRow r: Int) -> CGFloat { ROW }

    // this is what makes a row draggable back out into another app
    func tableView(_ t: NSTableView, pasteboardWriterForRow r: Int) -> NSPasteboardWriting? {
        let p = items[r]
        guard FileManager.default.fileExists(atPath: p) else { return nil }
        return NSURL(fileURLWithPath: p)
    }

    func tableView(_ t: NSTableView, viewFor c: NSTableColumn?, row r: Int) -> NSView? {
        let path = items[r]
        let exists = FileManager.default.fileExists(atPath: path)
        let cell = NSView(frame: NSRect(x: 0, y: 0, width: W - 24, height: ROW))

        let iv = NSImageView(frame: NSRect(x: 6, y: 8, width: 24, height: 24))
        iv.image = exists ? NSWorkspace.shared.icon(forFile: path)
                          : NSImage(named: NSImage.cautionName)
        iv.alphaValue = exists ? 1 : 0.5
        cell.addSubview(iv)

        let name = (path as NSString).lastPathComponent
        let label = NSTextField(labelWithString: name)
        label.font = mono
        label.textColor = exists ? textC : dimC
        label.lineBreakMode = .byTruncatingMiddle
        if !exists {
            label.attributedStringValue = NSAttributedString(string: name, attributes: [
                .font: mono, .foregroundColor: dimC,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue])
        }
        label.frame = NSRect(x: 38, y: exists ? 11 : 17, width: W - 24 - 38 - 30, height: 17)
        cell.addSubview(label)

        if !exists {
            let note = NSTextField(labelWithString: "moved or deleted")
            note.font = NSFont(name: "JetBrainsMono Nerd Font", size: 10) ?? .monospacedSystemFont(ofSize: 10, weight: .regular)
            note.textColor = dimC
            note.frame = NSRect(x: 38, y: 3, width: 200, height: 13)
            cell.addSubview(note)
        }

        let x = NSButton(frame: NSRect(x: W - 24 - 26, y: 10, width: 20, height: 20))
        x.title = "✕"; x.isBordered = false; x.font = mono
        x.contentTintColor = dimC
        x.tag = r
        x.target = self; x.action = #selector(removeRow(_:))
        cell.addSubview(x)
        return cell
    }

    @objc func removeRow(_ sender: NSButton) {
        guard sender.tag < items.count else { return }
        var cur = items; cur.remove(at: sender.tag)
        saveList(cur); refresh()
    }
}

let ctl = Controller()

// The whole window is the drop target, so you can aim anywhere in it.
final class DropView: NSView {
    var onDrop: (([String]) -> Void)?
    var highlighted = false { didSet { needsDisplay = true } }
    // set once the subviews exist; laying out from bounds is what keeps the list
    // the same height as the window no matter how AppKit sized the content view
    var titleView: NSView?, countView: NSView?, scrollView: NSView?, footer: [NSView] = []

    override func layout() {
        super.layout()
        let h = bounds.height
        titleView?.frame = NSRect(x: 16, y: h - 34, width: 140, height: 20)
        countView?.frame = NSRect(x: bounds.width - 150, y: h - 32, width: 134, height: 16)
        scrollView?.frame = NSRect(x: 12, y: FOOT, width: bounds.width - 24, height: max(0, h - HEAD - FOOT))
    }

    override func draw(_ r: NSRect) {
        bg.setFill(); r.fill()
        if highlighted {
            let p = NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 6), xRadius: 14, yRadius: 14)
            pink.withAlphaComponent(0.9).setStroke()
            p.lineWidth = 2
            p.setLineDash([7, 5], count: 2, phase: 0)
            p.stroke()
        }
    }
    override func draggingEntered(_ s: NSDraggingInfo) -> NSDragOperation { highlighted = true; return .copy }
    override func draggingExited(_ s: NSDraggingInfo?) { highlighted = false }
    override func performDragOperation(_ s: NSDraggingInfo) -> Bool {
        highlighted = false
        guard let urls = s.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else { return false }
        onDrop?(urls.map { $0.path })
        return true
    }
}

let H0 = windowHeight(ctl.items.count)
let content = DropView(frame: NSRect(x: 0, y: 0, width: W, height: H0))
content.registerForDraggedTypes([.fileURL])
content.onDrop = { ctl.add($0) }

let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: W, height: H0),
                   styleMask: [.titled, .fullSizeContentView, .closable],
                   backing: .buffered, defer: false)
win.titleVisibility = .hidden
win.titlebarAppearsTransparent = true
win.level = .floating
win.backgroundColor = bg
win.appearance = NSAppearance(named: .darkAqua)
win.contentView = content
win.isMovableByWindowBackground = true
// the traffic lights sat on top of the title, and Esc or the bar item already
// close this window
for b in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
    win.standardWindowButton(b)?.isHidden = true
}

let title = NSTextField(labelWithString: "Shelf")
title.font = NSFont(name: "JetBrainsMono Nerd Font Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
title.textColor = pink
content.addSubview(title)
content.titleView = title

let countLabel = NSTextField(labelWithString: "")
countLabel.font = mono
countLabel.textColor = dimC
countLabel.alignment = .right
content.addSubview(countLabel)
content.countView = countLabel
ctl.countLabel = countLabel

let col = NSTableColumn(identifier: .init("c"))
col.width = W - 24
let table = NSTableView(frame: NSRect(x: 12, y: FOOT, width: W - 24, height: H0 - HEAD - FOOT))
table.headerView = nil
table.backgroundColor = panel
table.addTableColumn(col)
table.dataSource = ctl
table.delegate = ctl
table.rowHeight = ROW
table.style = .plain
table.selectionHighlightStyle = .none
// copy only: a reference shelf must never let a receiver move the original away
table.setDraggingSourceOperationMask(.copy, forLocal: false)
ctl.table = table

// AppKit's coordinate origin is bottom-left, so a table with fewer rows than
// the scroll view is tall renders its rows pinned to the bottom. A flipped clip
// view puts the origin at the top, which is where a list belongs.
final class FlippedClip: NSClipView { override var isFlipped: Bool { true } }

let scroll = NSScrollView(frame: table.frame)
scroll.contentView = FlippedClip()
scroll.documentView = table
scroll.drawsBackground = true
scroll.backgroundColor = panel
scroll.wantsLayer = true
scroll.layer?.cornerRadius = 10
scroll.hasVerticalScroller = true
content.addSubview(scroll)
content.scrollView = scroll

let hint = NSTextField(labelWithString: "drag files in · drag out to copy · esc closes")
hint.font = NSFont(name: "JetBrainsMono Nerd Font", size: 10.5) ?? .monospacedSystemFont(ofSize: 10.5, weight: .regular)
hint.textColor = dimC
hint.frame = NSRect(x: 16, y: 10, width: W - 130, height: 14)
content.addSubview(hint)

let clear = NSButton(frame: NSRect(x: W - 92, y: 6, width: 78, height: 22))
clear.title = "clear all"
clear.font = mono
clear.bezelStyle = .rounded
clear.isBordered = false
clear.contentTintColor = dimC
clear.target = ctl
clear.action = #selector(Controller.clearAll)
content.addSubview(clear)

final class KeyWin: NSWindow {
    override func keyDown(with e: NSEvent) { if e.keyCode == 53 { exit(0) }; super.keyDown(with: e) }
    override var canBecomeKey: Bool { true }
}

ctl.refresh()

// park it under the bar on the right, where the widget that opened it lives
// grow and shrink with the list, staying pinned under the bar on the right
ctl.resize = {
    let h = windowHeight(ctl.items.count)
    guard abs(h - win.frame.height) > 1 else { return }
    if let s = NSScreen.main {
        let f = s.visibleFrame
        win.setFrame(NSRect(x: f.maxX - W - 24, y: f.maxY - h - 8, width: W, height: h), display: true, animate: true)
    }
    content.needsLayout = true      // layout() repositions everything from bounds
}
if let s = NSScreen.main {
    let f = s.visibleFrame
    win.setFrameOrigin(NSPoint(x: f.maxX - W - 24, y: f.maxY - H0 - 8))
}
win.makeKeyAndOrderFront(nil)
NSApp.activate(ignoringOtherApps: true)

// Click anywhere outside to dismiss, the same contract every other window here
// honours. Armed after a beat because activation can bounce focus at launch,
// which must not count as "clicked away" (clip_picker.swift hit exactly this).
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                                           object: win, queue: .main) { _ in exit(0) }
    if !win.isKeyWindow { win.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
}

// A drop on the bar rewrites list.txt from another process, so an open window has
// to notice. Polled rather than watched: a DispatchSource here needs a live fd and
// a strong reference, and when either lapses it fails silently (clip_watch.swift
// shipped that bug once already).
var lastStamp = (try? FileManager.default.attributesOfItem(atPath: listPath)[.modificationDate] as? Date) ?? nil
Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
    let now = (try? FileManager.default.attributesOfItem(atPath: listPath)[.modificationDate] as? Date) ?? nil
    if now != lastStamp { lastStamp = now; ctl.refresh() }
}

// Esc closes, matching every other window in the app
NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
    if e.keyCode == 53 { exit(0) }
    return e
}

app.run()
