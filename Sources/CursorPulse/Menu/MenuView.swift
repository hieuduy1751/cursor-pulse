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
                IntegrationsPage(model: model, page: $activePage)
            case .cursorSettings:
                CursorCompanionPage(model: model, page: $activePage)
            case .stateColors:
                StateColorsPage(model: model, page: $activePage)
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

            UpdateBannerView(model: model)

            ControlsSection(model: model)
                .padding(.bottom, 10)

            Divider()
                .padding(.bottom, 8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ActiveSessionsSection(model: model)
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

            StatusBadgeView(model: model)
        }
    }
}
