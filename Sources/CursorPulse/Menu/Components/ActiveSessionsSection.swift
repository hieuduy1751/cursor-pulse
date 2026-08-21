import SwiftUI
import CursorPulseCore

struct ActiveSessionsSection: View {
    let model: CursorPulseState

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Active Sessions")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                if !model.records.isEmpty {
                    Text("\(model.records.count) active")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if model.records.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "circle.slash")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("No active agent sessions")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                VStack(spacing: 4) {
                    ForEach(model.records) { rec in
                        let agent = AgentTool.from(raw: rec.tool)
                        let st = UniversalAgentState.normalize(rec.state)
                        let color = model.colors.color(for: st)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 7) {
                                AgentIconView(agent: agent, size: 18)

                                Text(rec.tool)
                                    .font(.callout)
                                    .fontWeight(.medium)

                                Text(st.displayName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(color.opacity(0.18))
                                    .foregroundColor(color)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Spacer()
                                Text(rec.session.count > 10 ? String(rec.session.prefix(8)) + "…" : rec.session)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .monospaced()
                            }
                            if st.isActionRequired {
                                Text("← ACTION REQUIRED")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(color)
                                    .padding(.leading, 25)
                            } else if st.isActionRecommended {
                                Text("← ACTION RECOMMENDED")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(color)
                                    .padding(.leading, 25)
                            }
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }
}
