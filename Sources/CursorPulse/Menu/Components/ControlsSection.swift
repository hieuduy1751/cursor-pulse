import SwiftUI
import CursorPulseCore

struct ControlsSection: View {
    let model: CursorPulseState

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cursor Tracking")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(model.isEnabled ? "Active • Tracking agent sessions" : "Paused • Badge hidden")
                        .font(.caption2)
                        .foregroundColor(model.isEnabled ? .secondary : .orange)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { model.isEnabled },
                    set: { model.isEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(model.isEnabled ? Color.blue.opacity(0.08) : Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "macwindow.badge.plus")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Open at Login")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(model.launchAtLogin.isEnabled ? "Automatic startup on login" : "Manual startup only")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { model.launchAtLogin.isEnabled },
                    set: { model.launchAtLogin.isEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
