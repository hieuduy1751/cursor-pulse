import Foundation

public struct OpencodeInstaller: ToolInstaller {
    public var tool: String { "opencode" }
    public var displayName: String { "OpenCode" }

    public var postInstallNote: String? {
        "Restart opencode (or start a new session) to load the plugin."
    }

    private let pluginEntry = "./plugins/cursorpulse.js"

    private let configFile: URL
    private let pluginFile: URL
    private let hooksDir: URL

    public init(configFile: URL? = nil, pluginFile: URL? = nil, hooksDir: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.configFile = configFile ?? home.appendingPathComponent(".config/opencode/opencode.json")
        self.pluginFile = pluginFile ?? home
            .appendingPathComponent(".config/opencode/plugins/cursorpulse.js")
        self.hooksDir = hooksDir ?? Paths.hooksDir
    }

    public var isInstalled: Bool {
        guard FileManager.default.fileExists(atPath: pluginFile.path) else { return false }
        let entries = JSONFiles.load(configFile)?["plugin"] as? [String] ?? []
        return entries.contains(pluginEntry)
    }

    public func install() {
        guard HookScripts.materialize("cursorpulse.opencode.js", as: "cursorpulse.js", executable: false, hooksDir: hooksDir) != nil,
              let content = try? String(contentsOf: hooksDir.appendingPathComponent("cursorpulse.js"), encoding: .utf8)
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

    public func uninstall() {
        try? FileManager.default.removeItem(at: pluginFile)
        guard var obj = JSONFiles.load(configFile) else { return }
        if var entries = obj["plugin"] as? [String] {
            entries.removeAll { $0 == pluginEntry }
            obj["plugin"] = entries
            JSONFiles.save(configFile, obj)
        }
    }
}
