// clip_picker [--title T] <file1> [file2 ...] — centered, autofocused picker.
// Type to filter, ↑/↓ + Enter selects (prints the chosen path), Esc cancels,
// click selects, clicking anywhere outside dismisses. Images render thumbnails.
//
// Doubles as the prompt-library picker: same interaction, different title and
// contents, so there is one picker to learn and one to maintain.
import AppKit

var argv = Array(CommandLine.arguments.dropFirst())
var windowTitle = "Clipboard"
if let i = argv.firstIndex(of: "--title"), i + 1 < argv.count {
    windowTitle = argv[i + 1]
    argv.removeSubrange(i...(i + 1))
}
let files = argv
guard !files.isEmpty else { exit(1) }

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let bgColor = NSColor(calibratedRed: 0.09, green: 0.05, blue: 0.16, alpha: 1)
let rowColor = NSColor(calibratedRed: 0.14, green: 0.09, blue: 0.25, alpha: 1)
let selColor = NSColor(calibratedRed: 0.22, green: 0.13, blue: 0.38, alpha: 1)
let pink = NSColor(calibratedRed: 1.0, green: 0.43, blue: 0.78, alpha: 1)
let dim = NSColor(calibratedWhite: 0.55, alpha: 1)
let mono = NSFont(name: "JetBrainsMono Nerd Font", size: 13) ?? .monospacedSystemFont(ofSize: 13, weight: .regular)

let W: CGFloat = 480, ROW_H: CGFloat = 56, GAP: CGFloat = 8, PAD: CGFloat = 16
let SEARCH_H: CGFloat = 30
let MAX_ROWS = 7
// previews are read once: they are what gets drawn AND what gets searched
struct Entry { let path: String; let preview: String; let haystack: String }

let entries: [Entry] = files.map { path in
    if path.hasSuffix(".png") {
        let d = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return Entry(path: path, preview: "image · \(d.map { f.string(from: $0) } ?? "")", haystack: "image")
    }
    var text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    text = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
    var short = text
    if short.count > 44 { short = String(short.prefix(44)) + "…" }
    return Entry(path: path, preview: short, haystack: text.lowercased())
}

let rowsShown = min(entries.count, MAX_ROWS)
let H = CGFloat(rowsShown) * (ROW_H + GAP) + 64 + SEARCH_H + 8

final class RowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {}
    override func drawBackground(in dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 0, dy: GAP / 2)
        let path = NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12)
        (isSelected ? selColor : rowColor).setFill()
        path.fill()
        if isSelected {
            pink.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }
}

final class Picker: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var shown: [Entry]
    var table: NSTableView!
    var countLabel: NSTextField!
    init(_ e: [Entry]) { shown = e }

    func filter(_ q: String) {
        let needle = q.lowercased().trimmingCharacters(in: .whitespaces)
        shown = needle.isEmpty ? entries : entries.filter { $0.haystack.contains(needle) }
        table.reloadData()
        if !shown.isEmpty { table.selectRowIndexes([0], byExtendingSelection: false) }
        countLabel.stringValue = needle.isEmpty ? "" : "\(shown.count) of \(entries.count)"
    }

    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }
    func tableView(_ t: NSTableView, heightOfRow r: Int) -> CGFloat { ROW_H + GAP }
    func tableView(_ t: NSTableView, rowViewForRow r: Int) -> NSTableRowView? { RowView() }

    func tableView(_ t: NSTableView, viewFor c: NSTableColumn?, row r: Int) -> NSView? {
        let e = shown[r]
        let width = W - 2 * PAD
        let cell = NSView(frame: NSRect(x: 0, y: 0, width: width, height: ROW_H + GAP))

        var textX: CGFloat = 16
        if e.path.hasSuffix(".png"), let img = NSImage(contentsOfFile: e.path) {
            let iv = NSImageView(frame: NSRect(x: 12, y: GAP / 2 + 6, width: 70, height: ROW_H - 12))
            iv.image = img
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.wantsLayer = true
            iv.layer?.cornerRadius = 8
            iv.layer?.masksToBounds = true
            cell.addSubview(iv)
            textX = 94
        }

        let label = NSTextField(labelWithString: e.preview)
        label.font = mono
        label.textColor = NSColor(calibratedWhite: 0.93, alpha: 1)
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: textX, y: (ROW_H + GAP - 18) / 2, width: width - textX - 16, height: 18)
        label.autoresizingMask = [.width]
        cell.addSubview(label)
        return cell
    }

    @objc func pick() {
        let r = table.selectedRow
        if r >= 0 && r < shown.count { print(shown[r].path); exit(0) }
    }
}

let picker = Picker(entries)

// Typing goes to the search field, but the arrow keys and Enter have to keep
// driving the list, so the field forwards those on rather than swallowing them.
final class SearchField: NSTextField {
    var onKey: ((UInt16) -> Bool)?
    override func keyDown(with e: NSEvent) {
        if onKey?(e.keyCode) == true { return }
        super.keyDown(with: e)
    }
}

final class KeyTable: NSTableView {
    var onEnter: (() -> Void)?
    override func keyDown(with e: NSEvent) {
        switch e.keyCode {
        case 36, 76: onEnter?()          // return / keypad enter
        case 53: exit(1)                 // esc
        default: super.keyDown(with: e)
        }
    }
}

let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: W, height: H),
                   styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
win.titleVisibility = .hidden
win.titlebarAppearsTransparent = true
win.level = .floating
win.center()
win.backgroundColor = bgColor
win.appearance = NSAppearance(named: .darkAqua)

let title = NSTextField(labelWithString: windowTitle)
title.font = NSFont(name: "JetBrainsMono Nerd Font Bold", size: 15) ?? .boldSystemFont(ofSize: 15)
title.textColor = pink
title.frame = NSRect(x: PAD + 2, y: H - 36, width: W - 2 * PAD - 90, height: 20)
win.contentView!.addSubview(title)

let countLabel = NSTextField(labelWithString: "")
countLabel.font = mono
countLabel.textColor = dim
countLabel.alignment = .right
countLabel.frame = NSRect(x: W - PAD - 100, y: H - 34, width: 96, height: 16)
win.contentView!.addSubview(countLabel)
picker.countLabel = countLabel

let search = SearchField(frame: NSRect(x: PAD, y: H - 36 - SEARCH_H - 6, width: W - 2 * PAD, height: SEARCH_H))
search.placeholderString = "type to filter"
search.font = mono
search.textColor = NSColor(calibratedWhite: 0.95, alpha: 1)
search.backgroundColor = rowColor
search.drawsBackground = true
search.isBordered = false
search.focusRingType = .none
search.wantsLayer = true
search.layer?.cornerRadius = 8
win.contentView!.addSubview(search)

let col = NSTableColumn(identifier: .init("c"))
col.width = W - 2 * PAD
let tableH = H - 60 - SEARCH_H - 8
let table = KeyTable(frame: NSRect(x: PAD, y: 12, width: W - 2 * PAD, height: tableH))
table.headerView = nil
table.backgroundColor = .clear
table.selectionHighlightStyle = .regular
table.intercellSpacing = .zero
table.style = .plain
table.addTableColumn(col)
table.dataSource = picker
table.delegate = picker
table.target = picker
table.action = #selector(Picker.pick)          // single click selects
table.onEnter = { picker.pick() }
picker.table = table

let scroll = NSScrollView(frame: table.frame)
scroll.documentView = table
scroll.drawsBackground = false
scroll.hasVerticalScroller = false
win.contentView!.addSubview(scroll)

table.selectRowIndexes([0], byExtendingSelection: false)

search.onKey = { code in
    switch code {
    case 53: exit(1)                                  // esc
    case 36, 76: picker.pick(); return true           // enter picks the selection
    case 125:                                         // down
        let n = min(table.selectedRow + 1, picker.shown.count - 1)
        if n >= 0 { table.selectRowIndexes([n], byExtendingSelection: false); table.scrollRowToVisible(n) }
        return true
    case 126:                                         // up
        let n = max(table.selectedRow - 1, 0)
        if picker.shown.count > 0 { table.selectRowIndexes([n], byExtendingSelection: false); table.scrollRowToVisible(n) }
        return true
    default: return false
    }
}

class SearchDelegate: NSObject, NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        picker.filter((obj.object as? NSTextField)?.stringValue ?? "")
    }
}
let searchDelegate = SearchDelegate()
search.delegate = searchDelegate

// dismiss when the user clicks anywhere outside (window loses key status).
// Armed only after a short grace period — activation from a hotkey daemon can
// bounce focus for a moment right at launch, which must not count as "outside".
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                                           object: win, queue: .main) { _ in exit(1) }
    if !win.isKeyWindow { win.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
}

win.makeKeyAndOrderFront(nil)
win.makeFirstResponder(search)
NSApp.activate(ignoringOtherApps: true)
app.run()
exit(1)
