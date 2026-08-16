import Foundation

public enum AgentTool: String, CaseIterable, Codable, Equatable {
    case antigravity = "antigravity"
    case codex = "codex"
    case claude = "claude"
    case cursor = "cursor"
    case opencode = "opencode"
    case debug = "debug"
    case custom = "custom"

    public static func from(raw: String) -> AgentTool {
        let clean = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.contains("antigravity") || clean.contains("agy") {
            return .antigravity
        } else if clean.contains("codex") {
            return .codex
        } else if clean.contains("claude") {
            return .claude
        } else if clean.contains("cursor") {
            return .cursor
        } else if clean.contains("opencode") {
            return .opencode
        } else if clean.contains("debug") {
            return .debug
        } else {
            return .custom
        }
    }

    public var systemImage: String {
        switch self {
        case .antigravity: return "atom"
        case .codex: return "terminal.fill"
        case .claude: return "sparkles"
        case .cursor: return "chevron.right.square.fill"
        case .opencode: return "chevron.left.forwardslash.chevron.right"
        case .debug: return "ladybug.fill"
        case .custom: return "cpu.fill"
        }
    }

    public var displayName: String {
        switch self {
        case .antigravity: return "Antigravity"
        case .codex: return "Codex CLI"
        case .claude: return "Claude Code"
        case .cursor: return "Cursor"
        case .opencode: return "OpenCode"
        case .debug: return "Simulation"
        case .custom: return "Custom Agent"
        }
    }
}

public struct ActiveAgentSummary: Equatable, Identifiable {
    public let tool: String
    public let agent: AgentTool
    public let state: UniversalAgentState
    public let sessionCount: Int

    public var id: String { tool }

    public init(tool: String, agent: AgentTool, state: UniversalAgentState, sessionCount: Int) {
        self.tool = tool
        self.agent = agent
        self.state = state
        self.sessionCount = sessionCount
    }

    public var priorityRank: Int {
        switch state {
        case .error: return 0
        case .needsApproval: return 1
        case .needsInput: return 2
        case .working: return 3
        case .queued: return 4
        case .ready: return 5
        case .stopped: return 6
        case .inactive: return 7
        }
    }

    public static func aggregateState(from records: [SessionRecord]) -> UniversalAgentState {
        let states = records.map { UniversalAgentState.normalize($0.state) }
        if states.contains(.error) { return .error }
        if states.contains(.needsApproval) { return .needsApproval }
        if states.contains(.needsInput) { return .needsInput }
        if states.contains(.working) { return .working }
        if states.contains(.queued) { return .queued }
        if states.contains(.ready) { return .ready }
        if states.contains(.stopped) { return .stopped }
        return .inactive
    }
}

public struct SessionRecord: Codable, Equatable, Identifiable {
    public var tool: String
    public var state: String
    public var ts: TimeInterval
    public var cwd: String?
    public var session: String

    public var id: String { session }

    public init(tool: String, state: String, ts: TimeInterval, cwd: String?, session: String) {
        self.tool = tool
        self.state = state
        self.ts = ts
        self.cwd = cwd
        self.session = session
    }
}
