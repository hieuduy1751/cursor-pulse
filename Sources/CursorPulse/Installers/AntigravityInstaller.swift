import CursorPulseCore
import Foundation

struct AntigravityInstaller: ToolInstaller {
    var tool: String { "antigravity" }
    var displayName: String { "Antigravity (IDE + AGY CLI)" }

    var postInstallNote: String? {
        "Restart Antigravity (or start a new AGY CLI session) to load the hooks."
    }

    private var hooksFile: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".gemini/config/hooks.json")
    }

    private var hookPath: String { Paths.hooksDir.appendingPathComponent("antigravity.sh").path }

    private var cursorPulseEntry: [String: Any] {
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
            "PreInvocation": [workingHandler],
            "PreToolUse": [["matcher": "*", "hooks": [preToolHandler]]],
            "PostToolUse": [["matcher": "*", "hooks": [workingHandler]]],
            "Stop": [stopHandler],
        ]
    }

    var isInstalled: Bool {
        JSONFiles.load(hooksFile)?["cursorpulse"] != nil
    }

    func install() {
        Paths.ensure()
        guard HookScripts.materialize("antigravity.sh", as: "antigravity.sh", executable: true) != nil else { return }
        var obj = JSONFiles.load(hooksFile) ?? [:]
        obj["cursorpulse"] = cursorPulseEntry
        JSONFiles.save(hooksFile, obj)
    }

    func uninstall() {
        var obj = JSONFiles.load(hooksFile) ?? [:]
        obj.removeValue(forKey: "cursorpulse")
        if obj.isEmpty {
            try? FileManager.default.removeItem(at: hooksFile)
        } else {
            JSONFiles.save(hooksFile, obj)
        }
    }
}
