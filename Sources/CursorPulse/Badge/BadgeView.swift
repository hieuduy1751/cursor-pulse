import SwiftUI
import CursorPulseCore

enum BadgeState: Equatable {
    case working
    case needsInput
    case needsApproval
    case queued
    case ready
    case error
    case stopped
    case inactive
    case hidden

    init(universal: UniversalAgentState) {
        switch universal {
        case .working: self = .working
        case .needsInput: self = .needsInput
        case .needsApproval: self = .needsApproval
        case .queued: self = .queued
        case .ready: self = .ready
        case .error: self = .error
        case .stopped: self = .stopped
        case .inactive: self = .inactive
        }
    }
}

@Observable
final class BadgeScene {
    var state: BadgeState = .hidden
    var activeAgents: [ActiveAgentSummary] = []
    var colors: StateColors
    var config: CursorConfig

    init(colors: StateColors = StateColors(), config: CursorConfig = CursorConfig()) {
        self.colors = colors
        self.config = config
    }
}

struct BadgeView: View {
    var scene: BadgeScene

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                content(time: t)
            }
        }
    }

    @ViewBuilder
    private func content(time: TimeInterval) -> some View {
        if scene.state == .hidden && scene.activeAgents.isEmpty {
            EmptyView()
        } else {
            let agentInfo: (state: BadgeState, color: Color, agent: AgentTool) = {
                if !scene.activeAgents.isEmpty {
                    let index = Int(floor(time)) % scene.activeAgents.count
                    let current = scene.activeAgents[index]
                    let st = BadgeState(universal: current.state)
                    let col = scene.colors.color(for: current.state)
                    return (st, col, current.agent)
                } else {
                    let st = scene.state
                    let uState: UniversalAgentState = (st == .ready ? .ready : .inactive)
                    let col = scene.colors.color(for: uState)
                    return (st, col, .antigravity)
                }
            }()

            agentBadge(time: time, state: agentInfo.state, color: agentInfo.color, agent: agentInfo.agent)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func agentBadge(time: TimeInterval, state: BadgeState, color: Color, agent: AgentTool) -> some View {
        let iconSize = scene.config.iconSize
        let haloSize = iconSize + 10.0
        let discSize = iconSize + 6.0

        return ZStack {
            switch state {
            case .working:
                spinnerLoader(time: time, size: haloSize, color: color, speed: 0.9)
            case .needsInput:
                glowHalo(time: time, baseSize: haloSize, color: color)
            case .needsApproval:
                spinnerLoader(time: time, size: haloSize, color: color, speed: 0.65)
            case .queued:
                spinnerLoader(time: time, size: haloSize, color: color, speed: 1.8)
            case .ready:
                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: haloSize, height: haloSize)
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .frame(width: haloSize - 2, height: haloSize - 2)
                    .shadow(color: color.opacity(0.8), radius: 3)
            case .error:
                spinnerLoader(time: time, size: haloSize, color: color, speed: 0.5)
            case .stopped:
                Circle()
                    .stroke(color.opacity(0.6), lineWidth: 1.5)
                    .frame(width: haloSize - 2, height: haloSize - 2)
            case .inactive:
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 1)
                    .frame(width: haloSize - 4, height: haloSize - 4)
            case .hidden:
                EmptyView()
            }

            Circle()
                .fill(scene.config.effectiveBackground)
                .frame(width: discSize, height: discSize)
                .overlay(
                    Circle().stroke(scene.config.showBorder ? color.opacity(0.4) : Color.clear, lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(scene.config.backgroundOpacity > 0.2 ? 0.35 : 0.0),
                    radius: 2,
                    y: 1
                )

            AgentIconView(agent: agent, size: iconSize)
        }
    }

    private func spinnerLoader(time: TimeInterval, size: CGFloat, color: Color, speed: Double = 0.9) -> some View {
        let angle = (time.truncatingRemainder(dividingBy: speed) / speed) * 360.0
        return ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 2.0)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0.05, to: 0.75)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            color.opacity(0.0),
                            color.opacity(0.45),
                            color
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(angle))
                .shadow(color: color.opacity(0.8), radius: 3)
        }
    }

    private func glowHalo(time: TimeInterval, baseSize: CGFloat, color: Color) -> some View {
        let opacity = 0.35 + 0.25 * sin(time * 3.5)
        return ZStack {
            Circle()
                .fill(color.opacity(opacity))
                .frame(width: baseSize + 4, height: baseSize + 4)
            Circle()
                .stroke(color, lineWidth: 1.5)
                .frame(width: baseSize, height: baseSize)
        }
    }
}
