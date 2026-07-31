// pick_color — eyedropper anywhere on screen, hex on stdout.
//
// NSColorSampler is the same picker macOS uses in its own colour panel, so it
// gets the loupe, the magnified pixel grid and Esc-to-cancel for free, and it
// needs no Screen Recording grant. Replaces Sip.
//
// Prints "#RRGGBB rgb(r, g, b)" so the caller can put either form on the
// clipboard. Exits 1 if the user cancels.
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let sampler = NSColorSampler()
sampler.show { picked in
    guard let c = picked?.usingColorSpace(.sRGB) else { exit(1) }
    let r = Int((c.redComponent   * 255).rounded())
    let g = Int((c.greenComponent * 255).rounded())
    let b = Int((c.blueComponent  * 255).rounded())
    print(String(format: "#%02X%02X%02X rgb(%d, %d, %d)", r, g, b, r, g, b))
    exit(0)
}

app.run()
