import Foundation

private struct CalibrationFilePayloadV5: Codable {
    var version: Int = 5
    var display1: GazeFeatureVector
    var display2: GazeFeatureVector
    var display1Spread: GazeFeatureSpread
    var display2Spread: GazeFeatureSpread
    var tuning: CalibrationTuning
}

private struct CalibrationFilePayloadV4: Codable {
    var version: Int = 4
    var display1: GazeFeatureVector
    var display2: GazeFeatureVector
    var display1Spread: GazeFeatureSpread
    var display2Spread: GazeFeatureSpread
}

/// Persists calibration prototypes to Application Support JSON.
public final class CalibrationStore: @unchecked Sendable {
    public static let shared = CalibrationStore()

    private static let fileName = "calibration.json"
    private static let appSupportSubpath = "Eye Window"

    private let fileURL: URL
    private let lock = NSLock()
    private var cached: CalibrationProfile?

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.fileURL = base
                .appendingPathComponent(Self.appSupportSubpath, isDirectory: true)
                .appendingPathComponent(Self.fileName)
        }
        cached = Self.loadFromDisk(url: self.fileURL)
    }

    public var isCalibrated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cached != nil
    }

    public var profile: CalibrationProfile? {
        lock.lock()
        defer { lock.unlock() }
        return cached
    }

    public func load() -> CalibrationProfile? {
        lock.lock()
        defer { lock.unlock() }
        if cached == nil {
            cached = Self.loadFromDisk(url: fileURL)
        }
        return cached
    }

    @discardableResult
    public func save(_ profile: CalibrationProfile) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        cached = profile
        return Self.writeToDisk(profile, url: fileURL)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        cached = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func loadFromDisk(url: URL) -> CalibrationProfile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let v5 = try? JSONDecoder().decode(CalibrationFilePayloadV5.self, from: data) {
            return CalibrationProfile(
                display1: v5.display1,
                display2: v5.display2,
                display1Spread: v5.display1Spread,
                display2Spread: v5.display2Spread,
                tuning: v5.tuning
            )
        }
        if let v4 = try? JSONDecoder().decode(CalibrationFilePayloadV4.self, from: data) {
            return CalibrationProfile(
                display1: v4.display1,
                display2: v4.display2,
                display1Spread: v4.display1Spread,
                display2Spread: v4.display2Spread
            )
        }
        return nil
    }

    private static func writeToDisk(_ profile: CalibrationProfile, url: URL) -> Bool {
        let payload = CalibrationFilePayloadV5(
            display1: profile.display1,
            display2: profile.display2,
            display1Spread: profile.display1Spread,
            display2Spread: profile.display2Spread,
            tuning: profile.tuning
        )
        let dir = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(payload)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
