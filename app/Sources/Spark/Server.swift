import Foundation

enum SleepError: LocalizedError {
    case failed(String)
    var errorDescription: String? {
        if case .failed(let m) = self { return m }
        return nil
    }
}

/// One line of the "Test connection" report.
struct Check {
    let ok: Bool
    let title: String
    let hint: String?
}

struct SSHResult {
    var status: Int32
    var stderr: String
    var timedOut: Bool
}

enum Server {
    /// Runs one command on the server with the system ssh, never prompting for a password.
    static func ssh(_ c: Config, _ command: String, timeout: TimeInterval) throws -> SSHResult {
        var args = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=5",
            "-o", "StrictHostKeyChecking=accept-new",
            "-p", String(c.port),
        ]
        if let key = c.identityFile, !key.isEmpty {
            args += ["-i", (key as NSString).expandingTildeInPath]
        }
        args += ["\(c.user)@\(c.host)", command]

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        let err = Pipe()
        p.standardError = err
        try p.run()

        let deadline = Date().addingTimeInterval(timeout)
        while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        if p.isRunning {
            p.terminate()
            return SSHResult(status: -1, stderr: "", timedOut: true)
        }
        let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return SSHResult(status: p.terminationStatus, stderr: msg, timedOut: false)
    }

    /// Suspends the server. Needs key-based login and a passwordless sudo rule for
    /// `systemctl suspend` on the server (see docs/setup.md).
    static func sleep(_ c: Config) throws {
        let r = try ssh(c, "sudo -n systemctl suspend", timeout: 10)
        // The connection drops as the machine goes to sleep, so ssh may never exit cleanly.
        if r.timedOut || r.status == 0 { return }
        let lower = r.stderr.lowercased()
        if lower.contains("closed by remote host") || lower.contains("connection reset") { return }
        throw SleepError.failed(explain(r.stderr, sudoStep: false))
    }

    /// Checks each thing a working setup needs, stopping at the first failure.
    static func diagnose(_ c: Config) -> [Check] {
        var out: [Check] = []

        if !isUp(c) {
            out.append(Check(ok: false, title: "Reach \(c.host) on port \(c.port)",
                hint: "No answer. Make sure the server is on, the address is right, and this Mac is on the same network."))
            return out
        }
        out.append(Check(ok: true, title: "Reach \(c.host) on port \(c.port)", hint: nil))

        do {
            let login = try ssh(c, "true", timeout: 10)
            if login.status != 0 || login.timedOut {
                out.append(Check(ok: false, title: "Log in with the key, no password",
                    hint: login.timedOut ? "The server took too long to answer." : explain(login.stderr, sudoStep: false)))
                return out
            }
            out.append(Check(ok: true, title: "Log in with the key, no password", hint: nil))

            let sudo = try ssh(c, "sudo -n -l /usr/bin/systemctl suspend", timeout: 10)
            if sudo.status != 0 || sudo.timedOut {
                out.append(Check(ok: false, title: "Allowed to sleep without a password",
                    hint: "The server still asks for a password to sleep. Add the sudo rule from step 4 of the setup guide."))
                return out
            }
            out.append(Check(ok: true, title: "Allowed to sleep without a password", hint: nil))
        } catch {
            out.append(Check(ok: false, title: "Run ssh", hint: error.localizedDescription))
        }
        return out
    }

    /// Turns raw ssh errors into something a person can act on.
    private static func explain(_ stderr: String, sudoStep: Bool) -> String {
        let lower = stderr.lowercased()
        if lower.contains("permission denied") {
            return "The server doesn't accept this key yet. Use “Copy public key” and add it to the server (step 3 of the setup guide)."
        }
        if lower.contains("no such file") && lower.contains("identity") || lower.contains("not accessible") {
            return "The key file wasn't found. Check the path, or use “Copy public key” to create one."
        }
        if lower.contains("sudo") {
            return "The server asks for a password to sleep. Add the sudo rule from step 4 of the setup guide."
        }
        if lower.contains("host key verification failed") {
            return "The server's identity changed. If you reinstalled it, remove its line from ~/.ssh/known_hosts."
        }
        let first = stderr.split(separator: "\n").first.map(String.init) ?? "ssh failed."
        return first
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

    /// Creates the key if it doesn't exist yet and returns the public half to paste on the server.
    static func ensureKey(at path: String) throws -> String {
        let expanded = (path as NSString).expandingTildeInPath
        if !FileManager.default.fileExists(atPath: expanded) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
            p.arguments = ["-t", "ed25519", "-f", expanded, "-N", "", "-C", "spark", "-q"]
            try p.run()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { throw SleepError.failed("Couldn't create the key.") }
        }
        return try String(contentsOfFile: expanded + ".pub", encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
