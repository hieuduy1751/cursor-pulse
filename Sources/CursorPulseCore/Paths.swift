import Foundation

public enum Paths {
    public static let dataDir: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cursorpulse")
    public static let sessionsDir: URL = dataDir.appendingPathComponent("sessions")
    public static let hooksDir: URL = dataDir.appendingPathComponent("hooks")

    public static func sessionFile(tool: String, sessionID: String) -> URL {
        sessionsDir.appendingPathComponent("\(sanitize(tool))__\(sanitize(sessionID)).json")
    }

    public static func ensure() {
        try? FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true)
    }

    private static func sanitize(_ value: String) -> String {
        value.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}
