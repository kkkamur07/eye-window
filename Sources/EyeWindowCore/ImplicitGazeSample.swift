import CoreGraphics
import Foundation

/// How a display label was inferred for an implicit training row.
public enum ImplicitLabelSource: String, Codable, Sendable {
    case mouseClick
    case appFocus
}

/// One labeled gaze feature row for offline classifier training.
public struct ImplicitGazeSample: Equatable, Sendable, Codable {
    public var timestamp: TimeInterval
    public var display: DisplayNumber
    public var gx: Double
    public var gy: Double
    public var gz: Double
    public var yawRadians: Double
    public var pitchRadians: Double
    public var source: ImplicitLabelSource
    public var mouseX: Double?
    public var mouseY: Double?

    public init(
        timestamp: TimeInterval,
        display: DisplayNumber,
        feature: GazeFeatureVector,
        source: ImplicitLabelSource,
        mousePoint: CGPoint? = nil
    ) {
        self.timestamp = timestamp
        self.display = display
        gx = feature.gx
        gy = feature.gy
        gz = feature.gz
        yawRadians = feature.yawRadians
        pitchRadians = feature.pitchRadians
        self.source = source
        if let mousePoint {
            mouseX = Double(mousePoint.x)
            mouseY = Double(mousePoint.y)
        } else {
            mouseX = nil
            mouseY = nil
        }
    }

    public var feature: GazeFeatureVector {
        GazeFeatureVector(
            gx: gx,
            gy: gy,
            gz: gz,
            yawRadians: yawRadians,
            pitchRadians: pitchRadians
        )
    }
}
