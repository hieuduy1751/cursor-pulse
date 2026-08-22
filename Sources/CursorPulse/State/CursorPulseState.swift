import AppKit
import CursorPulseCore
import Foundation
import QuartzCore

final class CursorTracker: NSObject {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var displayLink: CADisplayLink?
    private var fallbackTimer: Timer?
    private weak var window: BadgeWindow?

    init(window: BadgeWindow) {
        self.window = window
    }

    func start() {
        stop()
        window?.followCursor()

        let eventMask: NSEvent.EventTypeMask = [
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged
        ]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] _ in
            self?.window?.followCursor()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.window?.followCursor()
            return event
        }

        if let screen = NSScreen.main {
            let link = screen.displayLink(target: self, selector: #selector(onDisplayLink(_:)))
            link.add(to: .main, forMode: .common)
            self.displayLink = link
        } else {
            let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
                self?.window?.followCursor()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.fallbackTimer = timer
        }
    }

    @objc private func onDisplayLink(_ link: CADisplayLink) {
        window?.followCursor()
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        displayLink?.invalidate()
        displayLink = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    deinit {
        stop()
    }
}

@Observable
final class CursorPulseState {
    let store: SessionStore
    let colors: StateColors
    let config: CursorConfig
    let launchAtLogin: LaunchAtLoginManager
    let window: BadgeWindow
    let updater: UpdateManager
    private(set) var installers: [any ToolInstaller]
    private(set) var installedFlags: [String: Bool] = [:]
    private(set) var records: [SessionRecord] = []
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "cursorpulse_enabled")
            if !isEnabled {
                doneTimer?.invalidate()
                doneTimer = nil
                tracker.stop()
                window.orderOut(nil)
                visibleBadgeState = .hidden
            } else {
                recompute()
            }
        }
    }

    private let tracker: CursorTracker
    private var doneTimer: Timer?
    private var visibleBadgeState: BadgeState = .hidden

    init() {
        store = SessionStore()
        colors = StateColors()
        config = CursorConfig()
        launchAtLogin = LaunchAtLoginManager.shared
        window = BadgeWindow(colors: colors, config: config)
        tracker = CursorTracker(window: window)
        updater = UpdateManager()
        let list: [any ToolInstaller] = [
            CodexInstaller(),
            ClaudeInstaller(),
            CursorInstaller(),
            AntigravityInstaller(),
            OpencodeInstaller(),
            PiInstaller(),
            OmpInstaller()
        ]
        self.installers = list
        var flags: [String: Bool] = [:]
        for installer in list {
            flags[installer.tool] = installer.isInstalled
        }
        self.installedFlags = flags
        if UserDefaults.standard.object(forKey: "cursorpulse_enabled") != nil {
            self.isEnabled = UserDefaults.standard.bool(forKey: "cursorpulse_enabled")
        } else {
            self.isEnabled = true
        }
    }

    func start() {
        store.onChange = { [weak self] in
            self?.recompute()
        }
        store.start()
        recompute()
        updater.checkForUpdates()
    }

    func refreshInstallerStatus() {
        for installer in installers {
            installedFlags[installer.tool] = installer.isInstalled
        }
    }

    private var seenActive = false

    private func recompute() {
        records = store.records
        guard isEnabled else {
            if visibleBadgeState != .hidden {
                tracker.stop()
                window.orderOut(nil)
                visibleBadgeState = .hidden
            }
            return
        }

        let grouped = Dictionary(grouping: records, by: { $0.tool })
        var summaries: [ActiveAgentSummary] = []
        for (toolName, toolRecords) in grouped {
            let agent = AgentTool.from(raw: toolName)
            let state = ActiveAgentSummary.aggregateState(from: toolRecords)
            if state != .inactive {
                summaries.append(ActiveAgentSummary(
                    tool: toolName,
                    agent: agent,
                    state: state,
                    sessionCount: toolRecords.count
                ))
            }
        }
        summaries.sort { $0.priorityRank < $1.priorityRank }
        window.scene.activeAgents = summaries

        let target: BadgeState
        if let top = summaries.first {
            target = BadgeState(universal: top.state)
        } else {
            target = .inactive
        }

        setBadge(target)
    }

    private func setBadge(_ state: BadgeState) {
        guard state != visibleBadgeState else { return }
        visibleBadgeState = state
        window.scene.state = state

        if state == .hidden {
            tracker.stop()
            window.orderOut(nil)
        } else {
            window.orderFrontRegardless()
            tracker.start()
        }
    }

    func setDebug(_ state: UniversalAgentState) {
        if state == .inactive {
            clearDebug()
        } else {
            SessionStore.report(tool: "debug", state: state.rawValue, session: "debug")
        }
    }

    func setMultiAgentDebug() {
        SessionStore.report(tool: "antigravity", state: State.working, session: "agy-1")
        SessionStore.report(tool: "claude", state: State.working, session: "claude-1")
        SessionStore.report(tool: "cursor", state: State.needsApproval, session: "cursor-1")
        SessionStore.report(tool: "codex", state: State.ready, session: "codex-1")
    }

    func clearDebug() {
        SessionStore.report(tool: "debug", state: State.inactive, session: "debug")
        SessionStore.report(tool: "antigravity", state: State.inactive, session: "agy-1")
        SessionStore.report(tool: "claude", state: State.inactive, session: "claude-1")
        SessionStore.report(tool: "cursor", state: State.inactive, session: "cursor-1")
        SessionStore.report(tool: "codex", state: State.inactive, session: "codex-1")
    }
}
