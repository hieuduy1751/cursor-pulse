import Foundation
import CursorPulseCore

let validStates = [
    State.inactive, State.queued, State.working, State.needsInput,
    State.needsApproval, State.ready, State.error, State.stopped,
    State.busy, State.waiting, State.idle
]
let args = CommandLine.arguments
guard args.count > 1, validStates.contains(args[1].lowercased()) else {
    FileHandle.standardError.write("usage: cursorpulse-report <working|needs_input|needs_approval|ready|error|queued|stopped|inactive> (reads {tool, session_id, cwd} JSON from stdin)\n".data(using: .utf8)!)
    exit(2)
}
let state = args[1]

var tool = "custom"
var session = "unknown"
var cwd: String?

let data = FileHandle.standardInput.readDataToEndOfFile()
if !data.isEmpty, let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
    tool = (obj["tool"] as? String) ?? tool
    session = (obj["session_id"] as? String)
        ?? (obj["conversationId"] as? String)
        ?? session
    cwd = (obj["cwd"] as? String) ?? (obj["workspacePaths"] as? [String])?.first
}

SessionStore.report(tool: tool, state: state, session: session, cwd: cwd)
