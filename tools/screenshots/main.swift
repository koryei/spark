// Renders the real Settings window to PNGs (with sample values) for the README mockups.
import AppKit

let out = CommandLine.arguments[1]
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.appearance = NSAppearance(named: .aqua)

let settings = SettingsController()
settings.show()

func textFields(_ v: NSView) -> [NSTextField] {
    ((v as? NSTextField).flatMap { $0.isEditable ? [$0] : nil } ?? []) + v.subviews.flatMap(textFields)
}

// Document order: name, MAC, address, port, broadcast, username, key.
let window = NSApp.windows[0]
let samples = ["homeserver", "a4:bb:6d:12:34:56", "192.168.1.50", "22", "192.168.1.255", "you", "~/.ssh/spark"]
for (f, v) in zip(textFields(window.contentView!), samples) { f.stringValue = v }
window.makeFirstResponder(nil)

func snapshot(_ name: String) {
    let v = window.contentView!
    v.layoutSubtreeIfNeeded()
    let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
    v.cacheDisplay(in: v.bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}

DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
    snapshot("settings-raw")
    settings.showChecks([
        Check(ok: true, title: "Reach 192.168.1.50 on port 22", hint: nil),
        Check(ok: true, title: "Log in with the key, no password", hint: nil),
        Check(ok: true, title: "Allowed to sleep without a password", hint: nil),
    ])
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        snapshot("test-raw")
        exit(0)
    }
}
app.run()
