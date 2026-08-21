import SwiftUI
import CursorPulseCore

struct StateColorsPage: View {
    let model: CursorPulseState
    @Binding var page: ActiveMenuPage

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    page = .main
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("State Colors")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button("Reset") {
                    model.colors.resetToDefaults()
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.bottom, 6)

            Text("Customize the badge and tag color for each agent state:")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(UniversalAgentState.allCases, id: \.self) { state in
                        HStack {
                            Circle()
                                .fill(model.colors.color(for: state))
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(state.displayName)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                if state.isActionRequired {
                                    Text("Action Required")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.orange)
                                } else if state.isActionRecommended {
                                    Text("Action Recommended")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.green)
                                }
                            }

                            Spacer()

                            ColorPicker(
                                "",
                                selection: Binding(
                                    get: { model.colors.color(for: state) },
                                    set: { model.colors.setColor($0, for: state) }
                                ),
                                supportsOpacity: false
                            )
                            .labelsHidden()
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            Divider()
                .padding(.vertical, 8)

            HStack(spacing: 8) {
                Button("Reset to Defaults") {
                    model.colors.resetToDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)

                Button("Done") {
                    page = .main
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
