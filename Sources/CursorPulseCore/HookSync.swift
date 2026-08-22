import Foundation

/// Re-applies hook installations for every currently-installed agent so that
/// updated hook scripts, registrations, and trust hashes ship automatically
/// when the app itself is updated. Runs at most once per app version and
/// never resurrects integrations the user has explicitly uninstalled.
public enum HookSync {
    public static let versionKey = "cursorpulse_last_hook_sync_version"

    /// Refresh all installed integrations if `appVersion` differs from the
    /// last synced version recorded in `defaults`.
    ///
    /// Returns the number of integrations refreshed, or nil when the sync
    /// was skipped (no bundle version available, e.g. bare `swift run`,
    /// or this version was already synced).
    @discardableResult
    public static func refreshInstalledHooks(
        installers: [any ToolInstaller],
        appVersion: String?,
        defaults: UserDefaults = .standard
    ) -> Int? {
        guard let appVersion, !appVersion.isEmpty else { return nil }
        guard defaults.string(forKey: versionKey) != appVersion else { return nil }

        var refreshed = 0
        for installer in installers where installer.isInstalled {
            // A precise uninstall + fresh install guarantees the deployed
            // script, registration shape, and (for Codex) trust hashes match
            // this build, while preserving any foreign entries in the user's
            // configs. All installers are idempotent and merge-safe.
            installer.uninstall()
            installer.install()
            refreshed += 1
        }
        defaults.set(appVersion, forKey: versionKey)
        return refreshed
    }
}
