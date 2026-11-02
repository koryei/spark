import Foundation

/// Settings for the server Spark controls. Stored at ~/.config/spark/config.json
/// and edited through the Settings window.
struct Config: Codable, Equatable {
    var name: String
    var mac: String           // e.g. "AA:BB:CC:DD:EE:FF"
    var broadcast: String     // e.g. "192.168.1.255"
    var host: String          // SSH host or IP
    var user: String
    var port: Int
    var identityFile: String? // optional path to an SSH key

    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/spark/config.json")
    }

    static var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    static func load() throws -> Config {
        try JSONDecoder().decode(Config.self, from: Data(contentsOf: url))
    }

    func save() throws {
        try FileManager.default.createDirectory(
            at: Config.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(self).write(to: Config.url)
    }

    /// Trims whitespace and drops a "/24" style suffix someone may have pasted after the address.
    var cleaned: Config {
        var c = self
        c.name = name.trimmingCharacters(in: .whitespaces)
        c.mac = mac.trimmingCharacters(in: .whitespaces)
        c.broadcast = broadcast.trimmingCharacters(in: .whitespaces)
        c.user = user.trimmingCharacters(in: .whitespaces)
        c.host = host.trimmingCharacters(in: .whitespaces).components(separatedBy: "/").first ?? ""
        c.identityFile = identityFile?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        return c
    }

    /// A plain-language problem with the settings, or nil when they look usable.
    func problem() -> String? {
        if name.isEmpty { return "Give the server a name." }
        let macBytes = mac.split(whereSeparator: { $0 == ":" || $0 == "-" })
        if macBytes.count != 6 || !macBytes.allSatisfy({ UInt8($0, radix: 16) != nil }) {
            return "The MAC address should look like c0:47:0e:fa:44:17."
        }
        if host.isEmpty { return "Enter the server's address, e.g. 10.0.0.232." }
        if !Config.isIPv4(broadcast) { return "The broadcast address should look like 10.0.0.255." }
        if user.isEmpty { return "Enter the username you log in to the server with." }
        if !(1...65535).contains(port) { return "The port should be a number, usually 22." }
        return nil
    }

    /// Guesses the broadcast address from a server address: 10.0.0.232 becomes 10.0.0.255.
    static func guessBroadcast(from host: String) -> String? {
        let h = host.trimmingCharacters(in: .whitespaces).components(separatedBy: "/").first ?? ""
        guard isIPv4(h) else { return nil }
        var parts = h.split(separator: ".")
        parts[3] = "255"
        return parts.joined(separator: ".")
    }

    static func isIPv4(_ s: String) -> Bool {
        var addr = in_addr()
        return inet_pton(AF_INET, s, &addr) == 1
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
