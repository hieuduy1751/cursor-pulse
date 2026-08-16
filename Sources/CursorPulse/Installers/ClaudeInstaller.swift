import CursorPulseCore
import Foundation

struct ClaudeInstaller: ToolInstaller {
    var tool: String { "claude" }
    var displayName: String { "Claude Code CLI" }

    var postInstallNote: String? {
        "Restart Claude Code (or start a new session) to load the hooks."
    }

    private var settingsFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
    }

    private var hookPath: String {
        Paths.hooksDir.appendingPathComponent("claude.sh").path
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
        return [
            "UserPromptSubmit": [["hooks": [workingHandler]]],
            "PreToolUse": [["matcher": "*", "hooks": [preToolHandler]]],
            "PostToolUse": [["matcher": "*", "hooks": [workingHandler]]],
            "Stop": [["hooks": [stopHandler]]],
        ]
    }

    var isInstalled: Bool {
        guard let obj = JSONFiles.load(settingsFile),
              let hooks = obj["hooks"] as? [String: Any] else { return false }
        return hooks["cursorpulse_installed"] as? Bool == true || hooks["PreToolUse"] != nil
    }

    func install() {
        Paths.ensure()
        guard HookScripts.materialize("claude.sh", as: "claude.sh", executable: true) != nil else { return }
        var obj = JSONFiles.load(settingsFile) ?? [:]
        var hooks = obj["hooks"] as? [String: Any] ?? [:]
        for (k, v) in cursorPulseHooks {
            hooks[k] = v
        }
        hooks["cursorpulse_installed"] = true
        obj["hooks"] = hooks
        JSONFiles.save(settingsFile, obj)
    }

    func uninstall() {
        guard var obj = JSONFiles.load(settingsFile),
              var hooks = obj["hooks"] as? [String: Any] else { return }
        for k in cursorPulseHooks.keys {
            hooks.removeValue(forKey: k)
        }
        hooks.removeValue(forKey: "cursorpulse_installed")
        if hooks.isEmpty {
            obj.removeValue(forKey: "hooks")
        } else {
            obj["hooks"] = hooks
        }
        JSONFiles.save(settingsFile, obj)
    }
}
