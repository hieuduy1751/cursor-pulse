import Foundation

public struct SemanticVersion: Comparable, CustomStringConvertible, Equatable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?

    public var description: String {
        if let prerelease, !prerelease.isEmpty {
            return "\(major).\(minor).\(patch)-\(prerelease)"
        }
        return "\(major).\(minor).\(patch)"
    }

    public init?(from string: String) {
        var clean = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.lowercased().hasPrefix("v") {
            clean.removeFirst()
        }
        let parts = clean.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        let versionNumbers = parts[0].split(separator: ".")
        guard versionNumbers.count >= 1,
              let maj = Int(versionNumbers[0]) else {
            return nil
        }
        self.major = maj
        self.minor = versionNumbers.count > 1 ? (Int(versionNumbers[1]) ?? 0) : 0
        self.patch = versionNumbers.count > 2 ? (Int(versionNumbers[2]) ?? 0) : 0
        self.prerelease = parts.count > 1 ? String(parts[1]) : nil
    }

    public init(major: Int, minor: Int, patch: Int, prerelease: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }
        if lhs.prerelease == nil && rhs.prerelease != nil {
            return false
        }
        if lhs.prerelease != nil && rhs.prerelease == nil {
            return true
        }
        if let lp = lhs.prerelease, let rp = rhs.prerelease {
            return lp < rp
        }
        return false
    }
}
