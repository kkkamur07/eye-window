import Foundation

/// Gaze + head pose feature vector for calibration and runtime nearest-prototype classification.
/// `gx`/`gy`/`gz` are a unit gaze direction from model **yaw** and **pitch** (radians).
public struct GazeFeatureVector: Equatable, Sendable, Codable {
    public var gx: Double
    public var gy: Double
    public var gz: Double
    public var yawRadians: Double
    public var pitchRadians: Double

    public init(
        gx: Double,
        gy: Double,
        gz: Double,
        yawRadians: Double,
        pitchRadians: Double
    ) {
        self.gx = gx
        self.gy = gy
        self.gz = gz
        self.yawRadians = yawRadians
        self.pitchRadians = pitchRadians
    }

    /// Build from Core ML gaze angles (use **gaze yaw**, not Vision head yaw).
    public static func fromGaze(yawRadians: Double, pitchRadians: Double) -> GazeFeatureVector {
        let cp = cos(pitchRadians)
        let sp = sin(pitchRadians)
        let sy = sin(yawRadians)
        let cy = cos(yawRadians)
        return GazeFeatureVector(
            gx: cp * sy,
            gy: sp,
            gz: cp * cy,
            yawRadians: yawRadians,
            pitchRadians: pitchRadians
        )
    }

    public static func fromPose(_ pose: HeadPose) -> GazeFeatureVector {
        fromGaze(yawRadians: pose.yawRadians, pitchRadians: pose.pitchRadians)
    }

    /// Mean of sample vectors (per component).
    public static func mean(_ samples: [GazeFeatureVector]) -> GazeFeatureVector {
        guard !samples.isEmpty else {
            return GazeFeatureVector(gx: 0, gy: 0, gz: 0, yawRadians: 0, pitchRadians: 0)
        }
        var sx = 0.0, sy = 0.0, sz = 0.0, yaw = 0.0, pitch = 0.0
        for s in samples {
            sx += s.gx
            sy += s.gy
            sz += s.gz
            yaw += s.yawRadians
            pitch += s.pitchRadians
        }
        let n = Double(samples.count)
        return GazeFeatureVector(
            gx: sx / n,
            gy: sy / n,
            gz: sz / n,
            yawRadians: yaw / n,
            pitchRadians: pitch / n
        )
    }

    /// Squared Euclidean distance in `[gx, gy, gz, yaw, pitch]` space.
    public func distanceSquared(to other: GazeFeatureVector) -> Double {
        let dgx = gx - other.gx
        let dgy = gy - other.gy
        let dgz = gz - other.gz
        let dyaw = yawRadians - other.yawRadians
        let dpitch = pitchRadians - other.pitchRadians
        return dgx * dgx + dgy * dgy + dgz * dgz + dyaw * dyaw + dpitch * dpitch
    }

    /// Mahalanobis squared distance using per-dimension std from calibration spread.
    public func mahalanobisSquared(to prototype: GazeFeatureVector, spread: GazeFeatureSpread) -> Double {
        func term(_ a: Double, _ b: Double, _ sigma: Double) -> Double {
            let d = a - b
            let s = max(sigma, GazeFeatureSpread.minStd)
            return (d / s) * (d / s)
        }
        return term(gx, prototype.gx, spread.gx)
            + term(gy, prototype.gy, spread.gy)
            + term(gz, prototype.gz, spread.gz)
            + term(yawRadians, prototype.yawRadians, spread.yawRadians)
            + term(pitchRadians, prototype.pitchRadians, spread.pitchRadians)
    }
}

/// Per-dimension standard deviation of gaze features during a calibration step.
public struct GazeFeatureSpread: Equatable, Sendable, Codable {
    public var gx: Double
    public var gy: Double
    public var gz: Double
    public var yawRadians: Double
    public var pitchRadians: Double

    /// Floor when spread is computed from very few or identical samples.
    public static let minStd: Double = 0.02

    public init(
        gx: Double,
        gy: Double,
        gz: Double,
        yawRadians: Double,
        pitchRadians: Double
    ) {
        self.gx = gx
        self.gy = gy
        self.gz = gz
        self.yawRadians = yawRadians
        self.pitchRadians = pitchRadians
    }

    /// Reasonable default when loading legacy calibrations without spread data.
    public static let `default` = GazeFeatureSpread(
        gx: 0.04,
        gy: 0.04,
        gz: 0.04,
        yawRadians: 0.03,
        pitchRadians: 0.03
    )

    /// Population std per component over calibration samples.
    public static func fromSamples(_ samples: [GazeFeatureVector]) -> GazeFeatureSpread {
        guard samples.count > 1 else { return .default }
        func std(_ values: [Double]) -> Double {
            let mean = values.reduce(0, +) / Double(values.count)
            let varSum = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
            return max(sqrt(varSum / Double(values.count)), minStd)
        }
        return GazeFeatureSpread(
            gx: std(samples.map(\.gx)),
            gy: std(samples.map(\.gy)),
            gz: std(samples.map(\.gz)),
            yawRadians: std(samples.map(\.yawRadians)),
            pitchRadians: std(samples.map(\.pitchRadians))
        )
    }

    /// Pooled spread for comparing two prototypes (geometric mean per axis).
    public static func pooled(_ a: GazeFeatureSpread, _ b: GazeFeatureSpread) -> GazeFeatureSpread {
        func pool(_ x: Double, _ y: Double) -> Double {
            max(sqrt(x * y), minStd)
        }
        return GazeFeatureSpread(
            gx: pool(a.gx, b.gx),
            gy: pool(a.gy, b.gy),
            gz: pool(a.gz, b.gz),
            yawRadians: pool(a.yawRadians, b.yawRadians),
            pitchRadians: pool(a.pitchRadians, b.pitchRadians)
        )
    }

    /// Max component std — useful for calibration quality feedback.
    public var maxComponent: Double {
        max(gx, gy, gz, yawRadians, pitchRadians)
    }
}

/// Per-display prototype vectors from calibration (dual-display MVP: D1 + D2).
public struct CalibrationProfile: Equatable, Sendable, Codable {
    public var display1: GazeFeatureVector
    public var display2: GazeFeatureVector
    public var display1Spread: GazeFeatureSpread
    public var display2Spread: GazeFeatureSpread
    public var tuning: CalibrationTuning

    public init(
        display1: GazeFeatureVector,
        display2: GazeFeatureVector,
        display1Spread: GazeFeatureSpread = .default,
        display2Spread: GazeFeatureSpread = .default,
        tuning: CalibrationTuning? = nil
    ) {
        self.display1 = display1
        self.display2 = display2
        self.display1Spread = display1Spread
        self.display2Spread = display2Spread
        self.tuning = tuning ?? CalibrationTuning.derive(
            display1: display1,
            display2: display2,
            display1Spread: display1Spread,
            display2Spread: display2Spread
        )
    }

    public static func derive(
        display1Samples: [GazeFeatureVector],
        display2Samples: [GazeFeatureVector],
        refine: Bool = true
    ) -> CalibrationProfile {
        let (r1, r2) = refine
            ? CalibrationQuality.refineSamples(display1: display1Samples, display2: display2Samples)
            : (display1Samples, display2Samples)
        let d1 = GazeFeatureVector.mean(r1)
        let d2 = GazeFeatureVector.mean(r2)
        let s1 = GazeFeatureSpread.fromSamples(r1)
        let s2 = GazeFeatureSpread.fromSamples(r2)
        return CalibrationProfile(
            display1: d1,
            display2: d2,
            display1Spread: s1,
            display2Spread: s2,
            tuning: CalibrationTuning.derive(
                display1: d1,
                display2: d2,
                display1Spread: s1,
                display2Spread: s2
            )
        )
    }

    /// Nearest mean prototype to `feature` (call with smoothed current vector at runtime).
    public func nearestDisplay(
        current feature: GazeFeatureVector,
        lockedDisplay: DisplayNumber? = nil
    ) -> DisplayNumber {
        GazeCalibrationRules.mapDisplay(
            feature: feature,
            profile: self,
            lockedDisplay: lockedDisplay,
            switchAdvantageRatio: tuning.switchAdvantageRatio
        )
    }

    /// Refined samples used for prototypes + replay scoring.
    public static func refinedCalibrationSamples(
        display1: [GazeFeatureVector],
        display2: [GazeFeatureVector]
    ) -> (display1: [GazeFeatureVector], display2: [GazeFeatureVector]) {
        let (r1, r2) = CalibrationQuality.refineSamples(display1: display1, display2: display2)
        return (r1, r2)
    }

    public func mappedDisplay(feature: GazeFeatureVector) -> DisplayNumber {
        GazeCalibrationRules.mapDisplay(
            feature: feature,
            profile: self,
            switchAdvantageRatio: tuning.switchAdvantageRatio
        )
    }
}
