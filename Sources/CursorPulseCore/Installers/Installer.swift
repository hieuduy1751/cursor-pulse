import Foundation

public protocol ToolInstaller {
    var tool: String { get }
    var displayName: String { get }
    var isInstalled: Bool { get }
    var postInstallNote: String? { get }
    func install()
    func uninstall()
}

enum JSONFiles {
    static func load(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any]
        else { return nil }
        return dict
    }

    static func save(_ url: URL, _ object: [String: Any]) {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            let backup = url.appendingPathExtension("cursorpulse.bak")
            if !fm.fileExists(atPath: backup.path) {
                try? fm.copyItem(at: url, to: backup)
            }
        }
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

public enum HookScripts {
    /// Test seam: when set, consulted first to locate a named hook resource.
    public static var resourceLocator: ((String) -> URL?)?

    /// Locate a bundled hook resource across app bundle and dev-tree locations.
    /// Note: hook scripts live in the CursorPulse app target's resources
    /// (copied to Contents/Resources/hooks by build-app.sh), so only
    /// Bundle.main lookups apply here.
    public static func locate(_ resource: String) -> URL? {
        if let url = resourceLocator?(resource) {
            return url
        }
        if let dotIndex = resource.lastIndex(of: ".") {
            let base = String(resource[..<dotIndex])
            let ext = String(resource[resource.index(after: dotIndex)...])
            if let u = Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "hooks") {
                return u
            }
            if let u = Bundle.main.url(forResource: base, withExtension: ext) {
                return u
            }
        }
        if let u = Bundle.main.url(forResource: resource, withExtension: nil, subdirectory: "hooks") {
            return u
        }
        if let resURL = Bundle.main.resourceURL?.appendingPathComponent("hooks/\(resource)") {
            if FileManager.default.fileExists(atPath: resURL.path) {
                return resURL
            }
        }
        let devPath = URL(fileURLWithPath: "Sources/CursorPulse/Resources/hooks/\(resource)")
        if FileManager.default.fileExists(atPath: devPath.path) {
            return devPath
        }
        var current = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        for _ in 0..<5 {
            let check = current.appendingPathComponent("Sources/CursorPulse/Resources/hooks/\(resource)")
            if FileManager.default.fileExists(atPath: check.path) {
                return check
            }
            current = current.deletingLastPathComponent()
        }
        return nil
    }

    public static func materialize(
        _ resource: String,
        as fileName: String,
        executable: Bool,
        hooksDir: URL = Paths.hooksDir
    ) -> URL? {
        guard let sourceURL = locate(resource),
              let content = try? String(contentsOf: sourceURL, encoding: .utf8)
        else { return nil }
        return deploy(content, as: fileName, executable: executable, hooksDir: hooksDir)
    }

    static func deploy(_ content: String, as fileName: String, executable: Bool, hooksDir: URL) -> URL? {
        Paths.ensure()
        try? FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true)
        let dest = hooksDir.appendingPathComponent(fileName)
        do {
            try content.write(to: dest, atomically: true, encoding: .utf8)
            if executable {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
            }
            return dest
        } catch {
            return nil
        }
    }
}
