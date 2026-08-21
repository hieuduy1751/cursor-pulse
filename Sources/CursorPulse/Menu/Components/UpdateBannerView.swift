import SwiftUI
import CursorPulseCore

struct UpdateBannerView: View {
    let model: CursorPulseState

    var body: some View {
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
}
