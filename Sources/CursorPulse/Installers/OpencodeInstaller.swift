import CursorPulseCore
import Foundation

struct OpencodeInstaller: ToolInstaller {
    var tool: String { "opencode" }
    var displayName: String { "OpenCode" }

    var postInstallNote: String? {
        "Restart opencode (or start a new session) to load the plugin."
    }

    private let pluginEntry = "./plugins/cursorpulse.js"

    private var configFile: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/opencode/opencode.json")
    }

    private var pluginFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/opencode/plugins/cursorpulse.js")
    }

    var isInstalled: Bool {
        guard FileManager.default.fileExists(atPath: pluginFile.path) else { return false }
        let entries = JSONFiles.load(configFile)?["plugin"] as? [String] ?? []
        return entries.contains(pluginEntry)
    }

    func install() {
        guard HookScripts.materialize("cursorpulse.opencode.js", as: "cursorpulse.js", executable: false) != nil,
              let content = try? String(contentsOf: Paths.hooksDir.appendingPathComponent("cursorpulse.js"), encoding: .utf8)
        else { return }
        try? FileManager.default.createDirectory(
            at: pluginFile.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? content.write(to: pluginFile, atomically: true, encoding: .utf8)

        var obj = JSONFiles.load(configFile) ?? [:]
        var entries = obj["plugin"] as? [String] ?? []
        if !entries.contains(pluginEntry) {
            entries.append(pluginEntry)
        }
        obj["plugin"] = entries
        JSONFiles.save(configFile, obj)
    }

    func uninstall() {
        try? FileManager.default.removeItem(at: pluginFile)
        guard var obj = JSONFiles.load(configFile) else { return }
        if var entries = obj["plugin"] as? [String] {
            entries.removeAll { $0 == pluginEntry }
            obj["plugin"] = entries
            JSONFiles.save(configFile, obj)
        }
    }
}
