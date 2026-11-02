import Foundation

enum WakeError: LocalizedError {
    case badMAC(String)
    case socket(String)

    var errorDescription: String? {
        switch self {
        case .badMAC(let m): return "“\(m)” is not a valid MAC address."
        case .socket(let m): return "Could not send the wake packet: \(m)"
        }
    }
}

enum WakeOnLAN {
    /// Sends a magic packet (6 × 0xFF, then the MAC 16 times) to the broadcast address on UDP port 9.
    static func send(mac: String, broadcast: String, port: UInt16 = 9) throws {
        let bytes = mac.split(whereSeparator: { $0 == ":" || $0 == "-" })
            .compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6 else { throw WakeError.badMAC(mac) }

        var packet = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: bytes) }

        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { throw WakeError.socket(String(cString: strerror(errno))) }
        defer { close(fd) }

        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &on, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, broadcast, &addr.sin_addr) == 1 else {
            throw WakeError.socket("“\(broadcast)” is not a valid IPv4 address.")
        }

        let sent = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(fd, packet, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard sent == packet.count else { throw WakeError.socket(String(cString: strerror(errno))) }
    }
}
