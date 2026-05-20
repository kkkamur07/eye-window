import Foundation

/// Nearest-mean gaze classification with temporal mode smoothing (last N frames).
public struct CalibratedGazeClassifier: Sendable {
    public static let predictionWindow = 10

    private var recentPredictions: [DisplayNumber] = []

    public init() {}

    public mutating func reset() {
        recentPredictions = []
    }

    /// Nearest calibrated mean vector (pass smoothed **current** for production-like behavior).
    public static func nearestDisplay(
        feature: GazeFeatureVector,
        layout: DualLayout,
        profile: CalibrationProfile
    ) -> DisplayNumber {
        _ = layout
        return GazeCalibrationRules.mapDisplay(feature: feature, profile: profile)
    }

    /// Classify with mode over the last `predictionWindow` raw predictions.
    public mutating func classify(
        feature: GazeFeatureVector,
        layout: DualLayout,
        profile: CalibrationProfile
    ) -> DisplayNumber? {
        let raw = Self.nearestDisplay(feature: feature, layout: layout, profile: profile)
        recentPredictions.append(raw)
        if recentPredictions.count > Self.predictionWindow {
            recentPredictions.removeFirst(recentPredictions.count - Self.predictionWindow)
        }
        return Self.majorityDisplay(recentPredictions)
    }

    private static func majorityDisplay(_ values: [DisplayNumber]) -> DisplayNumber? {
        guard !values.isEmpty else { return nil }
        var counts: [DisplayNumber: Int] = [:]
        for v in values {
            counts[v, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

/// Legacy yaw thresholds (v1 file); kept for migration helpers only.
public struct CalibrationThresholds: Equatable, Sendable, Codable {
    public var leftThresholdRadians: Double
    public var rightThresholdRadians: Double
    public var d1YawRadians: Double
    public var d2YawRadians: Double

    public init(
        leftThresholdRadians: Double,
        rightThresholdRadians: Double,
        d1YawRadians: Double,
        d2YawRadians: Double
    ) {
        self.leftThresholdRadians = leftThresholdRadians
        self.rightThresholdRadians = rightThresholdRadians
        self.d1YawRadians = d1YawRadians
        self.d2YawRadians = d2YawRadians
    }
}

/// Head-turn mapping using calibrated prototypes (consumed by **GazeStateMachine**).
public enum CalibratedGazeMapper {
    public static func mapDisplay(
        pose: HeadPose,
        layout: DualLayout,
        profile: CalibrationProfile,
        classifier: inout CalibratedGazeClassifier
    ) -> DisplayNumber? {
        _ = classifier
        _ = layout
        return GazeCalibrationRules.mapDisplay(pose: pose, profile: profile)
    }

    /// Menu / debug label from raw pose (no temporal smoothing).
    public static func poseLabel(
        pose: HeadPose,
        profile: CalibrationProfile,
        layout: DualLayout
    ) -> String {
        _ = layout
        let display = GazeCalibrationRules.mapDisplay(pose: pose, profile: profile)
        return display == .one ? "D1" : "D2"
    }
}

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

private struct CalibrationFilePayloadV3: Codable {
    var version: Int = 3
    var display1: GazeFeatureVector
    var display2: GazeFeatureVector
    var mappingRule: String
}

private struct CalibrationFilePayloadV2: Codable {
    var version: Int = 2
    var display1: GazeFeatureVector
    var display2: GazeFeatureVector
}

private struct CalibrationFilePayloadV1: Codable {
    var version: Int = 1
    var leftThresholdRadians: Double
    var rightThresholdRadians: Double
    var d1YawRadians: Double
    var d2YawRadians: Double
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
        if let v3 = try? JSONDecoder().decode(CalibrationFilePayloadV3.self, from: data) {
            return CalibrationProfile(
                display1: v3.display1,
                display2: v3.display2,
                display1Spread: .default,
                display2Spread: .default
            )
        }
        if let v2 = try? JSONDecoder().decode(CalibrationFilePayloadV2.self, from: data) {
            return CalibrationProfile(
                display1: v2.display1,
                display2: v2.display2,
                display1Spread: .default,
                display2Spread: .default
            )
        }
        if let v1 = try? JSONDecoder().decode(CalibrationFilePayloadV1.self, from: data) {
            return migrateV1(v1)
        }
        return nil
    }

    /// Approximate prototypes from legacy yaw-only calibration.
    private static func migrateV1(_ v1: CalibrationFilePayloadV1) -> CalibrationProfile {
        let d1 = GazeFeatureVector.fromGaze(yawRadians: v1.d1YawRadians, pitchRadians: 0)
        let d2 = GazeFeatureVector.fromGaze(yawRadians: v1.d2YawRadians, pitchRadians: 0)
        return CalibrationProfile(display1: d1, display2: d2)
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
