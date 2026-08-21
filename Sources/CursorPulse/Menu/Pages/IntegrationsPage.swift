import SwiftUI
import CursorPulseCore

struct IntegrationsPage: View {
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

                Text("Integrations")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Color.clear
                    .frame(width: 44, height: 1)
            }
            .padding(.bottom, 6)

            Text("Manage tracking hooks & plugins for supported AI agents:")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(Array(model.installers.indices), id: \.self) { idx in
                        installerRow(for: model.installers[idx])
                    }
                }
            }

            Divider()
                .padding(.vertical, 8)

            HStack(spacing: 8) {
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

    private func installerRow(for installer: any ToolInstaller) -> some View {
        let agent = AgentTool.from(raw: installer.tool)
        let isInstalled = model.installedFlags[installer.tool] == true
        return HStack(spacing: 10) {
            AgentIconView(agent: agent, size: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(installer.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(isInstalled ? "Installed • Ready to track" : "Not Installed")
                    .font(.caption2)
                    .foregroundColor(isInstalled ? .secondary : Color.secondary.opacity(0.6))
            }

            Spacer()

            if isInstalled {
                Button("Uninstall") {
                    installer.uninstall()
                    model.refreshInstallerStatus()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("Install") {
                    installer.install()
                    model.refreshInstallerStatus()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
