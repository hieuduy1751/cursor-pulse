import XCTest
@testable import CursorPulseCore

final class SessionStoreTests: XCTestCase {
    func testStateNormalization() {
        XCTAssertEqual(UniversalAgentState.normalize("ready"), .ready)
        XCTAssertEqual(UniversalAgentState.normalize("done"), .ready)
        XCTAssertEqual(UniversalAgentState.normalize("working"), .working)
        XCTAssertEqual(UniversalAgentState.normalize("busy"), .working)
        XCTAssertEqual(UniversalAgentState.normalize("idle"), .inactive)
        XCTAssertEqual(UniversalAgentState.normalize("inactive"), .inactive)
        XCTAssertEqual(UniversalAgentState.normalize("needs_input"), .needsInput)
        XCTAssertEqual(UniversalAgentState.normalize("needs_approval"), .needsApproval)
    }

    func testAggregateState() {
        let cursorReady = SessionRecord(tool: "cursor", state: "ready", ts: 100, cwd: nil, session: "s1")
        let claudeIdle = SessionRecord(tool: "claude", state: "inactive", ts: 100, cwd: nil, session: "s2")
        
        XCTAssertEqual(ActiveAgentSummary.aggregateState(from: [cursorReady]), .ready)
        XCTAssertEqual(ActiveAgentSummary.aggregateState(from: [claudeIdle]), .inactive)
        
        let cursorWorking = SessionRecord(tool: "cursor", state: "working", ts: 100, cwd: nil, session: "s1")
        XCTAssertEqual(ActiveAgentSummary.aggregateState(from: [cursorWorking, cursorReady]), .working)
    }

    func testRecordActiveTTL() {
        let now: TimeInterval = 1000
        
        // Working record within 15m TTL
        let workingRecent = SessionRecord(tool: "cursor", state: "working", ts: now - 30, cwd: nil, session: "w1")
        XCTAssertTrue(SessionStore.isRecordActive(workingRecent, now: now))
        
        // Working record past 15m TTL
        let workingOld = SessionRecord(tool: "cursor", state: "working", ts: now - 16 * 60, cwd: nil, session: "w2")
        XCTAssertFalse(SessionStore.isRecordActive(workingOld, now: now))
        
        // Ready record within 10s TTL
        let readyRecent = SessionRecord(tool: "claude", state: "ready", ts: now - 5, cwd: nil, session: "r1")
        XCTAssertTrue(SessionStore.isRecordActive(readyRecent, now: now))
        
        // Ready record past 10s TTL
        let readyOld = SessionRecord(tool: "claude", state: "ready", ts: now - 15, cwd: nil, session: "r2")
        XCTAssertFalse(SessionStore.isRecordActive(readyOld, now: now))
        
        // Inactive record is never active
        let inactiveRec = SessionRecord(tool: "claude", state: "inactive", ts: now, cwd: nil, session: "i1")
        XCTAssertFalse(SessionStore.isRecordActive(inactiveRec, now: now))
    }
}
