import Foundation

final class QuotaFetcher {
    private let settings = AppSettings.shared

    func fetch() async throws -> QuotaData {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let json = try self.runFetchScript()
                    let quota = try self.parseJSON(json)
                    continuation.resume(returning: quota)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Run bundled shell script

    private func runFetchScript() throws -> String {
        // Find the script — check bundle first, then source tree
        let scriptName = "fetch-quota.sh"
        var scriptPath: String?

        if let bundled = Bundle.main.path(forResource: "fetch-quota", ofType: "sh") {
            scriptPath = bundled
        } else {
            // Fallback: look relative to the executable
            let execURL = URL(fileURLWithPath: CommandLine.arguments[0])
            let resourcesDir = execURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources")
                .appendingPathComponent(scriptName)
            if FileManager.default.fileExists(atPath: resourcesDir.path) {
                scriptPath = resourcesDir.path
            }
        }

        guard let path = scriptPath else {
            throw FetchError.parseFailed("fetch-quota.sh not found in bundle")
        }

        // Resolve full claude CLI path
        let cliPath = resolveClaudePath()
        guard !cliPath.isEmpty else {
            throw FetchError.cliNotFound
        }

        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [path, cliPath]
        process.standardOutput = stdout
        process.standardError = stderr

        // GUI apps get minimal env — add everything claude needs for auth
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Set working directory to a trusted claude project dir to avoid trust dialog
        let trustedDir = findTrustedDirectory(home: home)
        process.currentDirectoryURL = URL(fileURLWithPath: trustedDir)
        var env = ProcessInfo.processInfo.environment
        let fullPath = [
            "\(home)/.local/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(home)/.claude/local",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].joined(separator: ":")
        env["PATH"] = fullPath
        env["HOME"] = home
        env["USER"] = NSUserName()
        env["SHELL"] = env["SHELL"] ?? "/bin/zsh"
        env["TERM"] = "xterm-256color"
        process.environment = env

        try process.run()
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let errOutput = String(data: errData, encoding: .utf8) ?? ""

        if output.isEmpty || output.contains("\"error\"") {
            if output.contains("cli_not_found") {
                throw FetchError.cliNotFound
            }
            let detail = errOutput.isEmpty ? output : errOutput
            throw FetchError.parseFailed("Script failed: \(detail.prefix(200))")
        }

        return output
    }

    // MARK: - Trusted Directory

    private func findTrustedDirectory(home: String) -> String {
        // Prefer a previously-trusted Claude project directory that is NOT inside
        // a macOS TCC-protected folder (Documents, Desktop, Downloads) to avoid
        // re-prompting for file access on every reinstall.
        let tccProtected = ["Documents", "Desktop", "Downloads", "Movies", "Music", "Pictures"]
            .map { "\(home)/\($0)" }

        let projectsDir = "\(home)/.claude/projects"
        let fm = FileManager.default

        if let entries = try? fm.contentsOfDirectory(atPath: projectsDir) {
            let sorted = entries.sorted { $0.count > $1.count }
            for entry in sorted {
                guard !entry.contains("."), !entry.contains("worktree") else { continue }
                let decoded = entry.replacingOccurrences(of: "-", with: "/")
                guard !tccProtected.contains(where: { decoded.hasPrefix($0) }) else { continue }
                if fm.fileExists(atPath: decoded) {
                    return decoded
                }
            }
        }

        // Fall back to ~/.claude — the expect script handles any trust dialog
        let claudeDir = "\(home)/.claude"
        return fm.fileExists(atPath: claudeDir) ? claudeDir : home
    }

    // MARK: - CLI Path Resolution

    private func resolveClaudePath() -> String {
        // User override
        if !settings.cliPath.isEmpty && FileManager.default.fileExists(atPath: settings.cliPath) {
            return settings.cliPath
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(home)/.claude/local/claude",
            "\(home)/.nvm/versions/node/v20.19.5/bin/claude",
        ]

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Last resort: try `which` with an expanded PATH
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["bash", "-lc", "which claude"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let result = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return result
    }

    // MARK: - Parse JSON output

    private func parseJSON(_ json: String) throws -> QuotaData {
        guard let data = json.data(using: .utf8) else {
            throw FetchError.parseFailed("Invalid JSON encoding")
        }

        struct ScriptOutput: Decodable {
            let sessionPercent: Int
            let sessionResetTime: String
            let weeklyAllPercent: Int
            let weeklyAllResetTime: String
            let weeklySonnetPercent: Int
            let weeklySonnetResetTime: String
        }

        let decoded = try JSONDecoder().decode(ScriptOutput.self, from: data)

        return QuotaData(
            sessionPercent: decoded.sessionPercent,
            sessionResetTime: decoded.sessionResetTime.trimmingCharacters(in: .whitespaces),
            weeklyAllPercent: decoded.weeklyAllPercent,
            weeklyAllResetTime: decoded.weeklyAllResetTime.trimmingCharacters(in: .whitespaces),
            weeklySonnetPercent: decoded.weeklySonnetPercent,
            weeklySonnetResetTime: decoded.weeklySonnetResetTime.trimmingCharacters(in: .whitespaces)
        )
    }
}
