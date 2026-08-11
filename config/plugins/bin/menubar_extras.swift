// menubar_extras — read the real macOS menu bar extras, and press one.
//
// sketchybar's own `alias` component could not do this job. An alias is a
// periodically re-captured BITMAP of the real item: it needs the Screen Recording
// grant, it costs a screen capture per icon every few seconds, and it can never
// be clicked, because sketchybar has no way to activate the item it photographed.
// So the old Extras widget was a decorative strip that did nothing — and on this
// machine it drew nothing at all, since Screen Recording was never granted.
//
// Accessibility can do all of it. Every app owns its own status item, reachable as
// AXExtrasMenuBar on that app's AXUIElement, and those items advertise AXPress.
// Pressing one opens the app's genuine dropdown, wherever the real item sits.
// This needs only the Accessibility grant, which the bar already holds for window
// snapping and space switching.
//
//   menubar_extras list          -> one "pid<TAB>name" line per app with an extra
//   menubar_extras press <pid>   -> opens that app's real menu
import AppKit
import ApplicationServices

func extrasElement(_ pid: pid_t) -> AXUIElement? {
    let app = AXUIElementCreateApplication(pid)
    var value: CFTypeRef?
    // kAXExtrasMenuBarAttribute is the menu bar that holds status items, as
    // opposed to kAXMenuBarAttribute which is the File/Edit/View one.
    guard AXUIElementCopyAttributeValue(app, kAXExtrasMenuBarAttribute as CFString, &value) == .success,
          let bar = value else { return nil }
    return (bar as! AXUIElement)
}

func extraItems(_ bar: AXUIElement) -> [AXUIElement] {
    var kids: CFTypeRef?
    guard AXUIElementCopyAttributeValue(bar, kAXChildrenAttribute as CFString, &kids) == .success,
          let arr = kids as? [AXUIElement] else { return [] }
    return arr
}

// Apps whose "extra" is really a system affordance, or that own the bar itself.
// Everything else is fair game: the point is that ANY app with an icon shows up,
// not a list we have to keep updating.
// Localised names, so both spellings of Control Cent{er,re} have to be listed —
// the system one showed up on this machine as "Control Centre".
let skip: Set<String> = ["Control Center", "Control Centre", "SystemUIServer",
                         "TextInputMenuAgent", "Spotlight", "Siri",
                         "NotificationCenter", "sketchybar"]

func listExtras() {
    for app in NSWorkspace.shared.runningApplications {
        guard let name = app.localizedName, !skip.contains(name) else { continue }
        // .prohibited apps never own a status item; skipping them keeps this from
        // walking every background daemon on the system.
        guard app.activationPolicy != .prohibited else { continue }
        guard let bar = extrasElement(app.processIdentifier) else { continue }
        guard !extraItems(bar).isEmpty else { continue }
        print("\(app.processIdentifier)\t\(name)")
    }
}

// Pressing is deliberately NOT done here.
//
// Reading the extras bar works from this binary, but AXUIElementPerformAction
// comes back kAXErrorCannotComplete (-25204): the Accessibility grant is per
// client binary, and a freshly built helper is not in the allow list — while
// System Events already is, and the bar already drives it for window snapping.
// So enumeration (which needs to be fast, and is far too slow through System
// Events across every process) stays here, and the press goes through osascript
// in extras.sh. Confirmed by opening Docker's and Cursor's real menus both ways.

let args = CommandLine.arguments
guard args.count > 1 else { print("usage: menubar_extras list"); exit(2) }

// Without the Accessibility grant every query silently returns nothing, which
// would look exactly like "no apps have menu bar icons". Say so instead.
guard AXIsProcessTrusted() else {
    FileHandle.standardError.write("menubar_extras: Accessibility not granted\n".data(using: .utf8)!)
    exit(3)
}

switch args[1] {
case "list": listExtras()
default: exit(2)
}
