import Foundation

/// Rolling mean of gaze feature vectors — the runtime **current** estimate before nearest-mean mapping.
///
/// Each frame appends a raw `[gx, gy, gz, yaw, pitch]` vector; `push` returns the mean of the last
/// `windowSize` frames (same rule used for calibration replay scoring).
public struct GazeVectorSmoother: Sendable {
    /// ~0.8 s of gaze history at 10 FPS (was 10 frames @ 5 FPS ≈ 2 s).
    public static let windowSize = 8

    private var buffer: [GazeFeatureVector] = []

    public init() {}

    public mutating func reset() {
        buffer = []
    }

    /// Append one raw frame; returns the smoothed **current** vector (mean over last `windowSize`).
    public mutating func push(_ feature: GazeFeatureVector) -> GazeFeatureVector {
        buffer.append(feature)
        if buffer.count > Self.windowSize {
            buffer.removeFirst(buffer.count - Self.windowSize)
        }
        return GazeFeatureVector.mean(buffer)
    }

    public var count: Int { buffer.count }

    /// Mean of buffered frames without appending (nil when empty).
    public var current: GazeFeatureVector? {
        guard !buffer.isEmpty else { return nil }
        return GazeFeatureVector.mean(buffer)
    }
}
