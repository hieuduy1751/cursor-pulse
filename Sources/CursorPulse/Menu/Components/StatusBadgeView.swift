import SwiftUI
import CursorPulseCore

struct StatusBadgeView: View {
    let model: CursorPulseState

    var body: some View {
        if !model.isEnabled {
            return AnyView(
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text("Paused")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
                .fixedSize()
            )
        }

        let summaries = model.window.scene.activeAgents
        if let top = summaries.first {
            let color = model.colors.color(for: top.state)
            let label = summaries.count > 1 ? "\(summaries.count) Agents" : top.state.displayName
            return AnyView(
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                    AgentIconView(agent: top.agent, size: 12)
                    Text(label)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.14))
                .clipShape(Capsule())
                .fixedSize()
            )
        } else {
            let color = model.colors.color(for: .inactive)
            return AnyView(
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                    Text("Inactive")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.14))
                .clipShape(Capsule())
                .fixedSize()
            )
        }
    }
}
