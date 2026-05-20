import Foundation

/// Why an implicit label was not written to the training dataset.
public enum ImplicitGazeRejectReason: String, Sendable, Codable {
    case debounced
    case insufficientFrames
    case staleWindow
    case unstableGaze
    case invalidFeature
    case outOfRangeAngles
    case nearDuplicate
}

/// Snapshot of gaze frames paired with a mouse click or focus change.
public struct GazeWindowSnapshot: Equatable, Sendable {
    public var features: [GazeFeatureVector]
    public var frameCount: Int
    /// Seconds between label time and newest frame in the window.
    public var newestAge: TimeInterval
    /// Seconds between label time and oldest frame in the window.
    public var oldestAge: TimeInterval
    public var spread: GazeFeatureSpread
    public var mean: GazeFeatureVector

    public init(
        features: [GazeFeatureVector],
        newestAge: TimeInterval,
        oldestAge: TimeInterval
    ) {
        self.features = features
        frameCount = features.count
        self.newestAge = newestAge
        self.oldestAge = oldestAge
        spread = GazeFeatureSpread.fromSamples(features)
        mean = GazeFeatureVector.mean(features)
    }
}

/// Quality gates so implicit rows are usable for offline classifier training.
public enum ImplicitGazeSampleFilter {
    public static let minIntervalBetweenSamples: TimeInterval = 0.35
    public static let minWindowFrames: Int = 4
    public static let maxNewestFrameAge: TimeInterval = 0.45
    public static let maxWindowSpread: Double = 0.10
    public static let maxYawSpread: Double = 0.07
    public static let minUnitVectorLength: Double = 0.85
    public static let maxUnitVectorLength: Double = 1.15
    public static let maxAbsYawRadians: Double = 1.35
    public static let maxAbsPitchRadians: Double = 1.0
    public static let nearDuplicateDistanceSquared: Double = 0.0025

    public static func evaluate(
        window: GazeWindowSnapshot,
        display: DisplayNumber,
        lastSaved: ImplicitGazeSample?
    ) -> ImplicitGazeRejectReason? {
        if window.frameCount < minWindowFrames {
            return .insufficientFrames
        }
        if window.newestAge > maxNewestFrameAge {
            return .staleWindow
        }
        if window.spread.maxComponent > maxWindowSpread || window.spread.yawRadians > maxYawSpread {
            return .unstableGaze
        }
        if let reason = invalidFeatureReason(window.mean) {
            return reason
        }
        if let lastSaved, isNearDuplicate(window.mean, display: display, last: lastSaved) {
            return .nearDuplicate
        }
        return nil
    }

    private static func invalidFeatureReason(_ feature: GazeFeatureVector) -> ImplicitGazeRejectReason? {
        let len = feature.unitLength
        if len < minUnitVectorLength || len > maxUnitVectorLength {
            return .invalidFeature
        }
        if abs(feature.yawRadians) < 1e-6 && abs(feature.pitchRadians) < 1e-6 {
            return .invalidFeature
        }
        if abs(feature.yawRadians) > maxAbsYawRadians || abs(feature.pitchRadians) > maxAbsPitchRadians {
            return .outOfRangeAngles
        }
        return nil
    }

    private static func isNearDuplicate(
        _ feature: GazeFeatureVector,
        display: DisplayNumber,
        last: ImplicitGazeSample
    ) -> Bool {
        guard last.display == display else { return false }
        return feature.distanceSquared(to: last.feature) < nearDuplicateDistanceSquared
    }
}

extension GazeFeatureVector {
    /// Length of the unit gaze direction `(gx, gy, gz)`.
    public var unitLength: Double {
        sqrt(gx * gx + gy * gy + gz * gz)
    }
}
