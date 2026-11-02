import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusLine = NSMenuItem(title: "Checking…", action: nil, keyEquivalent: "")
    private let wakeItem = NSMenuItem(title: "Wake server", action: #selector(wake), keyEquivalent: "w")
    private let sleepItem = NSMenuItem(title: "Sleep server", action: #selector(sleepServer), keyEquivalent: "s")
    private let queue = DispatchQueue(label: "spark.work")
    private let settings = SettingsController()

    func applicationDidFinishLaunching(_ note: Notification) {
        installEditMenu()
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
        let prefs = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)
        menu.addItem(NSMenuItem(title: "Quit Spark", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu

        // First launch: nothing is set up yet, so go straight to Settings.
        if !Config.exists || CommandLine.arguments.contains("--settings") { openSettings() }
    }

    // A menu bar app has no main menu, which would leave ⌘C and ⌘V dead in the Settings fields.
    private func installEditMenu() {
        let main = NSMenu()
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    // Refresh the status line each time the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        guard Config.exists, let c = try? Config.load() else {
            statusLine.title = "Not set up yet"
            wakeItem.isEnabled = false
            sleepItem.isEnabled = false
            return
        }
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

    @objc private func openSettings() { settings.show() }

    private func run(_ title: String, _ work: @escaping (Config) throws -> Void) {
        guard Config.exists, let c = try? Config.load() else { openSettings(); return }
        queue.async {
            do { try work(c) }
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
