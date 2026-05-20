import Foundation
import ServiceManagement

enum LaunchAtLogin {
    private static let key = "launchAtLogin"

    /// Default on so the app runs after you sign in (toggle in menu).
    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: key) == nil { return true }
            return UserDefaults.standard.bool(forKey: key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            apply(newValue)
        }
    }

    static func applyOnLaunch() {
        if isEnabled { apply(true) }
    }

    private static func apply(_ enabled: Bool) {
        let service = SMAppService.mainApp
        if enabled {
            try? service.register()
        } else {
            try? service.unregister()
        }
    }
}
