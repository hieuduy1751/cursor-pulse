import AppKit
import CursorPulseCore
import SwiftUI

@Observable
public final class CursorConfig {
    public var iconSize: CGFloat = 16.0 {
        didSet { save() }
    }
    public var offsetX: CGFloat = 16.0 {
        didSet { save() }
    }
    public var offsetY: CGFloat = -16.0 {
        didSet { save() }
    }
    public var backgroundColor: Color = .black {
        didSet { save() }
    }
    public var backgroundOpacity: Double = 0.85 {
        didSet { save() }
    }
    public var showBorder: Bool = true {
        didSet { save() }
    }

    public init() {
        load()
    }

    public var effectiveBackground: Color {
        backgroundColor.opacity(backgroundOpacity)
    }

    public func resetToDefaults() {
        iconSize = 16.0
        offsetX = 16.0
        offsetY = -16.0
        backgroundColor = .black
        backgroundOpacity = 0.85
        showBorder = true
        save()
    }

    private func save() {
        UserDefaults.standard.set(Double(iconSize), forKey: "cursorpulse_icon_size")
        UserDefaults.standard.set(Double(offsetX), forKey: "cursorpulse_offset_x")
        UserDefaults.standard.set(Double(offsetY), forKey: "cursorpulse_offset_y")
        UserDefaults.standard.set(backgroundOpacity, forKey: "cursorpulse_bg_opacity")
        UserDefaults.standard.set(showBorder, forKey: "cursorpulse_show_border")

        let nsColor = NSColor(backgroundColor).usingColorSpace(.sRGB) ?? NSColor(backgroundColor)
        let colorValues: [Double] = [
            Double(nsColor.redComponent),
            Double(nsColor.greenComponent),
            Double(nsColor.blueComponent)
        ]
        UserDefaults.standard.set(colorValues, forKey: "cursorpulse_bg_color")
    }

    private func load() {
        if let s = UserDefaults.standard.object(forKey: "cursorpulse_icon_size") as? Double {
            iconSize = CGFloat(s)
        }
        if let x = UserDefaults.standard.object(forKey: "cursorpulse_offset_x") as? Double {
            offsetX = CGFloat(x)
        }
        if let y = UserDefaults.standard.object(forKey: "cursorpulse_offset_y") as? Double {
            offsetY = CGFloat(y)
        }
        if let op = UserDefaults.standard.object(forKey: "cursorpulse_bg_opacity") as? Double {
            backgroundOpacity = op
        }
        if let border = UserDefaults.standard.object(forKey: "cursorpulse_show_border") as? Bool {
            showBorder = border
        }
        if let colorValues = UserDefaults.standard.array(forKey: "cursorpulse_bg_color") as? [Double], colorValues.count >= 3 {
            backgroundColor = Color(red: colorValues[0], green: colorValues[1], blue: colorValues[2])
        }
    }
}
