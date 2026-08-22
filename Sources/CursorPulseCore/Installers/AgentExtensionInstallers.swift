import Foundation

/// Shared engine for coding agents that auto-discover TypeScript extensions
/// from `<agentDir>/extensions/`. Both pi (`~/.pi/agent`) and Oh My Pi
/// (`~/.omp/agent`, plus `~/.omp/profiles/<name>/agent`) load every `.ts`
/// module found there with no config-file registration, so installing means
/// materializing one substituted extension file and uninstalling means
/// deleting it.
struct AgentExtensionInstaller {
    let tool: String
    let resource: String
    let agentDir: URL
    let hooksDir: URL
    let profileAgentDirs: [URL]

    var extensionFile: URL {
        agentDir.appendingPathComponent("extensions/cursorpulse.ts")
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: extensionFile.path)
    }

    /// The staged resource carries an @@TOOL@@ placeholder so a single bundled
    /// source serves every harness; each install bakes in its own tool name.
    func install() {
        Paths.ensure()
        guard let staged = HookScripts.materialize(resource, as: "cursorpulse.ts", executable: false, hooksDir: hooksDir),
              var content = try? String(contentsOf: staged, encoding: .utf8)
        else { return }
        content = content.replacingOccurrences(of: "@@TOOL@@", with: tool)
        for dir in [agentDir] + profileAgentDirs {
            let extDir = dir.appendingPathComponent("extensions")
            try? FileManager.default.createDirectory(at: extDir, withIntermediateDirectories: true)
            try? content.write(to: extDir.appendingPathComponent("cursorpulse.ts"), atomically: true, encoding: .utf8)
        }
    }

    func uninstall() {
        for dir in [agentDir] + profileAgentDirs {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("extensions/cursorpulse.ts"))
        }
    }
}

public struct PiInstaller: ToolInstaller {
    public var tool: String { "pi" }
    public var displayName: String { "Pi Coding Agent" }

    public var postInstallNote: String? {
        "Restart pi or run /reload to load the extension."
    }

    private let engine: AgentExtensionInstaller

    public init(agentDir: URL? = nil, hooksDir: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        // Both harnesses honor PI_CODING_AGENT_DIR for their agent directory.
        let resolved = agentDir ?? URL(
            fileURLWithPath: ProcessInfo.processInfo.environment["PI_CODING_AGENT_DIR"]
                ?? home.appendingPathComponent(".pi/agent").path
        )
        engine = AgentExtensionInstaller(
            tool: "pi",
            resource: "cursorpulse.agent.ts",
            agentDir: resolved,
            hooksDir: hooksDir ?? Paths.hooksDir,
            profileAgentDirs: []
        )
    }

    public var isInstalled: Bool { engine.isInstalled }
    public func install() { engine.install() }
    public func uninstall() { engine.uninstall() }
}

public struct OmpInstaller: ToolInstaller {
    public var tool: String { "omp" }
    public var displayName: String { "Oh My Pi" }

    public var postInstallNote: String? {
        "Restart omp (or start a new session) to load the extension."
    }

    private let engine: AgentExtensionInstaller

    public init(agentDir: URL? = nil, hooksDir: URL? = nil, profileAgentDirs: [URL]? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let resolved = agentDir ?? URL(
            fileURLWithPath: ProcessInfo.processInfo.environment["PI_CODING_AGENT_DIR"]
                ?? home.appendingPathComponent(".omp/agent").path
        )
        engine = AgentExtensionInstaller(
            tool: "omp",
            resource: "cursorpulse.agent.ts",
            agentDir: resolved,
            hooksDir: hooksDir ?? Paths.hooksDir,
            profileAgentDirs: profileAgentDirs ?? Self.discoveredProfileAgentDirs(home: home)
        )
    }

    public var isInstalled: Bool { engine.isInstalled }
    public func install() { engine.install() }
    public func uninstall() { engine.uninstall() }

    /// Existing `~/.omp/profiles/<name>/agent` directories; each profile loads
    /// extensions from its own agent dir.
    private static func discoveredProfileAgentDirs(home: URL) -> [URL] {
        let profiles = home.appendingPathComponent(".omp/profiles")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: profiles, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }
        return entries
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            }
            .map { $0.appendingPathComponent("agent") }
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("extensions").path) }
    }
}
