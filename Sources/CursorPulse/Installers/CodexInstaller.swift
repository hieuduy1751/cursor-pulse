import CursorPulseCore
import Foundation

struct CodexInstaller: ToolInstaller {
    var tool: String { "codex" }
    var displayName: String { "Codex CLI" }

    var postInstallNote: String? {
        nil
    }

    private var eventLabels: [String: String] {
        [
            "UserPromptSubmit": "user_prompt_submit",
            "PostToolUse": "post_tool_use",
            "PermissionRequest": "permission_request",
            "Stop": "stop",
            "SessionEnd": "session_end",
        ]
    }

    private var hooksFile: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/hooks.json")
    }

    private var hookPath: String { Paths.hooksDir.appendingPathComponent("codex.sh").path }

    private var events: [(event: String, state: String, matcher: String?, timeout: Int)] {
        [
            ("UserPromptSubmit", State.busy, nil, 10),
            ("PostToolUse", State.busy, "*", 10),
            ("PermissionRequest", State.waiting, "*", 10),
            ("Stop", State.idle, nil, 10),
            ("SessionEnd", State.idle, nil, 2),
        ]
    }

    private func handler(state: String, timeout: Int) -> [String: Any] {
        [
            "type": "command",
            "command": "\(hookPath) \(state)",
            "timeout": timeout,
        ]
    }

    private func group(state: String, matcher: String?, timeout: Int) -> [String: Any] {
        var group: [String: Any] = ["hooks": [handler(state: state, timeout: timeout)]]
        if let matcher { group["matcher"] = matcher }
        return group
    }

    var isInstalled: Bool {
        guard let hooks = JSONFiles.load(hooksFile)?["hooks"] as? [String: Any] else { return false }
        return hooks.values.contains { value in
            guard let groups = value as? [[String: Any]] else { return false }
            return groups.contains { Self.groupContains(hookPath, $0) }
        }
    }

    func install() {
        Paths.ensure()
        guard HookScripts.materialize("codex.sh", as: "codex.sh", executable: true) != nil else { return }
        var obj = JSONFiles.load(hooksFile) ?? [:]
        var hooks = obj["hooks"] as? [String: Any] ?? [:]
        var trustKeys: [(key: String, hash: String)] = []
        for spec in events {
            var groups = hooks[spec.event] as? [[String: Any]] ?? []
            if !groups.contains(where: { Self.groupContains(hookPath, $0) }) {
                groups.append(group(state: spec.state, matcher: spec.matcher, timeout: spec.timeout))
            }
            hooks[spec.event] = groups
            guard let label = eventLabels[spec.event],
                  let index = groups.lastIndex(where: { Self.groupContains(hookPath, $0) })
            else { continue }
            let key = "\(hooksFile.path):\(label):\(index):0"
            let hash = CodexConfigToml.trustHash(
                eventLabel: label,
                matcher: spec.matcher,
                command: "\(hookPath) \(spec.state)",
                timeout: spec.timeout
            )
            trustKeys.append((key, hash))
        }
        obj["hooks"] = hooks
        JSONFiles.save(hooksFile, obj)
        for entry in trustKeys {
            CodexConfigToml.upsertHookState(key: entry.key, hash: entry.hash)
        }
    }

    func uninstall() {
        var obj = JSONFiles.load(hooksFile) ?? [:]
        guard var hooks = obj["hooks"] as? [String: Any] else { return }
        var removedKeys: [String] = []
        for (event, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            for (index, group) in groups.enumerated() where Self.groupContains(hookPath, group) {
                if let label = eventLabels[event] {
                    removedKeys.append("\(hooksFile.path):\(label):\(index):0")
                }
            }
            let filtered = groups.filter { !Self.groupContains(hookPath, $0) }
            if filtered.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = filtered
            }
        }
        if hooks.isEmpty {
            obj.removeValue(forKey: "hooks")
        } else {
            obj["hooks"] = hooks
        }
        if obj.isEmpty || obj.keys.allSatisfy({ $0 == "description" }) {
            try? FileManager.default.removeItem(at: hooksFile)
        } else {
            JSONFiles.save(hooksFile, obj)
        }
        if !removedKeys.isEmpty {
            CodexConfigToml.removeHookState(keys: removedKeys)
        }
    }

    private static func groupContains(_ marker: String, _ group: [String: Any]) -> Bool {
        guard let handlers = group["hooks"] as? [[String: Any]] else { return false }
        return handlers.contains { ($0["command"] as? String)?.contains(marker) == true }
    }
}
