import SwiftUI
import CursorPulseCore

enum ActiveMenuPage {
    case main
    case integrations
    case cursorSettings
    case stateColors
}

struct MenuView: View {
    let model: CursorPulseState
    let onQuit: () -> Void

    @SwiftUI.State private var activePage: ActiveMenuPage = .main

    init(model: CursorPulseState, onQuit: @escaping () -> Void) {
        self.model = model
        self.onQuit = onQuit
    }

    var body: some View {
        ZStack(alignment: .top) {
            switch activePage {
            case .main:
                mainContentView
            case .integrations:
                integrationsSettingsView
            case .cursorSettings:
                cursorSettingsView
            case .stateColors:
                colorSettingsView
            }
        }
        .padding(14)
        .frame(width: 360, height: 500, alignment: .top)
        .focusEffectDisabled()
    }

    private var mainContentView: some View {
        VStack(spacing: 0) {
            headerRow
                .padding(.bottom, 8)

            updateBannerView

            controlsSection
                .padding(.bottom, 10)

            Divider()
                .padding(.bottom, 8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    activeSessionsSection
                }
            }

            VStack(spacing: 5) {
                Divider()
                    .padding(.bottom, 4)

                Button {
                    activePage = .integrations
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 18)
                        Text("Agent Integrations")
                            .font(.subheadline)
                        Spacer()
                        let installedCount = model.installers.filter { model.installedFlags[$0.tool] == true }.count
                        Text("\(installedCount) installed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Button {
                    activePage = .cursorSettings
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cursorarrow.and.square.on.square.dashed")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 18)
                        Text("Cursor Companion Settings")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Button {
                    activePage = .stateColors
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 18)
                        Text("State Colors")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.vertical, 4)

                Button(action: onQuit) {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                        Text("Quit CursorPulse")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var updateBannerView: some View {
        switch model.updater.status {
        case .available(let version, _, _):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("Update Available: \(version)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                HStack {
                    Text("A new release of CursorPulse is ready to install.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Update & Restart") {
                        model.updater.installUpdate()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 9)
            .background(Color.green.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 8)

        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Downloading Update...")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 9)
            .background(Color.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 8)

        case .installing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Installing & Relaunching CursorPulse...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 9)
            .background(Color.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 8)

        case .failed(let error):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    model.updater.checkForUpdates(manual: true)
                } label: {
                    Text("Retry")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.bottom, 8)

        case .idle, .checking, .upToDate:
            EmptyView()
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.85), Color.purple.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: Color.blue.opacity(0.3), radius: 3, y: 1)

                Image(systemName: "cursorarrow.rays")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("CursorPulse")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                HStack(spacing: 4) {
                    Text("v\(model.updater.currentVersion)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button {
                        model.updater.checkForUpdates(manual: true)
                    } label: {
                        if model.updater.status == .checking {
                            ProgressView()
                                .controlSize(.mini)
                        } else if case .upToDate = model.updater.status {
                            Text("Up to date")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            Text("Check for updates")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            }

            Spacer(minLength: 8)

            statusBadge
        }
    }

    private var controlsSection: some View {
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

    private var activeSessionsSection: some View {
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

    private var integrationsSettingsView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    activePage = .main
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
                    activePage = .main
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

    private var cursorSettingsView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    activePage = .main
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

                Text("Cursor Companion")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button("Reset") {
                    model.config.resetToDefaults()
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.bottom, 6)

            Text("Customize companion badge size, background & offset:")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live Preview")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.08))
                                .frame(height: 64)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                                )

                            HStack(spacing: 0) {
                                Image(systemName: "cursorarrow")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)

                                ZStack {
                                    Circle()
                                        .stroke(Color.blue.opacity(0.8), lineWidth: 1.5)
                                        .frame(width: model.config.iconSize + 10, height: model.config.iconSize + 10)

                                    Circle()
                                        .fill(model.config.effectiveBackground)
                                        .frame(width: model.config.iconSize + 6, height: model.config.iconSize + 6)
                                        .overlay(
                                            Circle().stroke(model.config.showBorder ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
                                        )

                                    AgentIconView(agent: .antigravity, size: model.config.iconSize)
                                }
                                .offset(x: model.config.offsetX * 0.4, y: -model.config.offsetY * 0.4)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Icon Size")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(Int(model.config.iconSize)) pt")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(model.config.iconSize) },
                                set: { model.config.iconSize = CGFloat($0) }
                            ),
                            in: 10...28,
                            step: 1
                        )
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Background & Glass")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            ColorPicker(
                                "",
                                selection: Binding(
                                    get: { model.config.backgroundColor },
                                    set: { model.config.backgroundColor = $0 }
                                ),
                                supportsOpacity: false
                            )
                            .labelsHidden()
                        }

                        HStack {
                            Text("Opacity")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(model.config.backgroundOpacity <= 0.05 ? "Transparent (0%)" : "\(Int(model.config.backgroundOpacity * 100))%")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: Binding(
                                get: { model.config.backgroundOpacity },
                                set: { model.config.backgroundOpacity = $0 }
                            ),
                            in: 0.0...1.0,
                            step: 0.05
                        )

                        Toggle("Show State Outline Ring", isOn: Binding(
                            get: { model.config.showBorder },
                            set: { model.config.showBorder = $0 }
                        ))
                        .font(.caption)
                        .toggleStyle(.checkbox)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cursor Position Offset")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 4) {
                            presetButton("Bottom-Right", x: 16, y: -16)
                            presetButton("Top-Right", x: 16, y: 16)
                            presetButton("Top-Left", x: -16, y: 16)
                            presetButton("Bottom-Left", x: -16, y: -16)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Horizontal (X)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(model.config.offsetX)) pt")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(model.config.offsetX) },
                                    set: { model.config.offsetX = CGFloat($0) }
                                ),
                                in: -40...50,
                                step: 1
                            )
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Vertical (Y)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(model.config.offsetY)) pt")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(model.config.offsetY) },
                                    set: { model.config.offsetY = CGFloat($0) }
                                ),
                                in: -50...40,
                                step: 1
                            )
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Divider()
                .padding(.vertical, 8)

            HStack(spacing: 8) {
                Button("Reset to Defaults") {
                    model.config.resetToDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)

                Button("Done") {
                    activePage = .main
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func presetButton(_ label: String, x: CGFloat, y: CGFloat) -> some View {
        let isSelected = (model.config.offsetX == x && model.config.offsetY == y)
        return Button(label) {
            model.config.offsetX = x
            model.config.offsetY = y
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .tint(isSelected ? .blue : .primary)
        .frame(maxWidth: .infinity)
    }

    private var colorSettingsView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    activePage = .main
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
                    activePage = .main
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var statusBadge: some View {
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
