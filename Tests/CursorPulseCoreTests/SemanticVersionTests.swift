import XCTest
@testable import CursorPulseCore

final class SemanticVersionTests: XCTestCase {
    func testParsing() {
        let v1 = SemanticVersion(from: "v0.1.1")
        XCTAssertEqual(v1?.major, 0)
        XCTAssertEqual(v1?.minor, 1)
        XCTAssertEqual(v1?.patch, 1)
        XCTAssertNil(v1?.prerelease)

        let v2 = SemanticVersion(from: "1.2.3-beta.1")
        XCTAssertEqual(v2?.major, 1)
        XCTAssertEqual(v2?.minor, 2)
        XCTAssertEqual(v2?.patch, 3)
        XCTAssertEqual(v2?.prerelease, "beta.1")

        let v3 = SemanticVersion(from: "2")
        XCTAssertEqual(v3?.major, 2)
        XCTAssertEqual(v3?.minor, 0)
        XCTAssertEqual(v3?.patch, 0)

        XCTAssertNil(SemanticVersion(from: "invalid"))
    }

    func testComparison() {
        let v010 = SemanticVersion(from: "v0.1.0")!
        let v011 = SemanticVersion(from: "0.1.1")!
        let v020 = SemanticVersion(from: "v0.2.0")!
        let v100 = SemanticVersion(from: "1.0.0")!

        XCTAssertTrue(v010 < v011)
        XCTAssertTrue(v011 < v020)
        XCTAssertTrue(v020 < v100)
        XCTAssertFalse(v100 < v011)
        XCTAssertEqual(v011, SemanticVersion(from: "v0.1.1"))
    }
}
