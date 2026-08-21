import Foundation

public struct ClaudeInstaller: ToolInstaller {
    public var tool: String { "claude" }
    public var displayName: String { "Claude Code CLI" }

    public var postInstallNote: String? {
        "Restart Claude Code (or start a new session) to load the hooks."
    }

    private let settingsFile: URL
    private let hookPath: String

    public init(settingsFile: URL? = nil, hooksDir: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.settingsFile = settingsFile ?? home
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
        self.hookPath = (hooksDir ?? Paths.hooksDir).appendingPathComponent("claude.sh").path
    }

    private var cursorPulseHooks: [String: Any] {
        let workingHandler: [String: Any] = [
            "type": "command",
            "command": "\(hookPath) working",
            "timeout": 10,
        ]
        let preToolHandler: [String: Any] = [
            "type": "command",
            "command": "\(hookPath) pre_tool",
            "timeout": 10,
        ]
        let stopHandler: [String: Any] = [
            "type": "command",
            "command": "\(hookPath) stop",
            "timeout": 10,
        ]
        let idleHandler: [String: Any] = [
            "type": "command",
            "command": "\(hookPath) idle",
            "timeout": 5,
        ]
        return [
            "UserPromptSubmit": [["hooks": [workingHandler]]],
            "PreToolUse": [["matcher": "*", "hooks": [preToolHandler]]],
            "PostToolUse": [["matcher": "*", "hooks": [workingHandler]]],
            "Stop": [["hooks": [stopHandler]]],
            "SessionEnd": [["hooks": [idleHandler]]],
        ]
    }

    public var isInstalled: Bool {
        guard let obj = JSONFiles.load(settingsFile),
              let hooks = obj["hooks"] as? [String: Any] else { return false }
        if hooks["cursorpulse_installed"] as? Bool == true { return true }
        return Self.containsCursorPulseHook(hooks, marker: "claude.sh")
    }

    static func containsCursorPulseHook(_ hooks: [String: Any], marker: String) -> Bool {
        for (_, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            for group in groups {
                guard let handlers = group["hooks"] as? [[String: Any]] else { continue }
                if handlers.contains(where: { ($0["command"] as? String)?.contains(marker) == true }) {
                    return true
                }
            }
        }
        return false
    }

    public func install() {
        Paths.ensure()
        guard HookScripts.materialize("claude.sh", as: "claude.sh", executable: true, hooksDir: hooksDir) != nil else { return }
        var obj = JSONFiles.load(settingsFile) ?? [:]
        var hooks = obj["hooks"] as? [String: Any] ?? [:]
        for (k, v) in cursorPulseHooks {
            // Merge our hook groups into any existing ones (including the
            // user's own hooks) instead of replacing the whole event key.
            guard let incoming = v as? [[String: Any]] else {
                hooks[k] = v
                continue
            }
            var existing = hooks[k] as? [[String: Any]] ?? []
            for group in incoming where !Self.hasMatchingCommand(in: existing, for: group) {
                existing.append(group)
            }
            hooks[k] = existing
        }
        hooks["cursorpulse_installed"] = true
        obj["hooks"] = hooks
        JSONFiles.save(settingsFile, obj)
    }

    private static func commands(of group: [String: Any]) -> [String] {
        (group["hooks"] as? [[String: Any]])?.compactMap { $0["command"] as? String } ?? []
    }

    private static func hasMatchingCommand(in existing: [[String: Any]], for group: [String: Any]) -> Bool {
        let wanted = commands(of: group)
        return existing.contains { g in commands(of: g).contains { wanted.contains($0) } }
    }

    public func uninstall() {
        guard var obj = JSONFiles.load(settingsFile),
              var hooks = obj["hooks"] as? [String: Any] else { return }
        for key in cursorPulseHooks.keys {
            guard let groups = hooks[key] as? [[String: Any]] else { continue }
            let filtered = groups.filter { group in
                guard let handlers = group["hooks"] as? [[String: Any]] else { return true }
                return !handlers.contains(where: { ($0["command"] as? String)?.contains("claude.sh") == true })
            }
            if filtered.isEmpty {
                hooks.removeValue(forKey: key)
            } else {
                hooks[key] = filtered
            }
        }
        hooks.removeValue(forKey: "cursorpulse_installed")
        if hooks.isEmpty {
            obj.removeValue(forKey: "hooks")
        } else {
            obj["hooks"] = hooks
        }
        JSONFiles.save(settingsFile, obj)
    }

    private var hooksDir: URL {
        URL(fileURLWithPath: hookPath).deletingLastPathComponent()
    }
}
