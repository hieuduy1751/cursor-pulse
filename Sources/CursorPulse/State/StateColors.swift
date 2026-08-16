import AppKit
import CursorPulseCore
import SwiftUI

@Observable
public final class StateColors {
    public var colors: [UniversalAgentState: Color] = [:]

    public init() {
        load()
    }

    public func color(for state: UniversalAgentState) -> Color {
        return colors[state] ?? Self.defaultColor(for: state)
    }

    public func setColor(_ color: Color, for state: UniversalAgentState) {
        colors[state] = color
        save()
    }

    public func resetToDefaults() {
        var map: [UniversalAgentState: Color] = [:]
        for state in UniversalAgentState.allCases {
            map[state] = Self.defaultColor(for: state)
        }
        self.colors = map
        save()
    }

    public static func defaultColor(for state: UniversalAgentState) -> Color {
        switch state {
        case .inactive: return Color(white: 0.85)
        case .queued: return Color(red: 0.72, green: 0.35, blue: 0.95)
        case .working: return Color(red: 0.25, green: 0.55, blue: 1.0)
        case .needsInput: return Color(red: 1.0, green: 0.55, blue: 0.0)
        case .needsApproval: return Color(red: 1.0, green: 0.82, blue: 0.0)
        case .ready: return Color(red: 0.25, green: 0.82, blue: 0.4)
        case .error: return Color(red: 0.95, green: 0.25, blue: 0.2)
        case .stopped: return Color(red: 0.4, green: 0.4, blue: 0.45)
        }
    }

    private func save() {
        var dict: [String: [Double]] = [:]
        for (state, color) in colors {
            let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
            dict[state.rawValue] = [
                Double(nsColor.redComponent),
                Double(nsColor.greenComponent),
                Double(nsColor.blueComponent),
                Double(nsColor.alphaComponent)
            ]
        }
        UserDefaults.standard.set(dict, forKey: "cursorpulse_state_colors")
    }

    private func load() {
        var result: [UniversalAgentState: Color] = [:]
        for state in UniversalAgentState.allCases {
            result[state] = Self.defaultColor(for: state)
        }
        if let dict = UserDefaults.standard.dictionary(forKey: "cursorpulse_state_colors") as? [String: [Double]] {
            for (key, values) in dict where values.count >= 3 {
                if let state = UniversalAgentState(rawValue: key) {
                    let r = values[0]
                    let g = values[1]
                    let b = values[2]
                    let a = values.count >= 4 ? values[3] : 1.0
                    result[state] = Color(red: r, green: g, blue: b, opacity: a)
                }
            }
        }
        self.colors = result
    }
}
