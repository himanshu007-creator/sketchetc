// journal_win <draftPath> <rootDir> [headerInfo]
// One window, two modes:
//   Work     · daily log with per-day locking. Tree of locked entries on the
//              left (pinned "writing" row on top), editor + live rendered
//              preview on the right; locked entries render read-only.
//   Personal · scratchpad notes. File list left, renameable title + editor
//              right, debounced autosave (1s after typing stops).
// Prints "FINALIZE" and exits 0 when a work entry is finalized.
import AppKit

guard CommandLine.arguments.count >= 3 else { print("usage: journal_win draft root [header]"); exit(2) }
let draftPath = CommandLine.arguments[1]
let rootDir = CommandLine.arguments[2]
let headerInfo = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "Writing"
let personalDir = rootDir + "/personal"

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Accessory apps have no menu bar, but text views only get ⌘C/⌘V/⌘X/⌘A/undo
// through an Edit menu's key equivalents — so install a minimal hidden one.
let mainMenu = NSMenu()
let editHolder = NSMenuItem()
mainMenu.addItem(editHolder)
let editMenu = NSMenu(title: "Edit")
editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
editHolder.submenu = editMenu
app.mainMenu = mainMenu

let bg = NSColor(calibratedRed: 0.09, green: 0.05, blue: 0.16, alpha: 1)
let panel = NSColor(calibratedRed: 0.14, green: 0.09, blue: 0.25, alpha: 1)
let panelDeep = NSColor(calibratedRed: 0.11, green: 0.07, blue: 0.20, alpha: 1)
let pink = NSColor(calibratedRed: 1.0, green: 0.43, blue: 0.78, alpha: 1)
let cyan = NSColor(calibratedRed: 0.04, green: 0.83, blue: 0.83, alpha: 1)
let textC = NSColor(calibratedWhite: 0.93, alpha: 1)
let dimC = NSColor(calibratedWhite: 1, alpha: 0.45)
let mono = NSFont(name: "JetBrainsMono Nerd Font", size: 13.5) ?? .monospacedSystemFont(ofSize: 13.5, weight: .regular)
let monoSmall = NSFont(name: "JetBrainsMono Nerd Font", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular)

let W: CGFloat = 1000, H: CGFloat = 640, PAD: CGFloat = 22, TOP: CGFloat = 64

// ---------- markdown renderer ----------
func inlineRuns(_ line: String, base: NSFont, color: NSColor) -> NSAttributedString {
    let out = NSMutableAttributedString()
    func emit(_ s: Substring, bold: Bool = false, code: Bool = false) {
        guard !s.isEmpty else { return }
        var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: color, .font: base]
        if bold, let d = NSFont(descriptor: base.fontDescriptor.withSymbolicTraits(.bold), size: base.pointSize) {
            attrs[.font] = d
        }
        if code {
            attrs[.font] = NSFont(name: "JetBrainsMono Nerd Font", size: base.pointSize - 1) ?? base
            attrs[.foregroundColor] = cyan
            attrs[.backgroundColor] = panelDeep
        }
        out.append(NSAttributedString(string: String(s), attributes: attrs))
    }
    func emitBold(_ chunk: Substring) {
        var r = chunk
        while let open = r.range(of: "**"), let close = r[open.upperBound...].range(of: "**") {
            emit(r[..<open.lowerBound])
            emit(r[open.upperBound..<close.lowerBound], bold: true)
            r = r[close.upperBound...]
        }
        emit(r)
    }
    var rest = Substring(line)
    while !rest.isEmpty {
        if let tick = rest.firstIndex(of: "`"),
           let close = rest[rest.index(after: tick)...].firstIndex(of: "`") {
            emitBold(rest[..<tick])
            emit(rest[rest.index(after: tick)..<close], code: true)
            rest = rest[rest.index(after: close)...]
        } else {
            emitBold(rest); break
        }
    }
    return out
}

func renderMarkdown(_ src: String) -> NSAttributedString {
    let pre = src
        .replacingOccurrences(of: "- [x]", with: "☑", options: .caseInsensitive)
        .replacingOccurrences(of: "- [ ]", with: "☐")
    let body = NSFont.systemFont(ofSize: 14)
    let out = NSMutableAttributedString()
    var inCode = false
    for raw in pre.components(separatedBy: "\n") {
        if raw.hasPrefix("```") { inCode.toggle(); continue }
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = 5
        if inCode {
            out.append(NSAttributedString(string: raw + "\n", attributes: [
                .font: monoSmall, .foregroundColor: cyan, .backgroundColor: panelDeep, .paragraphStyle: para]))
            continue
        }
        var line = raw
        var font = body
        var color = textC
        var prefix = ""
        if line.hasPrefix("# ") { line = String(line.dropFirst(2)); font = .boldSystemFont(ofSize: 22); color = pink; para.paragraphSpacingBefore = 10 }
        else if line.hasPrefix("## ") { line = String(line.dropFirst(3)); font = .boldSystemFont(ofSize: 18); para.paragraphSpacingBefore = 8 }
        else if line.hasPrefix("### ") { line = String(line.dropFirst(4)); font = .boldSystemFont(ofSize: 15.5); para.paragraphSpacingBefore = 6 }
        else if line.hasPrefix("> ") { line = "▎ " + line.dropFirst(2); color = dimC }
        else if line == "---" || line == "***" { line = "──────────────"; color = NSColor(calibratedWhite: 1, alpha: 0.2) }
        else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            prefix = "•  "; line = String(line.dropFirst(2))
            para.headIndent = 18; para.firstLineHeadIndent = 4
        }
        else if line.hasPrefix("☑") || line.hasPrefix("☐") {
            para.headIndent = 18; para.firstLineHeadIndent = 4
        }
        let rendered = NSMutableAttributedString()
        if !prefix.isEmpty {
            rendered.append(NSAttributedString(string: prefix, attributes: [.font: font, .foregroundColor: pink]))
        }
        rendered.append(inlineRuns(line, base: font, color: color))
        rendered.append(NSAttributedString(string: "\n"))
        rendered.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: rendered.length))
        out.append(rendered)
    }
    return out
}

// ---------- work entry tree ----------
final class Node {
    let label: String
    let path: String?      // "WRITE" sentinel = the editing row
    var children: [Node]
    init(_ label: String, path: String? = nil, children: [Node] = []) {
        self.label = label; self.path = path; self.children = children
    }
}

func workTree() -> [Node] {
    let fm = FileManager.default
    let years = ((try? fm.contentsOfDirectory(atPath: rootDir)) ?? [])
        .filter { $0.count == 4 && Int($0) != nil }.sorted(by: >)
    let mf = DateFormatter(); mf.dateFormat = "MM"
    let mo = DateFormatter(); mo.dateFormat = "MMMM"
    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
    let od = DateFormatter(); od.dateFormat = "EEE dd"
    func dayNodes(_ y: String, _ m: String) -> [Node] {
        let dir = "\(rootDir)/\(y)/\(m)"
        let days = ((try? fm.contentsOfDirectory(atPath: dir)) ?? []).filter { $0.hasSuffix(".md") }.sorted(by: >)
        return days.map { d in
            let stem = String(d.dropLast(3))
            let label = df.date(from: "\(y)-\(m)-\(stem)").map { od.string(from: $0) } ?? stem
            return Node(label, path: "\(dir)/\(d)")
        }
    }
    func monthNodes(_ y: String) -> [Node] {
        let months = ((try? fm.contentsOfDirectory(atPath: "\(rootDir)/\(y)")) ?? [])
            .filter { $0 != "personal" && $0 != "index.log" }.sorted(by: >)
        return months.map { m in
            Node(mf.date(from: m).map { mo.string(from: $0) } ?? m, children: dayNodes(y, m))
        }
    }
    var roots: [Node] = [Node("✎  " + headerInfo, path: "WRITE")]
    if years.count == 1 { roots += monthNodes(years[0]) }
    else { roots += years.map { Node($0, children: monthNodes($0)) } }
    return roots
}

// ---------- search ----------
// The sidebar is built entirely from [Node], so searching does not need a new
// view: it just swaps what the outline is showing. A result node carries the
// file path, so selecting one goes through exactly the same read pane as
// clicking a date does.
func searchTree(_ q: String) -> [Node] {
    let needle = q.lowercased().trimmingCharacters(in: .whitespaces)
    guard !needle.isEmpty else { return workTree() }
    let fm = FileManager.default

    var files: [String] = []
    if let e = fm.enumerator(atPath: rootDir) {
        for case let f as String in e where f.hasSuffix(".md") { files.append(rootDir + "/" + f) }
    }

    var hits: [Node] = []
    for path in files.sorted(by: >) {
        let name = (path as NSString).lastPathComponent
        // date sits in the path as yyyy/MM/dd.md, so searching "2026-07" or a
        // filename works without opening the file at all
        let where_ = path.replacingOccurrences(of: rootDir, with: "")
        let dateish = where_.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".md", with: "")
        let body = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""

        var snippet: String? = nil
        if dateish.lowercased().contains(needle) || name.lowercased().contains(needle) {
            snippet = body.split(separator: "\n").first.map(String.init) ?? ""
        } else {
            for line in body.split(separator: "\n") where line.lowercased().contains(needle) {
                snippet = String(line); break
            }
        }
        guard var s = snippet else { continue }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "# -[]x")).trimmingCharacters(in: .whitespaces)
        if s.count > 46 { s = String(s.prefix(46)) + "…" }
        let label = dateish.trimmingCharacters(in: CharacterSet(charactersIn: "-")) + (s.isEmpty ? "" : "  ·  " + s)
        hits.append(Node(label, path: path))
    }
    if hits.isEmpty { return [Node("no matches for \"\(q)\"")] }
    return hits
}

// ---------- personal notes ----------
func noteFiles() -> [String] {
    let fm = FileManager.default
    try? fm.createDirectory(atPath: personalDir, withIntermediateDirectories: true)
    let names = ((try? fm.contentsOfDirectory(atPath: personalDir)) ?? []).filter { $0.hasSuffix(".md") }
    return names.sorted { a, b in
        let ma = (try? fm.attributesOfItem(atPath: personalDir + "/" + a)[.modificationDate] as? Date) ?? nil
        let mb = (try? fm.attributesOfItem(atPath: personalDir + "/" + b)[.modificationDate] as? Date) ?? nil
        return (ma ?? .distantPast) > (mb ?? .distantPast)
    }
}

// ---------- controller ----------
final class Controller: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate,
                        NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate,
                        NSTextFieldDelegate {
    var workRoots: [Node] = []
    var notes: [String] = []
    var currentNote: String?
    var saveTimer: Timer?

    var outline: NSOutlineView!
    var editor: NSTextView!, preview: NSTextView!, readPane: NSTextView!
    var editSplit: NSView!, readWrap: NSView!
    var workButtons: [NSButton] = []

    var noteTable: NSTableView!
    var noteTitle: NSTextField!
    var noteEditor: NSTextView!
    var savedLabel: NSTextField!

    var workView: NSView!, personalView: NSView!

    // ----- mode switch -----
    @objc func switchMode(_ seg: NSSegmentedControl) {
        flushNote()
        let personal = seg.selectedSegment == 1
        workView.isHidden = personal
        personalView.isHidden = !personal
        if personal { reloadNotes(keepSelection: true) }
    }

    // ----- search -----
    // Guarded on the field's identity: the window has other text fields (note
    // titles) and they must not be treated as search input.
    func controlTextDidChange(_ note: Notification) {
        guard let f = note.object as? NSTextField, f.identifier?.rawValue == "jsearch" else { return }
        searchChanged(f)
    }

    @objc func searchChanged(_ sender: NSTextField) {
        let q = sender.stringValue
        if q.trimmingCharacters(in: .whitespaces).isEmpty {
            reloadWork()
            return
        }
        workRoots = searchTree(q)
        outline.reloadData()
        if !workRoots.isEmpty, workRoots[0].path != nil {
            outline.selectRowIndexes([0], byExtendingSelection: false)
        }
    }

    // ----- work -----
    func reloadWork() {
        workRoots = workTree()
        outline.reloadData()
        for n in workRoots { outline.expandItem(n) }
        outline.selectRowIndexes([0], byExtendingSelection: false)
        showWrite()
    }
    func showWrite() {
        editSplit.isHidden = false
        readWrap.isHidden = true
        workButtons.forEach { $0.isHidden = false }
    }
    func showLocked(_ path: String) {
        editSplit.isHidden = true
        readWrap.isHidden = false
        workButtons.forEach { $0.isHidden = true }
        let src = (try? String(contentsOfFile: path, encoding: .utf8)) ?? "(unreadable)"
        readPane.textStorage?.setAttributedString(renderMarkdown(src))
    }
    func outlineView(_ o: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? Node)?.children.count ?? workRoots.count
    }
    func outlineView(_ o: NSOutlineView, child i: Int, ofItem item: Any?) -> Any {
        (item as? Node)?.children[i] ?? workRoots[i]
    }
    func outlineView(_ o: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !((item as! Node).children.isEmpty)
    }
    func outlineView(_ o: NSOutlineView, viewFor c: NSTableColumn?, item: Any) -> NSView? {
        let n = item as! Node
        let icon = n.path == "WRITE" ? "" : (n.path == nil ? "󰉋 " : "󰧮 ")
        let l = NSTextField(labelWithString: icon + n.label)
        l.font = monoSmall
        l.textColor = n.path == "WRITE" ? pink : (n.path == nil ? cyan : textC)
        l.lineBreakMode = .byTruncatingTail
        return l
    }
    func outlineViewSelectionDidChange(_ n: Notification) {
        guard let node = outline.item(atRow: outline.selectedRow) as? Node else { return }
        if node.path == "WRITE" { showWrite() }
        else if let p = node.path { showLocked(p) }
    }
    @objc func saveDraft() {
        try? editor.string.write(toFile: draftPath, atomically: true, encoding: .utf8)
        NSSound(named: "Pop")?.play()
    }
    @objc func doFinalize() {
        try? editor.string.write(toFile: draftPath, atomically: true, encoding: .utf8)
        print("FINALIZE")
        exit(0)
    }
    @objc func doClose() { flushNote(); exit(1) }

    // ----- personal -----
    func reloadNotes(keepSelection: Bool) {
        let sel = currentNote
        notes = noteFiles()
        noteTable.reloadData()
        if keepSelection, let s = sel, let i = notes.firstIndex(of: s) {
            noteTable.selectRowIndexes([i], byExtendingSelection: false)
        } else if !notes.isEmpty {
            noteTable.selectRowIndexes([0], byExtendingSelection: false)
            loadNote(notes[0])
        } else {
            currentNote = nil
            noteTitle.stringValue = ""
            noteEditor.string = ""
        }
    }
    func numberOfRows(in t: NSTableView) -> Int { notes.count }
    func tableView(_ t: NSTableView, viewFor c: NSTableColumn?, row r: Int) -> NSView? {
        let l = NSTextField(labelWithString: "󰧮 " + String(notes[r].dropLast(3)))
        l.font = monoSmall
        l.textColor = textC
        l.lineBreakMode = .byTruncatingTail
        return l
    }
    func tableViewSelectionDidChange(_ n: Notification) {
        guard noteTable.selectedRow >= 0, noteTable.selectedRow < notes.count else { return }
        flushNote()
        loadNote(notes[noteTable.selectedRow])
    }
    func loadNote(_ name: String) {
        currentNote = name
        noteTitle.stringValue = String(name.dropLast(3))
        noteEditor.string = (try? String(contentsOfFile: personalDir + "/" + name, encoding: .utf8)) ?? ""
        savedLabel.stringValue = ""
    }
    @objc func newNote() {
        flushNote()
        var name = "untitled.md"; var n = 1
        while FileManager.default.fileExists(atPath: personalDir + "/" + name) {
            n += 1; name = "untitled-\(n).md"
        }
        FileManager.default.createFile(atPath: personalDir + "/" + name, contents: Data())
        reloadNotes(keepSelection: false)
        if let i = notes.firstIndex(of: name) {
            noteTable.selectRowIndexes([i], byExtendingSelection: false)
            loadNote(name)
        }
        win.makeFirstResponder(noteTitle)
    }
    @objc func deleteNote() {
        guard let cur = currentNote else { return }
        let a = NSAlert()
        a.messageText = "Delete \"\(cur.dropLast(3))\"?"
        a.addButton(withTitle: "Delete"); a.addButton(withTitle: "Cancel")
        if a.runModal() == .alertFirstButtonReturn {
            try? FileManager.default.removeItem(atPath: personalDir + "/" + cur)
            currentNote = nil
            reloadNotes(keepSelection: false)
        }
    }
    func flushNote() {
        saveTimer?.invalidate()
        guard let cur = currentNote else { return }
        try? noteEditor.string.write(toFile: personalDir + "/" + cur, atomically: true, encoding: .utf8)
    }
    func noteSaved() {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        savedLabel.stringValue = "saved · " + f.string(from: Date())
    }
    // rename on Enter / focus-out
    func controlTextDidEndEditing(_ n: Notification) {
        guard let cur = currentNote else { return }
        var t = noteTitle.stringValue.trimmingCharacters(in: .whitespaces)
        t = t.replacingOccurrences(of: "/", with: "-")
        guard !t.isEmpty, t + ".md" != cur else { return }
        var name = t + ".md"; var k = 1
        while FileManager.default.fileExists(atPath: personalDir + "/" + name) {
            k += 1; name = "\(t)-\(k).md"
        }
        flushNote()
        try? FileManager.default.moveItem(atPath: personalDir + "/" + cur, toPath: personalDir + "/" + name)
        currentNote = name
        reloadNotes(keepSelection: true)
        noteTitle.stringValue = String(name.dropLast(3))
    }

    // ----- editors -----
    func textDidChange(_ n: Notification) {
        guard let tv = n.object as? NSTextView else { return }
        if tv == editor {
            preview.textStorage?.setAttributedString(renderMarkdown(tv.string))
        }
        if tv == noteEditor, currentNote != nil {
            saveTimer?.invalidate()
            saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.flushNote()
                self?.noteSaved()
            }
        }
    }
}
let ctl = Controller()

// ---------- window ----------
let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: W, height: H),
                   styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
win.titleVisibility = .hidden
win.titlebarAppearsTransparent = true
win.isMovableByWindowBackground = true
win.level = .floating
win.center()
win.backgroundColor = bg
win.appearance = NSAppearance(named: .darkAqua)
let content = win.contentView!

let title = NSTextField(labelWithString: "Journal")
title.font = NSFont(name: "JetBrainsMono Nerd Font Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
title.textColor = pink
title.frame = NSRect(x: 96, y: H - 42, width: 130, height: 22)
content.addSubview(title)

let tabs = NSSegmentedControl(labels: ["Work", "Personal"], trackingMode: .selectOne,
                              target: ctl, action: #selector(Controller.switchMode(_:)))
tabs.selectedSegment = 0
tabs.frame = NSRect(x: W - PAD - 200, y: H - 42, width: 200, height: 24)
content.addSubview(tabs)

func makeText(_ frame: NSRect, editable: Bool, monoFont: Bool) -> (NSScrollView, NSTextView) {
    let scroll = NSScrollView(frame: frame)
    scroll.hasVerticalScroller = true
    scroll.borderType = .noBorder
    scroll.wantsLayer = true
    scroll.layer?.cornerRadius = 10
    let tv = NSTextView(frame: NSRect(origin: .zero, size: frame.size))
    tv.autoresizingMask = [.width]
    tv.font = monoFont ? mono : NSFont.systemFont(ofSize: 14)
    tv.backgroundColor = editable ? panel : panelDeep
    tv.textColor = textC
    tv.insertionPointColor = pink
    tv.textContainerInset = NSSize(width: 14, height: 14)
    tv.isRichText = false
    tv.isEditable = editable
    tv.allowsUndo = editable
    scroll.documentView = tv
    return (scroll, tv)
}
func mkButton(_ label: String, x: CGFloat, y: CGFloat, w: CGFloat, action: Selector, key: String = "") -> NSButton {
    let b = NSButton(title: label, target: ctl, action: action)
    b.bezelStyle = .rounded
    b.keyEquivalent = key
    b.frame = NSRect(x: x, y: y, width: w, height: 32)
    return b
}

let listW: CGFloat = 240
let rightX = PAD + listW + 14
let rightW = W - PAD - rightX
let paneY: CGFloat = 64
let paneH = H - TOP - paneY - 14
let halfW = (rightW - 10) / 2

// ===== Work view =====
let workView = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H - TOP))
let outline = NSOutlineView()
let ocol = NSTableColumn(identifier: .init("t")); ocol.width = listW - 24
outline.headerView = nil
outline.backgroundColor = panel
outline.addTableColumn(ocol)
outline.outlineTableColumn = ocol
outline.dataSource = ctl
outline.delegate = ctl
outline.rowHeight = 24
outline.indentationPerLevel = 13
// search sits above the tree, where you would reach for it
let jsearch = NSTextField(frame: NSRect(x: PAD, y: H - TOP - 40, width: listW, height: 26))
jsearch.identifier = NSUserInterfaceItemIdentifier("jsearch")
jsearch.placeholderString = "search entries"
jsearch.font = monoSmall
jsearch.textColor = textC
jsearch.backgroundColor = panelDeep
jsearch.drawsBackground = true
jsearch.isBordered = false
jsearch.focusRingType = .none
jsearch.wantsLayer = true
jsearch.layer?.cornerRadius = 8
jsearch.target = ctl
jsearch.action = #selector(Controller.searchChanged(_:))
jsearch.delegate = ctl
workView.addSubview(jsearch)

let oScroll = NSScrollView(frame: NSRect(x: PAD, y: 20, width: listW, height: H - TOP - 68))
oScroll.documentView = outline
oScroll.hasVerticalScroller = true
oScroll.wantsLayer = true
oScroll.layer?.cornerRadius = 10
oScroll.drawsBackground = true
oScroll.backgroundColor = panel
workView.addSubview(oScroll)

let editSplit = NSView(frame: NSRect(x: rightX, y: 0, width: rightW, height: H - TOP))
let (eScroll, editor) = makeText(NSRect(x: 0, y: paneY, width: halfW, height: paneH), editable: true, monoFont: true)
let (vScroll, preview) = makeText(NSRect(x: halfW + 10, y: paneY, width: halfW, height: paneH), editable: false, monoFont: false)
editor.delegate = ctl
editor.string = (try? String(contentsOfFile: draftPath, encoding: .utf8)) ?? "- "
preview.textStorage?.setAttributedString(renderMarkdown(editor.string))
editSplit.addSubview(eScroll); editSplit.addSubview(vScroll)
workView.addSubview(editSplit)

let readWrap = NSView(frame: NSRect(x: rightX, y: 0, width: rightW, height: H - TOP))
readWrap.isHidden = true
let (rScroll, readPane) = makeText(NSRect(x: 0, y: 20, width: rightW, height: H - TOP - 34), editable: false, monoFont: false)
readWrap.addSubview(rScroll)
workView.addSubview(readWrap)

let bFinal = mkButton("Finalize & lock", x: W - PAD - 150, y: 16, w: 150, action: #selector(Controller.doFinalize))
let bSave = mkButton("Save draft", x: W - PAD - 296, y: 16, w: 136, action: #selector(Controller.saveDraft), key: "s")
let bClose = mkButton("Close", x: rightX, y: 16, w: 96, action: #selector(Controller.doClose), key: "\u{1b}")
workView.addSubview(bFinal); workView.addSubview(bSave); workView.addSubview(bClose)
content.addSubview(workView)

// ===== Personal view =====
let personalView = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H - TOP))
personalView.isHidden = true
let noteTable = NSTableView()
let ncol = NSTableColumn(identifier: .init("n")); ncol.width = listW - 24
noteTable.headerView = nil
noteTable.backgroundColor = panel
noteTable.addTableColumn(ncol)
noteTable.dataSource = ctl
noteTable.delegate = ctl
noteTable.rowHeight = 26
let nScroll = NSScrollView(frame: NSRect(x: PAD, y: 58, width: listW, height: H - TOP - 72))
nScroll.documentView = noteTable
nScroll.hasVerticalScroller = true
nScroll.wantsLayer = true
nScroll.layer?.cornerRadius = 10
nScroll.drawsBackground = true
nScroll.backgroundColor = panel
personalView.addSubview(nScroll)
let bNew = mkButton("New", x: PAD, y: 16, w: 112, action: #selector(Controller.newNote))
let bDel = mkButton("Delete", x: PAD + 122, y: 16, w: 118, action: #selector(Controller.deleteNote))
personalView.addSubview(bNew); personalView.addSubview(bDel)

let noteTitle = NSTextField(frame: NSRect(x: rightX + 2, y: H - TOP - 46, width: rightW - 180, height: 26))
noteTitle.font = NSFont(name: "JetBrainsMono Nerd Font Bold", size: 15) ?? .boldSystemFont(ofSize: 15)
noteTitle.textColor = textC
noteTitle.backgroundColor = .clear
noteTitle.isBordered = false
noteTitle.focusRingType = .none
noteTitle.placeholderString = "note title"
noteTitle.delegate = ctl
personalView.addSubview(noteTitle)

let savedLabel = NSTextField(labelWithString: "")
savedLabel.font = monoSmall
savedLabel.textColor = dimC
savedLabel.alignment = .right
savedLabel.frame = NSRect(x: W - PAD - 170, y: H - TOP - 44, width: 170, height: 20)
personalView.addSubview(savedLabel)

let (neScroll, noteEditor) = makeText(NSRect(x: rightX, y: 16, width: rightW, height: H - TOP - 72), editable: true, monoFont: true)
noteEditor.delegate = ctl
personalView.addSubview(neScroll)
content.addSubview(personalView)

ctl.outline = outline
ctl.editor = editor; ctl.preview = preview; ctl.readPane = readPane
ctl.editSplit = editSplit; ctl.readWrap = readWrap
ctl.workButtons = [bFinal, bSave]
ctl.noteTable = noteTable; ctl.noteTitle = noteTitle
ctl.noteEditor = noteEditor; ctl.savedLabel = savedLabel
ctl.workView = workView; ctl.personalView = personalView

// resizable window: pin lists left, header top, buttons bottom; panes flex
win.styleMask.insert(.resizable)
win.minSize = NSSize(width: 800, height: 520)
title.autoresizingMask = [.minYMargin]
tabs.autoresizingMask = [.minXMargin, .minYMargin]
workView.autoresizingMask = [.width, .height]
personalView.autoresizingMask = [.width, .height]
oScroll.autoresizingMask = [.height]
editSplit.autoresizingMask = [.width, .height]
readWrap.autoresizingMask = [.width, .height]
eScroll.autoresizingMask = [.width, .height]
vScroll.autoresizingMask = [.width, .height]
rScroll.autoresizingMask = [.width, .height]
bFinal.autoresizingMask = [.minXMargin]
bSave.autoresizingMask = [.minXMargin]
nScroll.autoresizingMask = [.height]
neScroll.autoresizingMask = [.width, .height]
noteTitle.autoresizingMask = [.width, .minYMargin]
savedLabel.autoresizingMask = [.minXMargin, .minYMargin]

ctl.reloadWork()
if CommandLine.arguments.contains("--personal") {
    tabs.selectedSegment = 1
    ctl.switchMode(tabs)
}
win.makeKeyAndOrderFront(nil)
win.makeFirstResponder(CommandLine.arguments.contains("--personal") ? noteEditor : editor)
NSApp.activate(ignoringOtherApps: true)
app.run()
exit(1)
