import Foundation

enum SleepError: LocalizedError {
    case failed(String)
    var errorDescription: String? {
        if case .failed(let m) = self { return m }
        return nil
    }
}

enum Server {
    /// Suspends the server over SSH. Needs key-based login and passwordless sudo for
    /// `systemctl suspend` on the server (see README).
    static func sleep(_ c: Config) throws {
        var args = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=5",
            "-o", "StrictHostKeyChecking=accept-new",
            "-p", String(c.port),
        ]
        if let key = c.identityFile, !key.isEmpty { args += ["-i", (key as NSString).expandingTildeInPath] }
        args += ["\(c.user)@\(c.host)", "sudo -n systemctl suspend"]

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        p.arguments = args
        let err = Pipe()
        p.standardError = err
        try p.run()

        // The connection drops as the machine goes to sleep, so ssh may never exit cleanly.
        let deadline = Date().addingTimeInterval(10)
        while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        if p.isRunning { p.terminate(); return }

        // 255 is ssh's own error code, but also what you get when the link dies mid-suspend.
        if p.terminationStatus != 0 {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let lower = msg.lowercased()
            let dropped = lower.contains("closed by remote host") || lower.contains("connection reset")
            if !dropped { throw SleepError.failed(msg.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
    }

    /// True when something accepts a TCP connection on the SSH port within a second.
    static func isUp(_ c: Config) -> Bool {
        var hints = addrinfo(); hints.ai_family = AF_INET; hints.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(c.host, String(c.port), &hints, &res) == 0, let info = res else { return false }
        defer { freeaddrinfo(res) }

        let fd = socket(info.pointee.ai_family, info.pointee.ai_socktype, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)

        if connect(fd, info.pointee.ai_addr, info.pointee.ai_addrlen) == 0 { return true }
        guard errno == EINPROGRESS else { return false }

        var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        guard poll(&pfd, 1, 1000) > 0 else { return false }
        var soErr: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fd, SOL_SOCKET, SO_ERROR, &soErr, &len)
        return soErr == 0
    }
}
