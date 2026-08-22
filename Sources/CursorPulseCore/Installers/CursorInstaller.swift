import Foundation

public struct CursorInstaller: ToolInstaller {
    public var tool: String { "cursor" }
    public var displayName: String { "Cursor (IDE + Agent)" }

    public var postInstallNote: String? {
        "Restart Cursor (or reopen workspace) to activate tracking hooks."
    }

    private let hooksFile: URL
    private let hookPath: String

    public init(hooksFile: URL? = nil, hooksDir: URL? = nil) {
        self.hooksFile = hooksFile
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".cursor")
                .appendingPathComponent("hooks.json")
        self.hookPath = (hooksDir ?? Paths.hooksDir).appendingPathComponent("cursor.sh").path
    }

    /// Events registered by older versions but no longer used; kept so
    /// uninstall can clean stale entries left on existing machines.
    private static let legacyEvents: Set<String> = ["preToolUse"]

    private var targetHooks: [String: String] {
        [
            "beforeSubmitPrompt": "\(hookPath) working",
            "beforeShellExecution": "\(hookPath) needs_approval",
            "afterFileEdit": "\(hookPath) working",
            "postToolUse": "\(hookPath) working",
            "stop": "\(hookPath) ready",
            "sessionEnd": "\(hookPath) idle",
        ]
    }

    public var isInstalled: Bool {
        guard let obj = JSONFiles.load(hooksFile),
              let hooks = obj["hooks"] as? [String: Any] else { return false }
        if let arr = hooks["beforeSubmitPrompt"] as? [[String: Any]],
           arr.contains(where: { ($0["command"] as? String)?.contains("cursor.sh") == true }) {
            return true
        }
        return false
    }

    public func install() {
        Paths.ensure()
        guard HookScripts.materialize("cursor.sh", as: "cursor.sh", executable: true, hooksDir: hooksDir) != nil else { return }
        var obj = JSONFiles.load(hooksFile) ?? [:]
        obj["version"] = 1
        var hooks = obj["hooks"] as? [String: Any] ?? [:]

        for (event, cmd) in targetHooks {
            var eventList = hooks[event] as? [[String: Any]] ?? []
            if !eventList.contains(where: { ($0["command"] as? String)?.contains("cursor.sh") == true }) {
                eventList.append(["command": cmd])
            }
            hooks[event] = eventList
        }
        obj["hooks"] = hooks
        JSONFiles.save(hooksFile, obj)
    }

    public func uninstall() {
        guard var obj = JSONFiles.load(hooksFile),
              var hooks = obj["hooks"] as? [String: Any] else { return }
        for event in Set(targetHooks.keys).union(Self.legacyEvents) {
            if var eventList = hooks[event] as? [[String: Any]] {
                eventList.removeAll(where: { ($0["command"] as? String)?.contains("cursor.sh") == true })
                if eventList.isEmpty {
                    hooks.removeValue(forKey: event)
                } else {
                    hooks[event] = eventList
                }
            }
        }
        obj["hooks"] = hooks
        JSONFiles.save(hooksFile, obj)
    }

    private var hooksDir: URL {
        URL(fileURLWithPath: hookPath).deletingLastPathComponent()
    }
}
