import AppKit
import SwiftUI

final class BadgeWindow: NSPanel {
    private static let width: CGFloat = 64
    private static let height: CGFloat = 64

    let scene: BadgeScene

    init(colors: StateColors = StateColors(), config: CursorConfig = CursorConfig()) {
        self.scene = BadgeScene(colors: colors, config: config)
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.cursorWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        hasShadow = false
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        animationBehavior = .none
        contentView = NSHostingView(rootView: BadgeView(scene: scene))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func followCursor() {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        let offsetX = scene.config.offsetX
        let offsetY = scene.config.offsetY
        var origin = CGPoint(
            x: pointer.x + offsetX - Self.width / 2,
            y: pointer.y + offsetY - Self.height / 2
        )
        if let screen {
            let f = screen.frame
            origin.x = min(max(origin.x, f.minX + 2), f.maxX - Self.width - 2)
            origin.y = min(max(origin.y, f.minY + 2), f.maxY - Self.height - 2)
        }
        if frame.origin != origin {
            setFrameOrigin(origin)
        }
    }
}
