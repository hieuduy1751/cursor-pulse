import XCTest
@testable import CursorPulseCore

final class UpdateManagerTests: XCTestCase {
    func testReleaseAssetPicking() {
        let assets = [
            ReleaseAsset(name: "CursorPulse-v0.1.1-mac-x64.dmg", browser_download_url: "https://example.com/x64.dmg", size: 100),
            ReleaseAsset(name: "CursorPulse-v0.1.1-mac-x64.zip", browser_download_url: "https://example.com/x64.zip", size: 100),
            ReleaseAsset(name: "CursorPulse-v0.1.1-mac-arm64.dmg", browser_download_url: "https://example.com/arm64.dmg", size: 100),
            ReleaseAsset(name: "CursorPulse-v0.1.1-mac-arm64.zip", browser_download_url: "https://example.com/arm64.zip", size: 100),
            ReleaseAsset(name: "CursorPulse-v0.1.1-mac-universal.zip", browser_download_url: "https://example.com/uni.zip", size: 100),
        ]

        let armBest = UpdateManager.pickBestAsset(from: assets, forArchitecture: "arm64")
        XCTAssertEqual(armBest?.name, "CursorPulse-v0.1.1-mac-arm64.zip")

        let x64Best = UpdateManager.pickBestAsset(from: assets, forArchitecture: "x64")
        XCTAssertEqual(x64Best?.name, "CursorPulse-v0.1.1-mac-x64.zip")

        let fallbackAssets = [
            ReleaseAsset(name: "CursorPulse-v0.1.1-mac-universal.zip", browser_download_url: "https://example.com/uni.zip", size: 100),
        ]
        let fallback = UpdateManager.pickBestAsset(from: fallbackAssets, forArchitecture: "arm64")
        XCTAssertEqual(fallback?.name, "CursorPulse-v0.1.1-mac-universal.zip")
    }

    func testReleaseDecoding() throws {
        let json = """
        {
            "tag_name": "v0.1.1",
            "name": "v0.1.1 Release",
            "body": "Bug fixes",
            "html_url": "https://github.com/hieuduy1751/cursor-pulse/releases/tag/v0.1.1",
            "published_at": "2026-08-17T08:34:06Z",
            "assets": [
                {
                    "name": "CursorPulse-v0.1.1-mac-arm64.zip",
                    "browser_download_url": "https://github.com/hieuduy1751/cursor-pulse/releases/download/v0.1.1/CursorPulse-v0.1.1-mac-arm64.zip",
                    "size": 331776
                }
            ]
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertEqual(release.tag_name, "v0.1.1")
        XCTAssertEqual(release.assets.count, 1)
        XCTAssertEqual(release.assets[0].name, "CursorPulse-v0.1.1-mac-arm64.zip")
    }
    func testSecureDownloadSurvivesSourceDeletion() throws {
        // URLSession hands the delegate a temp file named like CFNetworkDownload_xxx.tmp
        // and deletes it the moment didFinishDownloadingTo returns. Securing the file
        // must therefore complete synchronously and stay valid after the source vanishes.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("CFNetworkDownload_\(UUID().uuidString).tmp")
        try Data("zip-bytes".utf8).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let manager = UpdateManager(currentVersion: "0.0.1")
        let secured = try manager.secureDownload(at: tmp)
        defer { try? FileManager.default.removeItem(at: secured) }

        // URLSession deletes whatever remains; a move-based capture leaves nothing.
        if FileManager.default.fileExists(atPath: tmp.path) {
            try FileManager.default.removeItem(at: tmp)
        }
        XCTAssertTrue(secured.lastPathComponent.hasSuffix(".zip"))
        XCTAssertEqual(try Data(contentsOf: secured), Data("zip-bytes".utf8))
    }
}
