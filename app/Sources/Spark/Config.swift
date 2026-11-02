import Foundation

/// Settings for the server Spark controls. Lives at ~/.config/spark/config.json.
struct Config: Codable {
    var name: String
    var mac: String          // e.g. "AA:BB:CC:DD:EE:FF"
    var broadcast: String    // e.g. "192.168.1.255"
    var host: String         // SSH host or IP
    var user: String
    var port: Int
    var identityFile: String? // optional path to an SSH key

    static let example = Config(
        name: "homeserver",
        mac: "AA:BB:CC:DD:EE:FF",
        broadcast: "192.168.1.255",
        host: "192.168.1.50",
        user: "you",
        port: 22,
        identityFile: nil
    )

    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/spark/config.json")
    }

    /// Loads the config, writing an example file first if none exists.
    static func load() throws -> Config {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(example).write(to: url)
        }
        return try JSONDecoder().decode(Config.self, from: Data(contentsOf: url))
    }
}
