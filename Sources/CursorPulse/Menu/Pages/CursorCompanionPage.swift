import SwiftUI
import CursorPulseCore

struct CursorCompanionPage: View {
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
                    page = .main
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
}
