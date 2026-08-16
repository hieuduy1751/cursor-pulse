import Foundation

public enum State {
    public static let inactive = "inactive"
    public static let queued = "queued"
    public static let working = "working"
    public static let needsInput = "needs_input"
    public static let needsApproval = "needs_approval"
    public static let ready = "ready"
    public static let error = "error"
    public static let stopped = "stopped"

    public static let busy = "busy"
    public static let waiting = "waiting"
    public static let idle = "idle"
}

public enum UniversalAgentState: String, CaseIterable, Codable, Equatable {
    case inactive = "inactive"
    case queued = "queued"
    case working = "working"
    case needsInput = "needs_input"
    case needsApproval = "needs_approval"
    case ready = "ready"
    case error = "error"
    case stopped = "stopped"

    public static func normalize(_ raw: String) -> UniversalAgentState {
        switch raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "inactive", "idle", "none", "off":
            return .inactive
        case "queued", "pending":
            return .queued
        case "working", "busy", "running", "active":
            return .working
        case "needs_input", "needsinput", "input", "waiting", "waiting_for_input", "ask":
            return .needsInput
        case "needs_approval", "needsapproval", "approval", "permission", "asked", "permission_request":
            return .needsApproval
        case "ready", "done", "finished", "completed", "success":
            return .ready
        case "error", "failed", "failure", "blocked", "err":
            return .error
        case "stopped", "cancelled", "canceled", "interrupted", "abort", "aborted":
            return .stopped
        default:
            return .inactive
        }
    }

    public var isActionRequired: Bool {
        switch self {
        case .needsInput, .needsApproval, .error:
            return true
        default:
            return false
        }
    }

    public var isActionRecommended: Bool {
        return self == .ready
    }

    public var displayName: String {
        switch self {
        case .inactive: return "Inactive"
        case .queued: return "Queued"
        case .working: return "Working"
        case .needsInput: return "Needs Input"
        case .needsApproval: return "Needs Approval"
        case .ready: return "Ready"
        case .error: return "Error"
        case .stopped: return "Stopped"
        }
    }
}

private let fsEventsCallback: FSEventStreamCallback = { _, info, _, _, _, _ in
    guard let info else { return }
    let store = Unmanaged<SessionStore>.fromOpaque(info).takeUnretainedValue()
    DispatchQueue.main.async { store.rescan() }
}

public final class SessionStore {
    public private(set) var records: [SessionRecord] = []
    public var onChange: (() -> Void)?

    private var stream: FSEventStreamRef?
    private var sweepTimer: Timer?
    private let ttl: TimeInterval = 15 * 60

    public init() {}

    public func start() {
        Paths.ensure()
        rescan()
        startWatching()
        sweepTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sweep()
        }
    }

    public func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        sweepTimer?.invalidate()
        sweepTimer = nil
    }

    private func startWatching() {
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        let path = Paths.sessionsDir.standardizedFileURL.path as CFString
        stream = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        )
        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    public func rescan() {
        let now = Date().timeIntervalSince1970
        var found: [SessionRecord] = []
        if let files = try? FileManager.default.contentsOfDirectory(
            at: Paths.sessionsDir, includingPropertiesForKeys: nil
        ) {
            for url in files where url.pathExtension == "json" {
                if let data = try? Data(contentsOf: url),
                   let rec = try? JSONDecoder().decode(SessionRecord.self, from: data) {
                    found.append(rec)
                }
            }
        }
        found = found.filter { now - $0.ts < ttl }
        let sorted = found.sorted { $0.ts > $1.ts }
        if sorted != records {
            records = sorted
            onChange?()
        }
    }

    private func sweep() {
        let now = Date().timeIntervalSince1970
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: Paths.sessionsDir, includingPropertiesForKeys: nil) {
            for url in files where url.pathExtension == "json" {
                if let data = try? Data(contentsOf: url),
                   let rec = try? JSONDecoder().decode(SessionRecord.self, from: data),
                   now - rec.ts >= ttl {
                    try? fm.removeItem(at: url)
                }
            }
        }
        rescan()
    }

    public static func report(tool: String, state: String, session: String, cwd: String? = nil) {
        Paths.ensure()
        let normalized = UniversalAgentState.normalize(state)
        let file = Paths.sessionFile(tool: tool, sessionID: session)
        if state == State.idle || normalized == .inactive {
            try? FileManager.default.removeItem(at: file)
            return
        }
        let rec = SessionRecord(
            tool: tool,
            state: normalized.rawValue,
            ts: Date().timeIntervalSince1970,
            cwd: cwd,
            session: session
        )
        if let data = try? JSONEncoder().encode(rec) {
            try? data.write(to: file, options: .atomic)
        }
    }
}
