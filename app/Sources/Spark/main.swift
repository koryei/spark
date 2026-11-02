import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusLine = NSMenuItem(title: "Checking…", action: nil, keyEquivalent: "")
    private let wakeItem = NSMenuItem(title: "Wake server", action: #selector(wake), keyEquivalent: "w")
    private let sleepItem = NSMenuItem(title: "Sleep server", action: #selector(sleepServer), keyEquivalent: "s")
    private let queue = DispatchQueue(label: "spark.work")

    func applicationDidFinishLaunching(_ note: Notification) {
        item.button?.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Spark")

        let menu = NSMenu()
        menu.delegate = self
        statusLine.isEnabled = false
        [wakeItem, sleepItem].forEach { $0.target = self }
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(wakeItem)
        menu.addItem(sleepItem)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Open config…", action: #selector(openConfig), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(NSMenuItem(title: "Quit Spark", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    // Refresh the status line each time the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        guard let c = try? Config.load() else { statusLine.title = "Config error"; return }
        statusLine.title = "\(c.name) · checking…"
        queue.async {
            let up = Server.isUp(c)
            DispatchQueue.main.async {
                self.statusLine.title = "\(c.name) · \(up ? "Awake" : "Asleep")"
                self.wakeItem.isEnabled = !up
                self.sleepItem.isEnabled = up
            }
        }
    }

    @objc private func wake() {
        run("Wake") { c in try WakeOnLAN.send(mac: c.mac, broadcast: c.broadcast) }
    }

    @objc private func sleepServer() {
        run("Sleep") { c in try Server.sleep(c) }
    }

    @objc private func openConfig() {
        _ = try? Config.load() // creates the example file on first run
        NSWorkspace.shared.open(Config.url)
    }

    private func run(_ title: String, _ work: @escaping (Config) throws -> Void) {
        queue.async {
            do { try work(try Config.load()) }
            catch {
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                    let alert = NSAlert()
                    alert.messageText = "\(title) failed"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
