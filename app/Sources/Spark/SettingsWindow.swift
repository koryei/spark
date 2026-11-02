import AppKit

/// The Settings window: three small groups of fields, a connection test and Save.
final class SettingsController: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    private let window: NSWindow
    private let name = SettingsController.field("homeserver")
    private let mac = SettingsController.field("c0:47:0e:fa:44:17")
    private let host = SettingsController.field("10.0.0.232")
    private let port = SettingsController.field("22")
    private let broadcast = SettingsController.field("10.0.0.255")
    private let user = SettingsController.field("your username on the server")
    private let key = SettingsController.field("~/.ssh/spark")
    private let status = NSTextField(wrappingLabelWithString: "")
    private let testButton = NSButton(title: "Test connection", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)
    private let queue = DispatchQueue(label: "spark.settings")
    var onSave: (() -> Void)?

    override init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "Spark Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        [name, mac, host, port, broadcast, user, key].forEach { $0.delegate = self }
        build()
        fill()
    }

    func show() {
        fill()
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: Layout

    private static func field(_ placeholder: String) -> NSTextField {
        let f = NSTextField()
        f.placeholderString = placeholder
        f.translatesAutoresizingMaskIntoConstraints = false
        f.widthAnchor.constraint(equalToConstant: 260).isActive = true
        return f
    }

    private func label(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.alignment = .right
        return l
    }

    private func header(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = .boldSystemFont(ofSize: 13)
        return l
    }

    private func group(_ title: String, _ rows: [[NSView]]) -> NSStackView {
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 8
        grid.columnSpacing = 12
        grid.rowAlignment = .firstBaseline
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 0).width = 110
        let box = NSStackView(views: [header(title), grid])
        box.orientation = .vertical
        box.alignment = .leading
        box.spacing = 10
        return box
    }

    private func build() {
        port.widthAnchor.constraint(equalToConstant: 70).isActive = true
        let keyButton = NSButton(title: "Copy public key", target: self, action: #selector(copyKey))
        keyButton.controlSize = .small
        let keyRow = NSStackView(views: [key, keyButton])
        keyRow.spacing = 8
        key.widthAnchor.constraint(equalToConstant: 150).isActive = true

        let portRow = NSStackView(views: [port])
        portRow.alignment = .leading

        let server = group("Server", [[label("Name"), name], [label("MAC address"), mac]])
        let network = group("Network", [
            [label("Server address"), host],
            [label("SSH port"), portRow],
            [label("Broadcast"), broadcast],
        ])
        let login = group("Login", [[label("Username"), user], [label("SSH key"), keyRow]])

        status.font = .systemFont(ofSize: 12)
        status.preferredMaxLayoutWidth = 432
        status.isSelectable = true

        testButton.target = self; testButton.action = #selector(test)
        saveButton.target = self; saveButton.action = #selector(save)
        saveButton.keyEquivalent = "\r"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let buttons = NSStackView(views: [testButton, spacer, saveButton])
        buttons.orientation = .horizontal

        let root = NSStackView(views: [server, network, login, status, buttons])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 20
        root.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 20, right: 24)
        root.setCustomSpacing(14, after: login)
        buttons.widthAnchor.constraint(equalToConstant: 432).isActive = true

        window.contentView = root
        window.setContentSize(root.fittingSize)
    }

    private func fill() {
        let c = Config.exists ? try? Config.load() : nil
        name.stringValue = c?.name ?? "homeserver"
        mac.stringValue = c?.mac ?? ""
        host.stringValue = c?.host ?? ""
        port.stringValue = String(c?.port ?? 22)
        broadcast.stringValue = c?.broadcast ?? ""
        user.stringValue = c?.user ?? ""
        key.stringValue = c?.identityFile ?? "~/.ssh/spark"
        say(Config.exists ? "" : "Fill these in, then press Test connection. The setup guide on GitHub walks through each one.")
    }

    // Fill in the broadcast address for the user as soon as the server address is known.
    func controlTextDidEndEditing(_ obj: Notification) {
        guard (obj.object as? NSTextField) === host, broadcast.stringValue.isEmpty,
              let guess = Config.guessBroadcast(from: host.stringValue) else { return }
        broadcast.stringValue = guess
    }

    // MARK: Actions

    private func read() -> Config? {
        let c = Config(
            name: name.stringValue, mac: mac.stringValue, broadcast: broadcast.stringValue,
            host: host.stringValue, user: user.stringValue,
            port: Int(port.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0,
            identityFile: key.stringValue
        ).cleaned
        if let p = c.problem() { say(p, bad: true); return nil }
        return c
    }

    @objc private func save() {
        guard let c = read() else { return }
        do {
            try c.save()
            onSave?()
            window.close()
        } catch {
            say("Couldn't save: \(error.localizedDescription)", bad: true)
        }
    }

    @objc private func test() {
        guard let c = read() else { return }
        testButton.isEnabled = false
        say("Testing…")
        queue.async {
            let checks = Server.diagnose(c)
            DispatchQueue.main.async {
                self.testButton.isEnabled = true
                self.showChecks(checks)
            }
        }
    }

    @objc private func copyKey() {
        do {
            let path = key.stringValue.isEmpty ? "~/.ssh/spark" : key.stringValue
            let pub = try Server.ensureKey(at: path)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(pub, forType: .string)
            key.stringValue = path
            say("Public key copied. Add it to the server as shown in step 3 of the setup guide, then press Test connection.")
        } catch {
            say("Couldn't read or create the key: \(error.localizedDescription)", bad: true)
        }
    }

    // MARK: Status text. Every result carries a mark and words, never colour alone.

    private func say(_ s: String, bad: Bool = false) {
        status.attributedStringValue = NSAttributedString(string: s, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: bad ? NSColor.systemRed : NSColor.secondaryLabelColor,
        ])
    }

    private func showChecks(_ checks: [Check]) {
        let out = NSMutableAttributedString()
        for ch in checks {
            let line = "\(ch.ok ? "✓" : "✗")  \(ch.title)\n"
            out.append(NSAttributedString(string: line, attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: ch.ok ? NSColor.labelColor : NSColor.systemRed,
            ]))
            if let h = ch.hint {
                out.append(NSAttributedString(string: "     \(h)\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor,
                ]))
            }
        }
        if checks.allSatisfy({ $0.ok }) {
            out.append(NSAttributedString(string: "\nAll good. Press Save.", attributes: [
                .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor,
            ]))
        }
        status.attributedStringValue = out
    }
}
