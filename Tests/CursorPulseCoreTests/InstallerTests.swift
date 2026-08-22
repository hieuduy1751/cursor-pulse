import XCTest
@testable import CursorPulseCore

final class InstallerTests: XCTestCase {
    private var sandbox: URL!
    private var hooksDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sandbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("cursorpulse-tests-\(UUID().uuidString)", isDirectory: true)
        hooksDir = sandbox.appendingPathComponent("hooks")
        try FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true)

        let fixtureRoot = sandbox.appendingPathComponent("fixtures")
        HookScripts.resourceLocator = { resource in
            let url = fixtureRoot.appendingPathComponent(resource)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return url
        }
    }

    override func tearDownWithError() throws {
        HookScripts.resourceLocator = nil
        if let sandbox, FileManager.default.fileExists(atPath: sandbox.path) {
            try FileManager.default.removeItem(at: sandbox)
        }
        try super.tearDownWithError()
    }

    private func makeFixture(_ resource: String, content: String = "#!/bin/bash\nexit 0\n") throws -> URL {
        let fixtures = sandbox.appendingPathComponent("fixtures")
        try FileManager.default.createDirectory(at: fixtures, withIntermediateDirectories: true)
        let url = fixtures.appendingPathComponent(resource)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func foreignGroup(command: String) -> [[String: Any]] {
        [["hooks": [["type": "command", "command": command, "timeout": 10]]]]
    }

    // MARK: - ClaudeInstaller

    func testClaudeInstallRoundTrip() throws {
        try makeFixture("claude.sh")
        let settingsFile = sandbox.appendingPathComponent("claude/settings.json")

        // Foreign-only config must NOT be detected as installed (regression:
        // previously any PreToolUse key triggered a false positive).
        JSONFiles.save(settingsFile, [
            "hooks": ["PreToolUse": foreignGroup(command: "/usr/bin/my_own_hook.sh")]
        ])
        let installer = ClaudeInstaller(settingsFile: settingsFile, hooksDir: hooksDir)
        XCTAssertFalse(installer.isInstalled)

        installer.install()
        XCTAssertTrue(installer.isInstalled)

        let obj = try XCTUnwrap(JSONFiles.load(settingsFile))
        let hooks = try XCTUnwrap(obj["hooks"] as? [String: Any])
        XCTAssertEqual(Set(hooks.keys), Set(["UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop", "SessionEnd", "cursorpulse_installed"]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: hooksDir.appendingPathComponent("claude.sh").path))

        // Foreign PreToolUse hook must survive the install (merged, not replaced).
        let preToolAfterInstall = try XCTUnwrap(hooks["PreToolUse"] as? [[String: Any]])
        XCTAssertEqual(preToolAfterInstall.count, 2)

        // Re-install must be idempotent (no duplicate groups).
        installer.install()
        let reinstalled = try XCTUnwrap(JSONFiles.load(settingsFile))
        let reinstalledHooks = try XCTUnwrap(reinstalled["hooks"] as? [String: Any])
        XCTAssertEqual((reinstalledHooks["PreToolUse"] as? [[String: Any]])?.count, 2)

        // Uninstall removes only CursorPulse entries and preserves foreign ones.
        installer.uninstall()
        XCTAssertFalse(installer.isInstalled)
        let after = try XCTUnwrap(JSONFiles.load(settingsFile))
        let afterHooks = try XCTUnwrap(after["hooks"] as? [String: Any])
        let preTool = try XCTUnwrap(afterHooks["PreToolUse"] as? [[String: Any]])
        XCTAssertEqual(preTool.count, 1)
        let handlers = try XCTUnwrap(preTool[0]["hooks"] as? [[String: Any]])
        XCTAssertEqual(handlers[0]["command"] as? String, "/usr/bin/my_own_hook.sh")
        XCTAssertNil(afterHooks["cursorpulse_installed"])
    }

    // MARK: - CursorInstaller

    func testCursorInstallRoundTripPreservesForeignEntries() throws {
        try makeFixture("cursor.sh")
        let hooksFile = sandbox.appendingPathComponent("cursor/hooks.json")
        JSONFiles.save(hooksFile, [
            "hooks": ["stop": foreignGroup(command: "/usr/bin/user_stop_hook.sh")]
        ])

        let installer = CursorInstaller(hooksFile: hooksFile, hooksDir: hooksDir)
        XCTAssertFalse(installer.isInstalled)

        installer.install()
        XCTAssertTrue(installer.isInstalled)
        let obj = try XCTUnwrap(JSONFiles.load(hooksFile))
        let installedHooks = try XCTUnwrap(obj["hooks"] as? [String: Any])
        XCTAssertEqual(
            Set(installedHooks.keys),
            Set(["beforeSubmitPrompt", "beforeShellExecution", "afterFileEdit", "postToolUse", "stop", "sessionEnd"])
        )

        installer.uninstall()
        XCTAssertFalse(installer.isInstalled)
        let after = try XCTUnwrap(JSONFiles.load(hooksFile))
        let hooks = try XCTUnwrap(after["hooks"] as? [String: Any])
        let stop = try XCTUnwrap(hooks["stop"] as? [[String: Any]])
        XCTAssertEqual(stop.count, 1)
        let handlers = try XCTUnwrap(stop[0]["hooks"] as? [[String: Any]])
        XCTAssertEqual(handlers[0]["command"] as? String, "/usr/bin/user_stop_hook.sh")
    }

    func testCursorUninstallCleansLegacyPreToolUseRegistration() throws {
        try makeFixture("cursor.sh")
        let hooksFile = sandbox.appendingPathComponent("cursor/hooks.json")
        // Simulate a config created by an older version that registered preToolUse
        // (Cursor hook entries are flat {"command": ...} objects).
        JSONFiles.save(hooksFile, [
            "hooks": ["preToolUse": [["command": "\(hooksDir.appendingPathComponent("cursor.sh").path) pre_tool"]]]
        ])

        let installer = CursorInstaller(hooksFile: hooksFile, hooksDir: hooksDir)
        installer.install()
        XCTAssertTrue(installer.isInstalled)

        installer.uninstall()
        XCTAssertFalse(installer.isInstalled)
        let obj = try XCTUnwrap(JSONFiles.load(hooksFile))
        let hooks = try XCTUnwrap(obj["hooks"] as? [String: Any])
        XCTAssertNil(hooks["preToolUse"], "legacy preToolUse entry must be removed on uninstall")
        let residual = hooks.values.contains { value in
            guard let groups = value as? [[String: Any]] else { return false }
            return groups.contains { group in
                ((group["hooks"] ?? group) as? [[String: Any]])?.contains {
                    ($0["command"] as? String)?.contains("cursor.sh") == true
                } == true
            }
        }
        XCTAssertFalse(residual, "no cursor.sh entries may remain after uninstall")
    }

    // MARK: - AntigravityInstaller

    func testAntigravityInstallRoundTrip() throws {
        try makeFixture("antigravity.sh")
        let hooksFile = sandbox.appendingPathComponent("gemini/hooks.json")
        JSONFiles.save(hooksFile, ["user_key": "user_value"])

        let installer = AntigravityInstaller(hooksFile: hooksFile, hooksDir: hooksDir)
        XCTAssertFalse(installer.isInstalled)

        installer.install()
        XCTAssertTrue(installer.isInstalled)
        let obj = try XCTUnwrap(JSONFiles.load(hooksFile))
        XCTAssertEqual(obj["user_key"] as? String, "user_value")
        XCTAssertNotNil(obj["cursorpulse"])

        installer.uninstall()
        XCTAssertFalse(installer.isInstalled)
        let after = try XCTUnwrap(JSONFiles.load(hooksFile))
        XCTAssertEqual(after["user_key"] as? String, "user_value")
        XCTAssertNil(after["cursorpulse"])
    }

    // MARK: - CodexInstaller

    func testCodexInstallWritesTrustHashesAndUninstallCleansThem() throws {
        try makeFixture("codex.sh")
        let hooksFile = sandbox.appendingPathComponent("codex/hooks.json")
        let configFile = sandbox.appendingPathComponent("codex/config.toml")

        let installer = CodexInstaller(hooksFile: hooksFile, hooksDir: hooksDir, codexConfigFile: configFile)
        XCTAssertFalse(installer.isInstalled)

        installer.install()
        XCTAssertTrue(installer.isInstalled)

        let toml = try String(contentsOf: configFile, encoding: .utf8)
        XCTAssertTrue(toml.contains("[hooks.state."))
        XCTAssertTrue(toml.contains("trusted_hash = \"sha256:"))

        installer.uninstall()
        XCTAssertFalse(installer.isInstalled)
        let cleanedToml = try String(contentsOf: configFile, encoding: .utf8)
        XCTAssertFalse(cleanedToml.contains("[hooks.state."))
    }

    func testCodexInstallMigratesStaleHookCommands() throws {
        try makeFixture("codex.sh")
        let hooksFile = sandbox.appendingPathComponent("codex/hooks.json")
        let configFile = sandbox.appendingPathComponent("codex/config.toml")
        let hookPath = hooksDir.appendingPathComponent("codex.sh").path

        // Simulate an older install: Stop reported idle, permissions as waiting.
        JSONFiles.save(hooksFile, [
            "hooks": [
                "Stop": [["hooks": [["type": "command", "command": "\(hookPath) idle", "timeout": 10]]]],
                "PermissionRequest": [["matcher": "*", "hooks": [["type": "command", "command": "\(hookPath) waiting", "timeout": 10]]]],
            ]
        ])

        let installer = CodexInstaller(hooksFile: hooksFile, hooksDir: hooksDir, codexConfigFile: configFile)
        XCTAssertTrue(installer.isInstalled)

        installer.install()
        XCTAssertTrue(installer.isInstalled)

        let obj = try XCTUnwrap(JSONFiles.load(hooksFile))
        let hooks = try XCTUnwrap(obj["hooks"] as? [String: Any])

        // Stale groups must be replaced in place, not duplicated.
        let stopGroups = try XCTUnwrap(hooks["Stop"] as? [[String: Any]])
        XCTAssertEqual(stopGroups.count, 1)
        let stopHandlers = try XCTUnwrap(stopGroups[0]["hooks"] as? [[String: Any]])
        XCTAssertEqual(stopHandlers[0]["command"] as? String, "\(hookPath) ready")

        let permGroups = try XCTUnwrap(hooks["PermissionRequest"] as? [[String: Any]])
        XCTAssertEqual(permGroups.count, 1)
        let permHandlers = try XCTUnwrap(permGroups[0]["hooks"] as? [[String: Any]])
        XCTAssertEqual(permHandlers[0]["command"] as? String, "\(hookPath) needs_approval")

        // Trust hashes for the migrated commands are present.
        let toml = try String(contentsOf: configFile, encoding: .utf8)
        XCTAssertTrue(toml.contains("[hooks.state."))
        XCTAssertTrue(toml.contains("trusted_hash = \"sha256:"))
    }

    // MARK: - OpencodeInstaller

    func testOpencodeInstallRoundTrip() throws {
        try makeFixture("cursorpulse.opencode.js", content: "export const plugin = () => ({});\n")
        let configFile = sandbox.appendingPathComponent("opencode/opencode.json")
        let pluginFile = sandbox.appendingPathComponent("opencode/plugins/cursorpulse.js")

        let installer = OpencodeInstaller(configFile: configFile, pluginFile: pluginFile, hooksDir: hooksDir)
        XCTAssertFalse(installer.isInstalled)

        installer.install()
        XCTAssertTrue(installer.isInstalled)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pluginFile.path))
        let obj = try XCTUnwrap(JSONFiles.load(configFile))
        XCTAssertEqual(obj["plugin"] as? [String], ["./plugins/cursorpulse.js"])

        installer.uninstall()
        XCTAssertFalse(installer.isInstalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pluginFile.path))
    }

    // MARK: - PiInstaller

    func testPiInstallRoundTrip() throws {
        try makeFixture("cursorpulse.agent.ts", content: "const TOOL = \"@@TOOL@@\";\nexport default (pi: any) => {};\n")
        let agentDir = sandbox.appendingPathComponent("pihome/agent")
        let extensionFile = agentDir.appendingPathComponent("extensions/cursorpulse.ts")

        let installer = PiInstaller(agentDir: agentDir, hooksDir: hooksDir)
        XCTAssertFalse(installer.isInstalled)

        installer.install()
        XCTAssertTrue(installer.isInstalled)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extensionFile.path))
        let content = try String(contentsOf: extensionFile, encoding: .utf8)
        XCTAssertFalse(content.contains("@@TOOL@@"), "tool placeholder must be substituted")
        XCTAssertTrue(content.contains("\"pi\""), "extension must report tool name pi")

        installer.uninstall()
        XCTAssertFalse(installer.isInstalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: extensionFile.path))
    }

    // MARK: - OmpInstaller

    func testOmpInstallRoundTrip() throws {
        let agentDir = sandbox.appendingPathComponent("omphome/agent")
        let extensionFile = agentDir.appendingPathComponent("extensions/cursorpulse.ts")
        try makeFixture("cursorpulse.agent.ts", content: "const TOOL = \"@@TOOL@@\";\nexport default (pi: any) => {};\n")

        let installer = OmpInstaller(agentDir: agentDir, hooksDir: hooksDir)
        XCTAssertFalse(installer.isInstalled)

        installer.install()
        XCTAssertTrue(installer.isInstalled)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extensionFile.path))
        let content = try String(contentsOf: extensionFile, encoding: .utf8)
        XCTAssertFalse(content.contains("@@TOOL@@"), "tool placeholder must be substituted")
        XCTAssertTrue(content.contains("\"omp\""), "extension must report tool name omp")

        installer.uninstall()
        XCTAssertFalse(installer.isInstalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: extensionFile.path))
    }

    func testOmpInstallCoversExistingProfiles() throws {
        try makeFixture("cursorpulse.agent.ts", content: "export default (pi: any) => {};\n")
        let agentDir = sandbox.appendingPathComponent("omphome/agent")
        let profileAgentDir = sandbox.appendingPathComponent("omphome/profiles/work/agent")
        try FileManager.default.createDirectory(
            at: profileAgentDir.appendingPathComponent("extensions"), withIntermediateDirectories: true
        )
        try makeFixture("cursorpulse.agent.ts", content: "const TOOL = \"@@TOOL@@\";\nexport default (pi: any) => {};\n")
        let installer = OmpInstaller(agentDir: agentDir, hooksDir: hooksDir, profileAgentDirs: [profileAgentDir])
        installer.install()
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: profileAgentDir.appendingPathComponent("extensions/cursorpulse.ts").path
        ))

        installer.uninstall()
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: profileAgentDir.appendingPathComponent("extensions/cursorpulse.ts").path
        ))
    }
 
    // MARK: - HookScripts.deploy

    func testDeployMakesScriptsExecutable() throws {
        let dest = HookScripts.deploy("#!/bin/bash\nexit 0\n", as: "deployed.sh", executable: true, hooksDir: hooksDir)
        let url = try XCTUnwrap(dest)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = attributes[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o755)
    }
}
