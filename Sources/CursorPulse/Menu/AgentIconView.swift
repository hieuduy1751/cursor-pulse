import SwiftUI
import AppKit
import CursorPulseCore

public struct AgentIconView: View {
    public let agent: AgentTool
    public var size: CGFloat = 16
    public var tint: Color? = nil

    public init(agent: AgentTool, size: CGFloat = 16, tint: Color? = nil) {
        self.agent = agent
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        if let img = Self.iconImage(for: agent) {
            Image(nsImage: img)
                .renderingMode(agent == .claude ? .original : .template)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .foregroundColor(iconColor)
                .frame(width: size, height: size)
        } else {
            fallbackView
        }
    }

    private var iconColor: Color {
        if let tint = tint { return tint }
        switch agent {
        case .antigravity: return .white
        case .codex: return .white
        case .claude: return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .cursor: return .white
        case .opencode: return .white
        case .pi, .omp: return .white
        case .debug: return Color(red: 0.95, green: 0.40, blue: 0.35)
        case .custom: return .white
        }
    }

    @ViewBuilder
    private var fallbackView: some View {
        Image(systemName: agent.systemImage)
            .font(.system(size: size * 0.75, weight: .semibold))
            .foregroundColor(iconColor)
            .frame(width: size, height: size)
    }

    private static var iconCache: [AgentTool: NSImage] = [:]

    private static func iconImage(for agent: AgentTool) -> NSImage? {
        if let cached = iconCache[agent] {
            return cached
        }

        let name: String
        switch agent {
        case .antigravity: name = "antigravity"
        case .codex: name = "codex"
        case .claude: name = "claude"
        case .cursor: name = "cursor"
        case .opencode: name = "opencode"
        case .pi: name = "pi"
        case .omp: name = "omp"
        case .debug, .custom: name = "antigravity"
        }

        var candidateURLs: [URL] = []
        if let bundleURL = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "icons") {
            candidateURLs.append(bundleURL)
        }
        if let moduleURL = Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: "icons") {
            candidateURLs.append(moduleURL)
        }
        if let resURL = Bundle.main.resourceURL?.appendingPathComponent("icons/\(name).svg") {
            candidateURLs.append(resURL)
        }
        candidateURLs.append(URL(fileURLWithPath: "Sources/CursorPulse/Resources/icons/\(name).svg"))

        for url in candidateURLs {
            if let img = NSImage(contentsOf: url) {
                img.size = NSSize(width: 128, height: 128)
                if agent != .claude {
                    img.isTemplate = true
                }
                iconCache[agent] = img
                return img
            }
        }
        return nil
    }
}
