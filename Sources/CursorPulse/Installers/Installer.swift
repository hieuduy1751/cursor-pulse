import CursorPulseCore
import Foundation

protocol ToolInstaller {
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

enum HookScripts {
    static func materialize(_ resource: String, as fileName: String, executable: Bool) -> URL? {
        let url: URL? = {
            if let dotIndex = resource.lastIndex(of: ".") {
                let base = String(resource[..<dotIndex])
                let ext = String(resource[resource.index(after: dotIndex)...])
                if let u = Bundle.module.url(forResource: base, withExtension: ext, subdirectory: "hooks") {
                    return u
                }
                if let u = Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "hooks") {
                    return u
                }
                if let u = Bundle.main.url(forResource: base, withExtension: ext) {
                    return u
                }
            }
            if let u = Bundle.module.url(forResource: resource, withExtension: nil, subdirectory: "hooks") {
                return u
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
        }()

        guard let sourceURL = url,
              let content = try? String(contentsOf: sourceURL, encoding: .utf8)
        else { return nil }
        Paths.ensure()
        let dest = Paths.hooksDir.appendingPathComponent(fileName)
        try? content.write(to: dest, atomically: true, encoding: .utf8)
        if executable {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
        }
        return dest
    }
}
