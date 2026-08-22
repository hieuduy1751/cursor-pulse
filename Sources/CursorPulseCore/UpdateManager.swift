import Foundation
import Observation

public struct ReleaseAsset: Codable, Equatable {
    public let name: String
    public let browser_download_url: String
    public let size: Int

    public var downloadURL: URL? {
        URL(string: browser_download_url)
    }

    public init(name: String, browser_download_url: String, size: Int) {
        self.name = name
        self.browser_download_url = browser_download_url
        self.size = size
    }
}

public struct GitHubRelease: Codable, Equatable {
    public let tag_name: String
    public let name: String?
    public let body: String?
    public let html_url: String
    public let published_at: String?
    public let assets: [ReleaseAsset]

    public init(tag_name: String, name: String?, body: String?, html_url: String, published_at: String?, assets: [ReleaseAsset]) {
        self.tag_name = tag_name
        self.name = name
        self.body = body
        self.html_url = html_url
        self.published_at = published_at
        self.assets = assets
    }
}

public enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate(version: String)
    case available(version: String, release: GitHubRelease, asset: ReleaseAsset)
    case downloading(progress: Double)
    case installing
    case failed(error: String)

    public var isUpdateAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    public var isBusy: Bool {
        switch self {
        case .checking, .downloading, .installing:
            return true
        default:
            return false
        }
    }
}

@Observable
public final class UpdateManager: NSObject, URLSessionDownloadDelegate {
    public private(set) var status: UpdateStatus = .idle
    public private(set) var lastCheckDate: Date?
    public private(set) var currentVersion: String

    public let repo: String
    private var downloadSession: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private var targetAsset: ReleaseAsset?
    private var downloadProgressHandler: ((Double) -> Void)?

    public init(repo: String = "hieuduy1751/cursor-pulse", currentVersion: String? = nil) {
        self.repo = repo
        if let currentVersion {
            self.currentVersion = currentVersion
        } else {
            let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            self.currentVersion = bundleVersion ?? "0.2.1"
        }
        super.init()
    }

    public static func pickBestAsset(from assets: [ReleaseAsset], forArchitecture arch: String? = nil) -> ReleaseAsset? {
        let currentArch: String = {
            if let arch { return arch }
            #if arch(arm64)
            return "arm64"
            #elseif arch(x86_64)
            return "x64"
            #else
            return "universal"
            #endif
        }()

        let zipAssets = assets.filter { $0.name.hasSuffix(".zip") }
        if let direct = zipAssets.first(where: { $0.name.localizedCaseInsensitiveContains(currentArch) }) {
            return direct
        }
        if let universal = zipAssets.first(where: { $0.name.localizedCaseInsensitiveContains("universal") }) {
            return universal
        }
        return zipAssets.first
    }

    public func checkForUpdates(manual: Bool = false) {
        guard !status.isBusy else { return }
        status = .checking

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            status = .failed(error: "Invalid update URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("CursorPulse-App", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.lastCheckDate = Date()

                if let error {
                    self.status = .failed(error: error.localizedDescription)
                    return
                }

                guard let data,
                      let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                    self.status = .failed(error: "Could not parse release information.")
                    return
                }

                guard let latestSemVer = SemanticVersion(from: release.tag_name),
                      let currentSemVer = SemanticVersion(from: self.currentVersion) else {
                    self.status = .upToDate(version: self.currentVersion)
                    return
                }

                if latestSemVer > currentSemVer {
                    if let asset = Self.pickBestAsset(from: release.assets) {
                        self.status = .available(version: release.tag_name, release: release, asset: asset)
                    } else {
                        self.status = .failed(error: "No compatible update asset found for release \(release.tag_name).")
                    }
                } else {
                    self.status = .upToDate(version: self.currentVersion)
                }
            }
        }.resume()
    }

    public func installUpdate() {
        guard case let .available(_, _, asset) = status,
              let downloadURL = asset.downloadURL else { return }

        self.targetAsset = asset
        self.status = .downloading(progress: 0.0)

        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: downloadURL)
        self.downloadSession = session
        self.downloadTask = task
        task.resume()
    }

    private func finishDownloadSession() {
        downloadTask = nil
        downloadSession?.finishTasksAndInvalidate()
        downloadSession = nil
    }

    // MARK: - URLSessionDownloadDelegate
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.status = .downloading(progress: progress)
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // URLSession deletes `location` as soon as this delegate method returns,
        // so the file must be moved into our own staging directory synchronously.
        // Dispatching the move to another queue races the deletion and fails with
        // "The file "CFNetworkDownload_…" couldn't be copied".
        do {
            let zipURL = try secureDownload(at: location)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.status = .installing
                self.performUpdateSwap(zipURL: zipURL)
                if !self.status.isBusy {
                    self.finishDownloadSession()
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.status = .failed(error: "Installation error: \(error.localizedDescription)")
                self?.finishDownloadSession()
            }
        }
    }

    /// Moves a completed download into a private staging directory as update.zip.
    func secureDownload(at location: URL) throws -> URL {
        let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CursorPulseUpdate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let destination = stagingDir.appendingPathComponent("update.zip")
        do {
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            // Cross-volume fallback; URLSession temp files are normally on the same volume.
            try FileManager.default.copyItem(at: location, to: destination)
        }
        return destination
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.status = .failed(error: "Download failed: \(error.localizedDescription)")
                self.finishDownloadSession()
            }
        }
    }

    private func performUpdateSwap(zipURL: URL) {
        let fm = FileManager.default

        do {
            // Unzip using /usr/bin/ditto -xk
            let ditto = Process()
            ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            ditto.arguments = ["-xk", zipURL.path, zipURL.deletingLastPathComponent().path]

            try ditto.run()
            ditto.waitUntilExit()

            // Find extracted .app
            let contents = try fm.contentsOfDirectory(at: zipURL.deletingLastPathComponent(), includingPropertiesForKeys: nil)
            guard let extractedApp = contents.first(where: { $0.pathExtension == "app" }) else {
                status = .failed(error: "Update archive did not contain an application bundle.")
                return
            }

            let currentAppURL = Bundle.main.bundleURL
            guard currentAppURL.pathExtension == "app" else {
                status = .failed(error: "Running from non-app bundle: \(currentAppURL.path)")
                return
            }

            // Create detached updater script
            let stagingDir = zipURL.deletingLastPathComponent()
            let updaterScript = stagingDir.appendingPathComponent("updater.sh")
            let scriptContent = """
            #!/bin/bash
            OLD_PID=\(ProcessInfo.processInfo.processIdentifier)
            NEW_APP="\(extractedApp.path)"
            TARGET_APP="\(currentAppURL.path)"

            # Wait for main process to exit
            for i in {1..50}; do
                if ! kill -0 "$OLD_PID" 2>/dev/null; then
                    break
                fi
                sleep 0.2
            done

            # Clear quarantine attribute
            xattr -dr com.apple.quarantine "$NEW_APP" 2>/dev/null || true

            # Replace app bundle using renames only, so a failed step can be rolled back
            # and the existing installation is never left half-copied.
            if ! cp -R "$NEW_APP" "$TARGET_APP.update"; then
                exit 1
            fi
            if [ -d "$TARGET_APP" ] && ! mv "$TARGET_APP" "$TARGET_APP.old"; then
                rm -rf "$TARGET_APP.update"
                exit 1
            fi
            if ! mv "$TARGET_APP.update" "$TARGET_APP"; then
                [ -d "$TARGET_APP.old" ] && mv "$TARGET_APP.old" "$TARGET_APP"
                rm -rf "$TARGET_APP.update"
                exit 1
            fi
            rm -rf "$TARGET_APP.old"

            # Launch new app
            open -n "$TARGET_APP"

            # Clean staging directory
            rm -rf "\(stagingDir.path)"
            exit 0
            """

            try scriptContent.write(to: updaterScript, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: updaterScript.path)

            let swapProcess = Process()
            swapProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
            swapProcess.arguments = [updaterScript.path]
            try swapProcess.run()

            exit(0)
        } catch {
            status = .failed(error: "Installation error: \(error.localizedDescription)")
        }
    }
}
