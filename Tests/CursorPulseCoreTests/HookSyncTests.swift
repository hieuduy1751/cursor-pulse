import XCTest
@testable import CursorPulseCore

private final class SpyInstaller: ToolInstaller {
    let tool: String
    let displayName: String
    var isInstalled: Bool
    var postInstallNote: String? { nil }
    private(set) var installCalls = 0
    private(set) var uninstallCalls = 0

    init(tool: String, isInstalled: Bool) {
        self.tool = tool
        self.displayName = tool
        self.isInstalled = isInstalled
    }

    func install() { installCalls += 1 }
    func uninstall() { uninstallCalls += 1 }
}

final class HookSyncTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "HookSyncTests-\(UUID().uuidString)"

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Fresh random suite per test => isolated, empty defaults.
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        if let defaults {
            defaults.removePersistentDomain(forName: suiteName)
        }
        try super.tearDownWithError()
    }

    func testSkipsWhenNoAppVersionAvailable() {
        // e.g. bare `swift run` where the bundle carries no version.
        let installed = SpyInstaller(tool: "claude", isInstalled: true)
        XCTAssertEqual(HookSync.refreshInstalledHooks(installers: [installed], appVersion: nil, defaults: defaults), nil)
        XCTAssertEqual(HookSync.refreshInstalledHooks(installers: [installed], appVersion: "", defaults: defaults), nil)
        XCTAssertEqual(installed.installCalls, 0)
        XCTAssertNil(defaults.string(forKey: HookSync.versionKey))
    }

    func testRefreshesOnlyInstalledToolsOncePerVersion() {
        let claude = SpyInstaller(tool: "claude", isInstalled: true)
        let cursor = SpyInstaller(tool: "cursor", isInstalled: false)

        XCTAssertEqual(HookSync.refreshInstalledHooks(installers: [claude, cursor], appVersion: "0.2.0", defaults: defaults), 1)
        XCTAssertEqual(claude.uninstallCalls, 1)
        XCTAssertEqual(claude.installCalls, 1, "uninstalled tool must not be resurrected")
        XCTAssertEqual(cursor.installCalls, 0)
        XCTAssertEqual(defaults.string(forKey: HookSync.versionKey), "0.2.0")

        // Same version again: no-op.
        XCTAssertNil(HookSync.refreshInstalledHooks(installers: [claude, cursor], appVersion: "0.2.0", defaults: defaults))
        XCTAssertEqual(claude.installCalls, 1)

        // New version: refreshes again.
        XCTAssertEqual(HookSync.refreshInstalledHooks(installers: [claude, cursor], appVersion: "0.3.0", defaults: defaults), 1)
        XCTAssertEqual(claude.installCalls, 2)
    }

    func testRealInstallersGetFreshScriptsAndRegistrations() throws {
        try makeClaudeFixtures()

        let settingsFile = sandbox.appendingPathComponent("claude/settings.json")
        let hooksDir = sandbox.appendingPathComponent("hooks")
        let installer = ClaudeInstaller(settingsFile: settingsFile, hooksDir: hooksDir)
        installer.install()
        XCTAssertTrue(installer.isInstalled)

        // Simulate a stale deployment from an older app version.
        let deployedScript = hooksDir.appendingPathComponent("claude.sh")
        try "#!/bin/bash\n# STALE\necho old\n".write(to: deployedScript, atomically: true, encoding: .utf8)

        let refreshed = HookSync.refreshInstalledHooks(
            installers: [installer],
            appVersion: "9.9.9",
            defaults: defaults
        )
        XCTAssertEqual(refreshed, 1)

        let content = try String(contentsOf: deployedScript, encoding: .utf8)
        XCTAssertFalse(content.contains("# STALE"), "deployed script must be replaced by the bundled copy")

        // Registration survives the round trip and stays detected as installed.
        XCTAssertTrue(installer.isInstalled)
        let obj = try XCTUnwrap(JSONFiles.load(settingsFile))
        let hooks = try XCTUnwrap(obj["hooks"] as? [String: Any])
        XCTAssertEqual(hooks["cursorpulse_installed"] as? Bool, true)
    }

    // MARK: - Fixtures

    private var sandbox: URL!

    private func makeClaudeFixtures() throws {
        sandbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("hooksync-tests-\(UUID().uuidString)", isDirectory: true)
        let fixtures = sandbox.appendingPathComponent("fixtures")
        try FileManager.default.createDirectory(at: fixtures, withIntermediateDirectories: true)
        try "#!/bin/bash\nexit 0\n"
            .write(to: fixtures.appendingPathComponent("claude.sh"), atomically: true, encoding: .utf8)

        let fixtureRoot = sandbox.appendingPathComponent("fixtures")
        HookScripts.resourceLocator = { resource in
            let url = fixtureRoot.appendingPathComponent(resource)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    override func tearDown() {
        HookScripts.resourceLocator = nil
        if let sandbox, FileManager.default.fileExists(atPath: sandbox.path) {
            try? FileManager.default.removeItem(at: sandbox)
        }
        super.tearDown()
    }
}
