import Foundation

public struct AntigravityInstaller: ToolInstaller {
    public var tool: String { "antigravity" }
    public var displayName: String { "Antigravity (IDE + AGY CLI)" }

    public var postInstallNote: String? {
        "Restart Antigravity (or start a new AGY CLI session) to load the hooks."
    }

    private let hooksFile: URL
    private let hookPath: String

    public init(hooksFile: URL? = nil, hooksDir: URL? = nil) {
        self.hooksFile = hooksFile
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".gemini/config/hooks.json")
        self.hookPath = (hooksDir ?? Paths.hooksDir).appendingPathComponent("antigravity.sh").path
    }

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

    public var isInstalled: Bool {
        JSONFiles.load(hooksFile)?["cursorpulse"] != nil
    }

    public func install() {
        Paths.ensure()
        guard HookScripts.materialize("antigravity.sh", as: "antigravity.sh", executable: true, hooksDir: hooksDir) != nil else { return }
        var obj = JSONFiles.load(hooksFile) ?? [:]
        obj["cursorpulse"] = cursorPulseEntry
        JSONFiles.save(hooksFile, obj)
    }

    public func uninstall() {
        var obj = JSONFiles.load(hooksFile) ?? [:]
        obj.removeValue(forKey: "cursorpulse")
        if obj.isEmpty {
            try? FileManager.default.removeItem(at: hooksFile)
        } else {
            JSONFiles.save(hooksFile, obj)
        }
    }

    private var hooksDir: URL {
        URL(fileURLWithPath: hookPath).deletingLastPathComponent()
    }
}
