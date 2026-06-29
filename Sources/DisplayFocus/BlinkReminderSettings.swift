import DisplayFocusCore
import Foundation

enum BlinkBreakIntervalPreset: CaseIterable, Identifiable {
    case production
    case fiveMinutes
    case twoMinutes
    case thirtySeconds

    var id: TimeInterval { breakInterval }

    var breakInterval: TimeInterval {
        switch self {
        case .production: return ActiveUsageConfiguration.default.breakInterval
        case .fiveMinutes: return 5 * 60
        case .twoMinutes: return 2 * 60
        case .thirtySeconds: return 30
        }
    }

    var menuLabel: String {
        switch self {
        case .production: return "60 minutes (default)"
        case .fiveMinutes: return "5 minutes"
        case .twoMinutes: return "2 minutes"
        case .thirtySeconds: return "30 seconds (test)"
        }
    }
}

enum BlinkReminderSettings {
    private static let breakIntervalKey = "blinkBreakIntervalSeconds"
    private static let trackingModeKey = "blinkTrackingMode"

    static func loadBreakInterval() -> TimeInterval {
        let stored = UserDefaults.standard.double(forKey: breakIntervalKey)
        if stored > 0 {
            return stored
        }
        return ActiveUsageConfiguration.default.breakInterval
    }

    static func saveBreakInterval(_ interval: TimeInterval) {
        UserDefaults.standard.set(interval, forKey: breakIntervalKey)
    }

    static func preset(for interval: TimeInterval) -> BlinkBreakIntervalPreset? {
        BlinkBreakIntervalPreset.allCases.first { $0.breakInterval == interval }
    }

    static func intervalLabel(_ interval: TimeInterval) -> String {
        preset(for: interval)?.menuLabel ?? "\(Int(interval))s"
    }

    static func loadTrackingMode() -> BlinkTrackingMode {
        guard let raw = UserDefaults.standard.string(forKey: trackingModeKey),
              let mode = BlinkTrackingMode(rawValue: raw)
        else {
            return .clock
        }
        return mode
    }

    static func saveTrackingMode(_ mode: BlinkTrackingMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: trackingModeKey)
    }

    static func nextBreakInterval(after current: TimeInterval) -> TimeInterval {
        let presets = BlinkBreakIntervalPreset.allCases.map(\.breakInterval)
        guard let index = presets.firstIndex(of: current) else {
            return ActiveUsageConfiguration.default.breakInterval
        }
        return presets[(index + 1) % presets.count]
    }
}
