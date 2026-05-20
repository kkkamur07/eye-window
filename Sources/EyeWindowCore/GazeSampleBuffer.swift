import Foundation

/// Timestamped gaze frame for pairing with mouse/focus labels.
public struct TimestampedGazeFeature: Equatable, Sendable {
    public var timestamp: TimeInterval
    public var feature: GazeFeatureVector

    public init(timestamp: TimeInterval, feature: GazeFeatureVector) {
        self.timestamp = timestamp
        self.feature = feature
    }
}

/// Thread-safe ring buffer of recent gaze features (fed from `GazeEngine` stream).
public final class GazeSampleBuffer: @unchecked Sendable {
    public static let defaultCapacity = 120
    public static let defaultMaxLabelAge: TimeInterval = 1.0
    public static let defaultMinFrames = 3

    private let lock = NSLock()
    private var samples: [TimestampedGazeFeature] = []
    private let capacity: Int

    public init(capacity: Int = defaultCapacity) {
        self.capacity = max(10, capacity)
    }

    public func reset() {
        lock.lock()
        samples = []
        lock.unlock()
    }

    public func append(_ feature: GazeFeatureVector, at timestamp: TimeInterval) {
        lock.lock()
        samples.append(TimestampedGazeFeature(timestamp: timestamp, feature: feature))
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
        lock.unlock()
    }

    /// Mean feature over frames in `(labelTime - maxAge, labelTime]`.
    public func representativeFeature(
        at labelTime: TimeInterval,
        maxAge: TimeInterval = defaultMaxLabelAge,
        minFrames: Int = defaultMinFrames
    ) -> GazeFeatureVector? {
        lock.lock()
        let window = samples.filter { $0.timestamp <= labelTime && labelTime - $0.timestamp <= maxAge }
        lock.unlock()
        guard window.count >= minFrames else { return nil }
        return GazeFeatureVector.mean(window.map(\.feature))
    }

    public var frameCount: Int {
        lock.lock()
        let n = samples.count
        lock.unlock()
        return n
    }
}
