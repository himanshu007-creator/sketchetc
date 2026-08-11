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

// The picker is a non-activating panel, not a window, and that is the whole fix
// for "the list appears but nothing responds".
//
// skhd launches us from a background daemon, and macOS 26 will not let such a
// process steal activation: NSApp.activate(ignoringOtherApps:) is deprecated and
// simply did nothing. Verified through the real Option+V hotkey — the picker was
// on screen while the terminal stayed frontmost, so clicks fell through and every
// keystroke went to the app behind it. Raising to .regular did not help either.
//
// A .nonactivatingPanel can become key WITHOUT its app becoming active, which is
// how Spotlight-style overlays work. canBecomeKey must be forced because a
// borderless-ish panel refuses key status by default.
final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

let bgColor = NSColor(calibratedRed: 0.09, green: 0.05, blue: 0.16, alpha: 1)
let rowColor = NSColor(calibratedRed: 0.14, green: 0.09, blue: 0.25, alpha: 1)
let selColor = NSColor(calibratedRed: 0.22, green: 0.13, blue: 0.38, alpha: 1)
let pink = NSColor(calibratedRed: 1.0, green: 0.43, blue: 0.78, alpha: 1)
let dim = NSColor(calibratedWhite: 0.55, alpha: 1)
let mono = NSFont(name: "JetBrainsMono Nerd Font", size: 13) ?? .monospacedSystemFont(ofSize: 13, weight: .regular)

// Rows were 56pt tall with a 7-row cap, so a 20-entry history showed a handful
// of very fat rows and everything else needed scrolling. Tighter rows fit more
// of the list on screen without feeling cramped.
let W: CGFloat = 520, ROW_H: CGFloat = 38, GAP: CGFloat = 6, PAD: CGFloat = 16
let SEARCH_H: CGFloat = 30
let MAX_ROWS = 10
// header (title + search + gaps) and the bottom padding, measured once
let CHROME_H: CGFloat = 34 + 8 + SEARCH_H + 10 + PAD
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
let H = CGFloat(rowsShown) * (ROW_H + GAP) + CHROME_H

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
//
// This used to override NSTextField.keyDown, which never runs: while a text
// field is being edited AppKit hands the keys to the window's field editor, an
// NSTextView, so the override was dead code and arrows/Enter/Esc did nothing at
// all. doCommandBy is the hook that actually fires — the same one entry_box.swift
// already uses.
final class SearchField: NSTextField {}

// NSTextField draws its text hard against the left edge, so the placeholder and
// the caret sat flush on the border with no breathing room. There is no padding
// property: the cell has to inset the drawing, editing AND selection rects, or
// the text jumps sideways the moment you start typing.
final class PaddedFieldCell: NSTextFieldCell {
    var pad = NSSize(width: 10, height: 0)
    private func inset(_ r: NSRect) -> NSRect {
        // vertical centring is done here too, so the glyphs sit mid-field
        let h = ceil(font?.boundingRectForFont.height ?? r.height)
        let y = r.origin.y + max(0, (r.height - h) / 2)
        return NSRect(x: r.origin.x + pad.width, y: y,
                      width: max(0, r.width - pad.width * 2), height: h)
    }
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        super.drawingRect(forBounds: inset(rect))
    }
    override func edit(withFrame rect: NSRect, in view: NSView, editor: NSText,
                       delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: inset(rect), in: view, editor: editor, delegate: delegate, event: event)
    }
    override func select(withFrame rect: NSRect, in view: NSView, editor: NSText,
                         delegate: Any?, start: Int, length: Int) {
        super.select(withFrame: inset(rect), in: view, editor: editor,
                     delegate: delegate, start: start, length: length)
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

let win = PickerPanel(contentRect: NSRect(x: 0, y: 0, width: W, height: H),
                      styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
                      backing: .buffered, defer: false)
win.titleVisibility = .hidden
win.titlebarAppearsTransparent = true
win.isFloatingPanel = true
win.becomesKeyOnlyIfNeeded = false
win.hidesOnDeactivate = false
win.level = .floating
win.center()
win.backgroundColor = bgColor
win.appearance = NSAppearance(named: .darkAqua)

// Everything below is laid out from contentView.bounds, never from the H
// constant. With .titled + .fullSizeContentView AppKit sizes the content view to
// the FULL window frame including the title bar, so constant-based frames put
// the header where the title bar is and let the list ride up over it — which is
// exactly why the first row sat on top of the search box.
let content = win.contentView!
let CH = content.bounds.height
let CW = content.bounds.width

let title = NSTextField(labelWithString: windowTitle)
title.font = NSFont(name: "JetBrainsMono Nerd Font Bold", size: 15) ?? .boldSystemFont(ofSize: 15)
title.textColor = pink
title.frame = NSRect(x: PAD + 2, y: CH - 34, width: CW - 2 * PAD - 90, height: 20)
title.autoresizingMask = [.minYMargin]
content.addSubview(title)

let countLabel = NSTextField(labelWithString: "")
countLabel.font = mono
countLabel.textColor = dim
countLabel.alignment = .right
countLabel.frame = NSRect(x: CW - PAD - 100, y: CH - 32, width: 96, height: 16)
countLabel.autoresizingMask = [.minXMargin, .minYMargin]
content.addSubview(countLabel)
picker.countLabel = countLabel

let search = SearchField(frame: NSRect(x: PAD, y: CH - 34 - SEARCH_H - 8, width: CW - 2 * PAD, height: SEARCH_H))
search.autoresizingMask = [.width, .minYMargin]
search.cell = PaddedFieldCell()
search.placeholderString = "type to filter"
search.font = mono
search.isEditable = true
search.isSelectable = true
search.textColor = NSColor(calibratedWhite: 0.95, alpha: 1)
// The rounded pill is drawn by the layer, not by the cell. A cell-drawn
// background is repainted by the field editor as a hard rectangle the moment you
// start typing, which squared off the corners and swallowed the padding.
search.drawsBackground = false
search.isBordered = false
search.focusRingType = .none
search.wantsLayer = true
search.layer?.cornerRadius = 8
search.layer?.backgroundColor = rowColor.cgColor
content.addSubview(search)

let col = NSTableColumn(identifier: .init("c"))
col.width = CW - 2 * PAD
// the list gets whatever is left under the search box, and no more
let listTop = search.frame.minY - 10
let table = KeyTable(frame: NSRect(x: 0, y: 0, width: CW - 2 * PAD, height: listTop - PAD))
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

let scroll = NSScrollView(frame: NSRect(x: PAD, y: PAD, width: CW - 2 * PAD, height: listTop - PAD))
scroll.documentView = table
scroll.drawsBackground = false
scroll.hasVerticalScroller = true
scroll.autohidesScrollers = true
scroll.autoresizingMask = [.width, .height]
content.addSubview(scroll)

table.selectRowIndexes([0], byExtendingSelection: false)

func moveSelection(_ delta: Int) {
    guard picker.shown.count > 0 else { return }
    let cur = table.selectedRow
    let n = min(max(cur + delta, 0), picker.shown.count - 1)
    table.selectRowIndexes([n], byExtendingSelection: false)
    table.scrollRowToVisible(n)
}

class SearchDelegate: NSObject, NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        picker.filter((obj.object as? NSTextField)?.stringValue ?? "")
    }
    // Arrows, Enter and Esc arrive here as editing commands rather than as
    // keyDown. Returning true consumes them so they never reach the field and
    // move the text caret instead of the selection.
    func control(_ c: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        switch sel {
        case #selector(NSResponder.moveDown(_:)):       moveSelection(1);  return true
        case #selector(NSResponder.moveUp(_:)):         moveSelection(-1); return true
        case #selector(NSResponder.insertNewline(_:)):  picker.pick();     return true
        case #selector(NSResponder.cancelOperation(_:)): exit(1)
        // page keys and home/end are free wins once we are already here
        case #selector(NSResponder.scrollPageDown(_:)): moveSelection(8);  return true
        case #selector(NSResponder.scrollPageUp(_:)):   moveSelection(-8); return true
        default: return false
        }
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
