// settings_win <settingsFile> <bgHex> <panelHex> <a1Hex> <a2Hex>
// Global preferences: notification categories, sound/voice, screenshot behavior.
// Writes settings.conf live on every toggle.
import AppKit

guard CommandLine.arguments.count >= 6 else { print("usage: settings_win conf bg panel a1 a2"); exit(2) }
let confPath = CommandLine.arguments[1]

func color(_ hex: String) -> NSColor {
    var h = hex.replacingOccurrences(of: "0x", with: "")
    if h.count == 8 { h = String(h.dropFirst(2)) }
    let v = UInt32(h, radix: 16) ?? 0x222222
    return NSColor(calibratedRed: CGFloat((v >> 16) & 0xFF) / 255,
                   green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}
let bg = color(CommandLine.arguments[2])
let panel = color(CommandLine.arguments[3])
let accent1 = color(CommandLine.arguments[4])
let accent2 = color(CommandLine.arguments[5])
let textC = NSColor(calibratedWhite: 0.93, alpha: 1)
let dimC = NSColor(calibratedWhite: 1, alpha: 0.45)
let mono = NSFont(name: "JetBrainsMono Nerd Font", size: 12.5) ?? .monospacedSystemFont(ofSize: 12.5, weight: .regular)
let monoBold = NSFont(name: "JetBrainsMono Nerd Font Bold", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .bold)

struct Row { let key: String; let label: String }
let GROUPS: [(String, [Row])] = [
    ("NOTIFICATIONS", [
        Row(key: "notify_agents", label: "AI agent finished"),
        Row(key: "notify_shot", label: "screenshots"),
        Row(key: "notify_aura", label: "aura awards and exports"),
        Row(key: "notify_journal", label: "journal locks and exports"),
        Row(key: "notify_ram", label: "RAM reclaim results"),
        Row(key: "notify_pomodoro", label: "pomodoro finished"),
        Row(key: "notify_speedtest", label: "speedtest results"),
        Row(key: "notify_ports", label: "dev server stopped"),
        Row(key: "notify_clipboard", label: "clipboard actions"),
        Row(key: "notify_shelf", label: "shelf drops"),
        Row(key: "notify_update", label: "new release available"),
        Row(key: "notify_toggles", label: "toggles, themes, misc"),
    ]),
    ("SOUND", [
        Row(key: "sound", label: "play a sound with notifications"),
        Row(key: "voice", label: "spoken announcements"),
    ]),
    ("SCREENSHOTS", [
        Row(key: "shot_to_clipboard", label: "also copy new shots to the clipboard"),
    ]),
]

func readConf() -> [String: String] {
    var d: [String: String] = [:]
    for line in ((try? String(contentsOfFile: confPath, encoding: .utf8)) ?? "").components(separatedBy: "\n") {
        guard !line.hasPrefix("#") else { continue }
        let kv = line.components(separatedBy: "=")
        if kv.count == 2 { d[kv[0].trimmingCharacters(in: .whitespaces)] = kv[1].trimmingCharacters(in: .whitespaces) }
    }
    return d
}
var conf = readConf()

func writeConf() {
    var lines = ["# sketchetc global settings · edit here or from the 󰀵 menu → Settings"]
    for (g, rows) in GROUPS {
        lines.append("# " + g.lowercased())
        for r in rows { lines.append("\(r.key)=\(conf[r.key] ?? "on")") }
    }
    lines.append("shot_dir=\(conf["shot_dir"] ?? "DESKTOP")")
    try? (lines.joined(separator: "\n") + "\n").write(toFile: confPath, atomically: true, encoding: .utf8)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let W: CGFloat = 520
let rowCount = GROUPS.reduce(0) { $0 + $1.1.count }
let H: CGFloat = 96 + CGFloat(rowCount) * 30 + CGFloat(GROUPS.count) * 34

let MODES = ["on", "silent", "off"]        // sound, banner only, nothing

final class Ctl: NSObject {
    var boxes: [NSButton] = []
    @objc func flip(_ b: NSButton) {
        let key = b.identifier?.rawValue ?? ""
        conf[key] = b.state == .on ? "on" : "off"
        writeConf()
    }
    // Notification rows are three-state, so a checkbox cannot represent them: it
    // would show "silent" as unchecked and overwrite it with "off" on the next
    // click, quietly destroying the setting.
    @objc func pickMode(_ seg: NSSegmentedControl) {
        let key = seg.identifier?.rawValue ?? ""
        conf[key] = MODES[max(0, min(seg.selectedSegment, MODES.count - 1))]
        writeConf()
    }
    @objc func close() { exit(0) }
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

let title = NSTextField(labelWithString: "Settings")
title.font = NSFont(name: "JetBrainsMono Nerd Font Bold", size: 15) ?? .boldSystemFont(ofSize: 15)
title.textColor = accent1
title.frame = NSRect(x: 96, y: H - 38, width: 300, height: 20)
content.addSubview(title)

let card = NSView(frame: NSRect(x: 18, y: 48, width: W - 36, height: H - 96))
card.wantsLayer = true
card.layer?.backgroundColor = panel.cgColor
card.layer?.cornerRadius = 10
content.addSubview(card)

var y = card.frame.height - 26
for (group, rows) in GROUPS {
    let gl = NSTextField(labelWithString: group)
    gl.font = monoBold
    gl.textColor = accent2
    gl.frame = NSRect(x: 18, y: y, width: 300, height: 16)
    card.addSubview(gl)
    y -= 28
    for r in rows {
        if r.key.hasPrefix("notify_") {
            let l = NSTextField(labelWithString: r.label)
            l.font = mono
            l.textColor = textC
            l.frame = NSRect(x: 22, y: y + 3, width: card.frame.width - 220, height: 18)
            card.addSubview(l)

            let seg = NSSegmentedControl(labels: ["sound", "silent", "off"],
                                         trackingMode: .selectOne,
                                         target: ctl, action: #selector(Ctl.pickMode(_:)))
            seg.identifier = NSUserInterfaceItemIdentifier(r.key)
            seg.font = NSFont(name: "JetBrainsMono Nerd Font", size: 10.5) ?? .monospacedSystemFont(ofSize: 10.5, weight: .regular)
            // anything unrecognised reads as "on", matching how notify.sh treats it
            let cur = conf[r.key] ?? "on"
            seg.selectedSegment = MODES.firstIndex(of: cur) ?? 0
            seg.frame = NSRect(x: card.frame.width - 192, y: y, width: 172, height: 22)
            card.addSubview(seg)
        } else {
            let b = NSButton(checkboxWithTitle: "  " + r.label, target: ctl, action: #selector(Ctl.flip(_:)))
            b.identifier = NSUserInterfaceItemIdentifier(r.key)
            b.font = mono
            b.contentTintColor = accent1
            b.attributedTitle = NSAttributedString(string: "  " + r.label,
                attributes: [.font: mono, .foregroundColor: textC])
            b.state = (conf[r.key] ?? "on") == "on" ? .on : .off
            b.frame = NSRect(x: 20, y: y, width: card.frame.width - 40, height: 22)
            card.addSubview(b)
            ctl.boxes.append(b)
        }
        y -= 30
    }
    y -= 6
}

let hint = NSTextField(labelWithString: "changes apply immediately")
hint.font = mono
hint.textColor = dimC
hint.frame = NSRect(x: 20, y: 18, width: W - 140, height: 16)
content.addSubview(hint)

let done = NSButton(title: "Done", target: ctl, action: #selector(Ctl.close))
done.bezelStyle = .rounded
done.keyEquivalent = "\r"
done.frame = NSRect(x: W - 106, y: 12, width: 88, height: 28)
content.addSubview(done)

win.makeKeyAndOrderFront(nil)
NSApp.activate(ignoringOtherApps: true)
app.run()
exit(0)
