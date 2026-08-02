// theme_win --builtin-dir D --user-dir D --state-cli P --theme N --iconset N
//           --bg HEX --panel HEX --accent1 HEX --accent2 HEX
//
// Theme Studio: browse themes (swatch strips), edit every color with native
// color wells, save custom themes, delete them, and switch iconsets.
//
// Named flags, not positions. Adding two arguments in v1.3.3 shifted every later
// index, the shift was applied as sequential replacements that cascaded, and the
// colour pairs ended up swapped: the studio opened with a pink background and
// nothing complained. Order carries no meaning here now, and a missing flag stops
// the program instead of quietly rendering the wrong colour.
//
// Every path arrives as an argument and every selection is written through
// state_cli.sh. This used to hardcode ~/.config/sketchybar/.theme, which stopped
// being where the bar reads from: you could pick a theme and nothing happened,
// with no error anywhere. Nothing here may know where config lives.
import AppKit

var opts: [String: String] = [:]
var argi = 1
let rawArgs = CommandLine.arguments
while argi < rawArgs.count {
    let a = rawArgs[argi]
    if a.hasPrefix("--"), argi + 1 < rawArgs.count {
        opts[String(a.dropFirst(2))] = rawArgs[argi + 1]
        argi += 2
    } else { argi += 1 }
}
func need(_ k: String) -> String {
    guard let v = opts[k], !v.isEmpty else {
        FileHandle.standardError.write("theme_win: missing --\(k)\n".data(using: .utf8)!)
        exit(2)
    }
    return v
}

let themesDir = need("builtin-dir")     // shipped themes, read only
let userThemesDir = need("user-dir")    // everything we save goes here
let stateCli = need("state-cli")
var activeTheme = need("theme")
let activeIconset = need("iconset")

func color(_ hex: String) -> NSColor {
    var h = hex.replacingOccurrences(of: "0x", with: "")
    if h.count == 8 { h = String(h.dropFirst(2)) }
    let v = UInt32(h, radix: 16) ?? 0x222222
    return NSColor(calibratedRed: CGFloat((v >> 16) & 0xFF) / 255,
                   green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}
func hexRGB(_ c: NSColor) -> String {
    let r = c.usingColorSpace(.deviceRGB) ?? c
    return String(format: "%02x%02x%02x",
                  Int(round(r.redComponent * 255)), Int(round(r.greenComponent * 255)), Int(round(r.blueComponent * 255)))
}

// Mutable: applying a theme restyles this window in place. They used to be
// captured at launch, so the bar recoloured while the window you picked in kept
// its old colours until you closed and reopened it.
var bg = color(need("bg"))
var panel = color(need("panel"))
var accent1 = color(need("accent1"))
var accent2 = color(need("accent2"))
let textC = NSColor(calibratedWhite: 0.93, alpha: 1)
let dimC = NSColor(calibratedWhite: 1, alpha: 0.5)
let mono = NSFont(name: "JetBrainsMono Nerd Font", size: 12.5) ?? .monospacedSystemFont(ofSize: 12.5, weight: .regular)

let ROLES: [(key: String, label: String)] = [
    ("BAR_COLOR", "bar background"), ("ITEM_BG_COLOR", "item pill"),
    ("POPUP_BG", "popup background"), ("POPUP_BORDER", "popup border"),
    ("PINK", "accent 1"), ("CYAN", "accent 2"), ("ORANGE", "warning"),
    ("RED", "critical"), ("PURPLE", "glow"), ("WHITE", "text"),
]
let BUILTIN = ["vice-city", "cyberpunk", "matrix", "catppuccin", "miami-sunset"]

struct Theme { var name: String; var colors: [String: String] }   // VAR -> 0xAARRGGBB

func loadThemes() -> [Theme] {
    let fm = FileManager.default
    // union of shipped and user themes, user first: an edited theme has to beat
    // the built-in of the same name, which is the order the bar resolves them in
    var seen = Set<String>()
    var names: [String] = []
    for dir in [userThemesDir, themesDir] {
        for f in ((try? fm.contentsOfDirectory(atPath: dir)) ?? []).filter({ $0.hasSuffix(".sh") }).sorted()
        where seen.insert(f).inserted { names.append(f) }
    }
    return names.compactMap { f in
        let userPath = userThemesDir + "/" + f
        let path = FileManager.default.fileExists(atPath: userPath) ? userPath : themesDir + "/" + f
        guard let src = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        var colors: [String: String] = [:]
        for line in src.components(separatedBy: "\n") where line.hasPrefix("export ") {
            let kv = line.dropFirst(7).components(separatedBy: "=")
            guard kv.count == 2 else { continue }
            // values carry trailing comments ("0xffff6ec7   # accent 1") — keep the token only
            let val = kv[1].components(separatedBy: "#")[0]
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: " ")[0]
            if !val.isEmpty { colors[kv[0]] = val }
        }
        return Theme(name: String(f.dropLast(3)), colors: colors)
    }
}
var themes = loadThemes()

func shell(_ cmd: String) {
    let p = Process()
    p.launchPath = "/bin/bash"
    p.arguments = ["-c", cmd]
    try? p.run()
}

func writeTheme(_ t: Theme) {
    var out = "#!/bin/bash\n# \(t.name) · made in Theme Studio\n"
    for (k, _) in ROLES { out += "export \(k)=\(t.colors[k] ?? "0xffffffff")\n" }
    try? FileManager.default.createDirectory(atPath: userThemesDir, withIntermediateDirectories: true)
    try? out.write(toFile: userThemesDir + "/" + t.name + ".sh", atomically: true, encoding: .utf8)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let W: CGFloat = 780, H: CGFloat = 610, PAD: CGFloat = 20, LIST_W: CGFloat = 240
let FOOT: CGFloat = 92   // global footer height (iconset + settings)

// theme-colored selection instead of the system accent
final class Row: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        let r = bounds.insetBy(dx: 3, dy: 2)
        let p = NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8)
        accent1.withAlphaComponent(0.22).setFill(); p.fill()
        accent1.withAlphaComponent(0.9).setStroke(); p.lineWidth = 1.5; p.stroke()
    }
}

final class Ctl: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var table: NSTableView!
    var wells: [String: NSColorWell] = [:]
    var nameField: NSTextField!
    var deleteBtn: NSButton!
    var applyBtn: NSButton!
    var lockLabel: NSTextField!
    var current: Int = 0
    var locked: Bool { BUILTIN.contains(themes[current].name) }

    func numberOfRows(in t: NSTableView) -> Int { themes.count }
    func tableView(_ t: NSTableView, heightOfRow r: Int) -> CGFloat { 34 }
    func tableView(_ t: NSTableView, rowViewForRow r: Int) -> NSTableRowView? { Row() }
    func tableView(_ t: NSTableView, viewFor c: NSTableColumn?, row r: Int) -> NSView? {
        let th = themes[r]
        let cell = NSView(frame: NSRect(x: 0, y: 0, width: LIST_W - 20, height: 34))
        let mark = NSTextField(labelWithString: th.name == activeTheme ? "●" : " ")
        mark.font = mono; mark.textColor = accent1
        mark.frame = NSRect(x: 4, y: 9, width: 14, height: 16)
        cell.addSubview(mark)
        let l = NSTextField(labelWithString: th.name)
        l.font = mono; l.textColor = textC
        l.lineBreakMode = .byTruncatingTail
        l.frame = NSRect(x: 20, y: 9, width: 118, height: 16)
        cell.addSubview(l)
        for (i, key) in ["PINK", "CYAN", "ORANGE", "PURPLE", "BAR_COLOR"].enumerated() {
            let sw = NSView(frame: NSRect(x: 142 + CGFloat(i) * 15, y: 11, width: 11, height: 11))
            sw.wantsLayer = true
            sw.layer?.backgroundColor = color(th.colors[key] ?? "0xff888888").cgColor
            sw.layer?.cornerRadius = 5.5
            cell.addSubview(sw)
        }
        return cell
    }
    func tableViewSelectionDidChange(_ n: Notification) {
        guard table.selectedRow >= 0 else { return }
        current = table.selectedRow
        let th = themes[current]
        nameField.stringValue = th.name
        for (k, _) in ROLES { wells[k]?.color = color(th.colors[k] ?? "0xff888888") }
        let built = BUILTIN.contains(th.name)
        deleteBtn.isEnabled = !built
        nameField.isEditable = !built
        // shipped themes are read-only: editing is disabled, copy first
        for (_, w) in wells { w.isEnabled = !built }
        applyBtn.title = built ? "Use theme" : "Apply"
        lockLabel.stringValue = built
            ? "built in · read only. Duplicate it to edit these colors."
            : "your theme · colors are per theme, edit any and Apply"
        lockLabel.textColor = built ? dimC : accent2
    }

    func collect(named: String) -> Theme {
        var t = themes[current]
        for (k, _) in ROLES {
            let old = t.colors[k] ?? "0xffffffff"
            let alpha = old.count >= 4 ? String(old.dropFirst(2).prefix(2)) : "ff"
            t.colors[k] = "0x" + alpha + hexRGB(wells[k]!.color)
        }
        t.name = named
        return t
    }
    @objc func apply() {
        let name = themes[current].name
        if !BUILTIN.contains(name) {
            writeTheme(collect(named: name))     // only ever writes user themes
        }
        shell("'\(stateCli)' set theme '\(name)'; sketchybar --reload")
        activeTheme = name
        themes = loadThemes()
        restyle(to: name)                        // the window follows the choice too
        table.reloadData()
    }
    @objc func saveAs() {
        var n = nameField.stringValue.trimmingCharacters(in: .whitespaces)
            .lowercased().replacingOccurrences(of: " ", with: "-")
        if n.isEmpty { n = "custom" }
        // never overwrite a shipped theme: land on a free "<name>-copy[-n]"
        if BUILTIN.contains(n) { n += "-copy" }
        var k = 1
        while FileManager.default.fileExists(atPath: userThemesDir + "/" + n + ".sh") || FileManager.default.fileExists(atPath: themesDir + "/" + n + ".sh") {
            k += 1
            n = n.hasSuffix("-copy") ? n + "-2" : n.replacingOccurrences(of: #"-\d+$"#, with: "", options: .regularExpression) + "-\(k)"
        }
        let t = collect(named: n)
        writeTheme(t)
        themes = loadThemes()
        table.reloadData()
        if let i = themes.firstIndex(where: { $0.name == n }) {
            table.selectRowIndexes([i], byExtendingSelection: false)
        }
    }
    @objc func deleteTheme() {
        let th = themes[current]
        guard !BUILTIN.contains(th.name) else { return }
        try? FileManager.default.removeItem(atPath: userThemesDir + "/" + th.name + ".sh")
        if activeTheme == th.name {
            // reset clears the key so the declared default applies, rather than
            // this file deciding independently what the default theme is
            shell("'\(stateCli)' clear theme; sketchybar --reload")
            activeTheme = "vice-city"
        }
        themes = loadThemes()
        table.reloadData()
        table.selectRowIndexes([0], byExtendingSelection: false)
    }
    @objc func setIconset(_ b: NSButton) {
        shell("'\(stateCli)' set iconset '\(b.alternateTitle)'; sketchybar --reload")
    }
    @objc func doClose() { exit(0) }
    @objc func openSettings() {
        shell("nohup \"$HOME/.config/sketchybar/plugins/settings_open.sh\" > /dev/null 2>&1 &")
    }
}
let ctl = Ctl()

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

let title = NSTextField(labelWithString: "Theme Studio")
title.font = NSFont(name: "JetBrainsMono Nerd Font Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
title.textColor = accent1
title.frame = NSRect(x: 96, y: H - 42, width: 300, height: 22)
content.addSubview(title)

let col = NSTableColumn(identifier: .init("t")); col.width = LIST_W - 20
let table = NSTableView()
table.headerView = nil
table.backgroundColor = panel
table.addTableColumn(col)
table.dataSource = ctl
table.delegate = ctl
let scroll = NSScrollView(frame: NSRect(x: PAD, y: FOOT, width: LIST_W, height: H - 60 - FOOT))
scroll.documentView = table
scroll.hasVerticalScroller = true
scroll.wantsLayer = true
scroll.layer?.cornerRadius = 10
scroll.drawsBackground = true
scroll.backgroundColor = panel
content.addSubview(scroll)

let dX = PAD + LIST_W + 18, dW = W - dX - PAD
let detail = NSView(frame: NSRect(x: dX, y: FOOT, width: dW, height: H - 60 - FOOT))
detail.wantsLayer = true
detail.layer?.backgroundColor = panel.cgColor
detail.layer?.cornerRadius = 10
content.addSubview(detail)

let nameField = NSTextField(frame: NSRect(x: 20, y: detail.frame.height - 46, width: dW - 40, height: 24))
nameField.font = NSFont(name: "JetBrainsMono Nerd Font Bold", size: 15) ?? .boldSystemFont(ofSize: 15)
nameField.textColor = textC
nameField.backgroundColor = .clear
nameField.isBordered = false
nameField.focusRingType = .none
nameField.placeholderString = "theme name"
detail.addSubview(nameField)

var wells: [String: NSColorWell] = [:]
let colW = (dW - 60) / 2
for (i, role) in ROLES.enumerated() {
    let cx: CGFloat = i < 5 ? 20 : 40 + colW
    let cy = detail.frame.height - 106 - CGFloat(i % 5) * 44
    let well = NSColorWell(frame: NSRect(x: cx, y: cy, width: 44, height: 28))
    if #available(macOS 13.0, *) { well.colorWellStyle = .minimal }
    detail.addSubview(well)
    let l = NSTextField(labelWithString: role.label)
    l.font = mono; l.textColor = dimC
    l.frame = NSRect(x: cx + 54, y: cy + 6, width: colW - 60, height: 16)
    detail.addSubview(l)
    wells[role.key] = well
}

// ---- global footer: icon set applies to EVERY theme ----
let footer = NSView(frame: NSRect(x: PAD, y: 14, width: W - 2 * PAD, height: FOOT - 26))
footer.wantsLayer = true
footer.layer?.backgroundColor = panel.withAlphaComponent(0.55).cgColor
footer.layer?.cornerRadius = 10
content.addSubview(footer)
let stripY: CGFloat = 8
let stripLabel = NSTextField(labelWithString: "icon set · applies to every theme")
stripLabel.font = mono; stripLabel.textColor = accent2
stripLabel.frame = NSRect(x: 14, y: FOOT - 48, width: 340, height: 16)
footer.addSubview(stripLabel)
let settingsBtn = NSButton(title: "Settings…", target: ctl, action: #selector(Ctl.openSettings))
settingsBtn.bezelStyle = .rounded
settingsBtn.frame = NSRect(x: footer.frame.width - 118, y: FOOT - 52, width: 104, height: 26)
footer.addSubview(settingsBtn)
// iconsets are files in ../icons — read them and preview real glyphs
var activeIconButton: NSButton?
let iconDir = (themesDir as NSString).deletingLastPathComponent + "/icons"
let sets = ((try? FileManager.default.contentsOfDirectory(atPath: iconDir)) ?? [])
    .filter { $0.hasSuffix(".sh") }.map { String($0.dropLast(3)) }.sorted()
func sample(_ set: String) -> String {
    guard let src = try? String(contentsOfFile: iconDir + "/" + set + ".sh", encoding: .utf8) else { return "" }
    var glyphs: [String] = []
    for key in ["ICON_CLOCK", "ICON_RAM", "ICON_WIFI", "ICON_POMO", "ICON_AURA"] {
        for line in src.components(separatedBy: "\n") where line.contains(key + "=") {
            if let part = line.components(separatedBy: key + "=").last {
                let g = part.components(separatedBy: " ")[0].replacingOccurrences(of: "\"", with: "")
                if !g.isEmpty { glyphs.append(g) }
            }
            break
        }
    }
    return glyphs.joined(separator: " ")
}
let perRow = max(sets.count, 1)
let bw = (footer.frame.width - 28 - CGFloat(perRow - 1) * 6) / CGFloat(perRow)
for (i, set) in sets.enumerated() {
    let b = NSButton(title: "\(set)  \(sample(set))", target: ctl, action: #selector(Ctl.setIconset(_:)))
    b.alternateTitle = set
    b.bezelStyle = .rounded
    b.font = mono
    let rowIdx = i / perRow, colIdx = i % perRow
    _ = rowIdx
    b.frame = NSRect(x: 14 + CGFloat(colIdx) * (bw + 6), y: stripY, width: bw, height: 28)
    if set == activeIconset { b.contentTintColor = accent1; activeIconButton = b }
    footer.addSubview(b)
}

func btn(_ t: String, _ x: CGFloat, _ w: CGFloat, _ a: Selector) -> NSButton {
    let b = NSButton(title: t, target: ctl, action: a)
    b.bezelStyle = .rounded
    b.frame = NSRect(x: x, y: 16, width: w, height: 30)
    return b
}
let applyBtn = btn("Apply", dW - 110, 90, #selector(Ctl.apply))
detail.addSubview(btn("Duplicate", dW - 240, 120, #selector(Ctl.saveAs)))
detail.addSubview(applyBtn)
let deleteBtn = btn("Delete", 20, 90, #selector(Ctl.deleteTheme))
detail.addSubview(deleteBtn)

let lockLabel = NSTextField(labelWithString: "")
lockLabel.font = mono
lockLabel.textColor = dimC
lockLabel.frame = NSRect(x: 20, y: detail.frame.height - 68, width: dW - 40, height: 16)
detail.addSubview(lockLabel)

ctl.table = table
ctl.wells = wells
ctl.nameField = nameField
ctl.deleteBtn = deleteBtn
ctl.applyBtn = applyBtn
ctl.lockLabel = lockLabel

if let i = themes.firstIndex(where: { $0.name == activeTheme }) {
    table.selectRowIndexes([i], byExtendingSelection: false)
} else {
    table.selectRowIndexes([0], byExtendingSelection: false)
}
ctl.tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification))

// Repaint the studio in the theme just chosen. Without this the bar recoloured
// while the window you picked in kept its launch colours, which reads as "that
// did not work" — the same doubt the bar's own fix removed.
func restyle(to name: String) {
    // same precedence the bar uses: a theme the user edited beats the built-in
    let userPath = userThemesDir + "/" + name + ".sh"
    let path = FileManager.default.fileExists(atPath: userPath) ? userPath : themesDir + "/" + name + ".sh"
    guard let src = try? String(contentsOfFile: path, encoding: .utf8) else { return }
    var vals: [String: String] = [:]
    for line in src.components(separatedBy: "\n") where line.contains("export ") && line.contains("=") {
        let body = line.replacingOccurrences(of: "export ", with: "")
        guard let k = body.components(separatedBy: "=").first?.trimmingCharacters(in: .whitespaces),
              let rest = body.components(separatedBy: "=").dropFirst().first else { continue }
        vals[k] = rest.components(separatedBy: " ")[0].trimmingCharacters(in: .whitespaces)
    }
    guard let b = vals["BAR_COLOR"], let pn = vals["ITEM_BG_COLOR"],
          let a1 = vals["PINK"], let a2 = vals["CYAN"] else { return }
    bg = color(b); panel = color(pn); accent1 = color(a1); accent2 = color(a2)

    win.backgroundColor = bg
    title.textColor = accent1
    table.backgroundColor = panel
    scroll.backgroundColor = panel
    detail.layer?.backgroundColor = panel.cgColor
    footer.layer?.backgroundColor = panel.withAlphaComponent(0.55).cgColor
    stripLabel.textColor = accent2
    activeIconButton?.contentTintColor = accent1
    win.contentView?.needsDisplay = true
}

win.makeKeyAndOrderFront(nil)
NSApp.activate(ignoringOtherApps: true)
app.run()
exit(0)
