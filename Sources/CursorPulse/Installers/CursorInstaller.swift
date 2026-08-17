import CursorPulseCore
import Foundation

struct CursorInstaller: ToolInstaller {
    var tool: String { "cursor" }
    var displayName: String { "Cursor (IDE + Agent)" }

    var postInstallNote: String? {
        "Restart Cursor (or reopen workspace) to activate tracking hooks."
    }

    private var hooksFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor")
            .appendingPathComponent("hooks.json")
    }

    private var hookPath: String {
        Paths.hooksDir.appendingPathComponent("cursor.sh").path
    }

    private var targetHooks: [String: String] {
        [
            "beforeSubmitPrompt": "\(hookPath) working",
            "beforeShellExecution": "\(hookPath) needs_approval",
            "afterFileEdit": "\(hookPath) working",
            "preToolUse": "\(hookPath) pre_tool",
            "postToolUse": "\(hookPath) working",
            "stop": "\(hookPath) ready",
            "sessionEnd": "\(hookPath) idle",
        ]
    }

    var isInstalled: Bool {
        guard let obj = JSONFiles.load(hooksFile),
              let hooks = obj["hooks"] as? [String: Any] else { return false }
        if let arr = hooks["beforeSubmitPrompt"] as? [[String: Any]],
           arr.contains(where: { ($0["command"] as? String)?.contains("cursor.sh") == true }) {
            return true
        }
        return false
    }

    func install() {
        Paths.ensure()
        guard HookScripts.materialize("cursor.sh", as: "cursor.sh", executable: true) != nil else { return }
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

    func uninstall() {
        guard var obj = JSONFiles.load(hooksFile),
              var hooks = obj["hooks"] as? [String: Any] else { return }
        for event in targetHooks.keys {
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
}
