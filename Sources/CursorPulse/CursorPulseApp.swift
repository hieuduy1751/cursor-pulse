import SwiftUI
import CursorPulseCore

@main
enum CursorPulseMain {
    private static var appDelegate: AppDelegate?

    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if let mode = args.first, ["--install", "--uninstall", "--status"].contains(mode) {
            runCLI(mode: mode, toolName: args.dropFirst().first)
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        self.appDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private static func runCLI(mode: String, toolName: String?) {
        let installers: [any ToolInstaller] = [
            CodexInstaller(),
            ClaudeInstaller(),
            CursorInstaller(),
            AntigravityInstaller(),
            OpencodeInstaller()
        ]
        guard let toolName else {
            for installer in installers {
                print("\(installer.tool): \(installer.isInstalled ? "installed" : "not installed")")
            }
            return
        }
        guard let installer = installers.first(where: { $0.tool == toolName }) else {
            FileHandle.standardError.write("unknown tool: \(toolName)\n".data(using: .utf8)!)
            exit(2)
        }
        switch mode {
        case "--install":
            installer.install()
            print("\(installer.displayName): installed"
                + (installer.postInstallNote.map { " — \($0)" } ?? ""))
        case "--uninstall":
            installer.uninstall()
            print("\(installer.displayName): uninstalled")
        default:
            print("\(installer.tool): \(installer.isInstalled ? "installed" : "not installed")")
        }
    }
}

final class AutoSizingHostingController<Content: View>: NSHostingController<Content> {
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = CursorPulseState()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        model.start()
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "CursorPulse")
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
            button.action = #selector(statusItemClicked(_:))
        }
        self.statusItem = item

        let controller = AutoSizingHostingController(
            rootView: MenuView(model: model) {
                NSApplication.shared.terminate(nil)
            }
        )
        let fixedSize = NSSize(width: 360, height: 500)
        controller.preferredContentSize = fixedSize

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = fixedSize
        popover.contentViewController = controller
        self.popover = popover
    }

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover = popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.contentSize = NSSize(width: 360, height: 500)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
