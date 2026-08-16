import Foundation
import ServiceManagement
import SwiftUI

@Observable
public final class LaunchAtLoginManager {
    public static let shared = LaunchAtLoginManager()

    public var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            } else {
                return UserDefaults.standard.bool(forKey: "cursorpulse_launch_at_login")
            }
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        if SMAppService.mainApp.status != .enabled {
                            try SMAppService.mainApp.register()
                        }
                    } else {
                        if SMAppService.mainApp.status == .enabled {
                            try SMAppService.mainApp.unregister()
                        }
                    }
                    UserDefaults.standard.set(newValue, forKey: "cursorpulse_launch_at_login")
                } catch {
                    print("Launch at login error: \(error)")
                }
            } else {
                UserDefaults.standard.set(newValue, forKey: "cursorpulse_launch_at_login")
            }
        }
    }

    public init() {}
}
