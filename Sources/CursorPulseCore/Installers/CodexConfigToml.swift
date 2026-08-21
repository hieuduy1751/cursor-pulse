import CryptoKit
import Foundation

enum CodexConfigToml {
    static var configPath: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/config.toml")
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func trustHash(eventLabel: String, matcher: String?, command: String, timeout: Int) -> String {
        var identity: [String: Any] = [
            "event_name": eventLabel,
            "hooks": [[
                "type": "command",
                "command": command,
                "async": false,
                "timeout": timeout,
            ] as [String: Any]],
        ]
        if let matcher { identity["matcher"] = matcher }
        let data = (try? JSONSerialization.data(
            withJSONObject: identity,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )) ?? Data()
        return "sha256:" + sha256Hex(data)
    }

    private static func escaped(_ key: String) -> String {
        key.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func upsertHookState(key: String, hash: String, in url: URL = configPath) {
        var text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let header = "[hooks.state.\"\(escaped(key))\"]"
        let stateBlock = "\(header)\ntrusted_hash = \"\(hash)\"\n"

        if let range = text.range(of: header) {
            let afterHeader = text.index(range.upperBound, offsetBy: 0)
            var blockEnd = afterHeader
            let remaining = text[afterHeader...]
            for lineRange in remaining.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = String(lineRange)
                if line.hasPrefix("[") || !(line.isEmpty || line.hasPrefix("trusted_hash") || line.hasPrefix("#")) {
                    break
                }
                blockEnd = text.index(blockEnd, offsetBy: line.count + 1)
                if blockEnd > text.endIndex { blockEnd = text.endIndex; break }
            }
            text.replaceSubrange(afterHeader ..< blockEnd, with: "\ntrusted_hash = \"\(hash)\"\n")
        } else {
            if !text.isEmpty, !text.hasSuffix("\n") { text += "\n" }
            text += "\n" + stateBlock
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func removeHookState(keys: [String], in url: URL = configPath) {
        guard var text = (try? String(contentsOf: url, encoding: .utf8)), !keys.isEmpty else { return }
        for key in keys {
            let header = "[hooks.state.\"\(escaped(key))\"]\n"
            guard let range = text.range(of: header) else { continue }
            var end = range.upperBound
            while end < text.endIndex {
                let lineEnd = text[end...].firstIndex(of: "\n") ?? text.endIndex
                let line = String(text[end ..< lineEnd])
                if line.hasPrefix("[") { break }
                end = lineEnd < text.endIndex ? text.index(lineEnd, offsetBy: 1) : text.endIndex
            }
            text.removeSubrange(range.lowerBound ..< end)
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
