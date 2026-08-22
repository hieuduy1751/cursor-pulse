import XCTest
@testable import CursorPulseCore

final class AgentToolTests: XCTestCase {
    func testFromRawMapsPiAndOmp() {
        XCTAssertEqual(AgentTool.from(raw: "pi"), .pi)
        XCTAssertEqual(AgentTool.from(raw: "omp"), .omp)
        XCTAssertEqual(AgentTool.from(raw: "oh my pi"), .omp)
    }

    func testNewToolsExposeDisplayNames() {
        XCTAssertFalse(AgentTool.pi.displayName.isEmpty)
        XCTAssertFalse(AgentTool.omp.displayName.isEmpty)
        XCTAssertFalse(AgentTool.pi.systemImage.isEmpty)
        XCTAssertFalse(AgentTool.omp.systemImage.isEmpty)
    }
}
