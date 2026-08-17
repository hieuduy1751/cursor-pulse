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
}
