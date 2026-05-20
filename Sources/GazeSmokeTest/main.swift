import AVFoundation
import CoreML
import EyeWindowCore
import Foundation

enum GazeSmokeTest {
    static func main() {
        if CommandLine.arguments.contains("--calibrate") {
            InteractiveCalibrate.run()
            return
        }

        var failed = false
        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            if ok {
                print("  OK  \(name)")
            } else {
                print("  FAIL \(name) \(detail)")
                failed = true
            }
        }

        print("=== Gaze pipeline smoke (Swift) ===\n")

        print("1) Decode formula (peak logits)")
        for (bin, expectedDeg) in [(0, -180.0), (45, 0.0), (67, 88.0), (22, -92.0)] {
            let logits = GazePipelineSmoke.peakLogits(bin: bin)
            let rad = GazeInference.decodeAngleRadians(logits: logits)
            let deg = rad * 180 / Double.pi
            check("bin \(bin) → \(expectedDeg)°", abs(deg - expectedDeg) < 0.5, "got \(deg)°")
        }

        print("\n2) Gaze vector from yaw/pitch")
        let forward = GazePipelineSmoke.gazeDirection(yawRadians: 0, pitchRadians: 0)
        check(
            "forward (0,0) → gz≈1",
            abs(forward.gx) < 1e-6 && abs(forward.gy) < 1e-6 && abs(forward.gz - 1) < 1e-6,
            "(\(forward.gx),\(forward.gy),\(forward.gz))"
        )
        let left = GazePipelineSmoke.gazeDirection(yawRadians: -.pi / 2, pitchRadians: 0)
        let leftLen = GazePipelineSmoke.vectorLength(gx: left.gx, gy: left.gy, gz: left.gz)
        check("unit length", abs(leftLen - 1) < 1e-6, "len=\(leftLen)")
        let v = GazeFeatureVector.fromGaze(yawRadians: 0.3, pitchRadians: -0.1)
        let reconstructed = GazePipelineSmoke.gazeDirection(yawRadians: v.yawRadians, pitchRadians: v.pitchRadians)
        check(
            "vector matches stored yaw/pitch",
            abs(v.gx - reconstructed.gx) < 1e-9 && abs(v.gy - reconstructed.gy) < 1e-9,
            ""
        )

        print("\n3) Core ML model load + uniform-gray inference")
        do {
            let model = try GazeModelLoader.loadModel()
            let sample = try GazePipelineSmoke.runUniformGrayInference(model: model)
            let dir = GazePipelineSmoke.gazeDirection(
                yawRadians: sample.yawRadians,
                pitchRadians: sample.pitchRadians
            )
            let yawDeg = sample.yawRadians * 180 / Double.pi
            let pitchDeg = sample.pitchRadians * 180 / Double.pi
            print("    yaw   = \(String(format: "%.4f", sample.yawRadians)) rad (\(String(format: "%.2f", yawDeg))°)")
            print("    pitch = \(String(format: "%.4f", sample.pitchRadians)) rad (\(String(format: "%.2f", pitchDeg))°)")
            print("    gx=\(String(format: "%.4f", dir.gx)) gy=\(String(format: "%.4f", dir.gy)) gz=\(String(format: "%.4f", dir.gz))")
            print("    onDisplayAttention=\(sample.onDisplayAttention)")
            check("finite yaw/pitch", sample.yawRadians.isFinite && sample.pitchRadians.isFinite, "")
            check(
                "vector unit length",
                abs(GazePipelineSmoke.vectorLength(gx: dir.gx, gy: dir.gy, gz: dir.gz) - 1) < 1e-4,
                ""
            )
        } catch {
            check("Core ML inference", false, "\(error)")
        }

        if CommandLine.arguments.contains("--live") {
            print("\n4) Live webcam (~5 s, face required)")
            runLiveSmoke(check: check)
        } else {
            print("\n4) Live webcam skipped (pass --live or --calibrate)")
        }

        print("\nInteractive calibration: swift run GazeSmokeTest -- --calibrate [--save]")

        print("\n=== \(failed ? "FAILED" : "PASS") ===")
        if !failed {
            print("Compare section 3 numbers with: python3 scripts/smoke_gaze_pipeline.py")
        }
        exit(failed ? 1 : 0)
    }

    static func runLiveSmoke(check: @escaping (String, Bool, String) -> Void) {
        let sem = DispatchSemaphore(value: 0)
        var samples: [GazeSample] = []

        Task {
            var status = GazeEngine.cameraPermissionStatus()
            if status == .notDetermined {
                let granted = await GazeEngine.requestCameraAccess()
                status = granted ? .authorized : .denied
            }
            guard status == .authorized else {
                check("camera permission", false, "denied")
                sem.signal()
                return
            }

            let engine = GazeEngine()
            let task = Task {
                for await pose in engine.gazeStream() {
                    samples.append(
                        GazeSample(
                            yawRadians: pose.yawRadians,
                            pitchRadians: pose.pitchRadians,
                            onDisplayAttention: pose.onDisplayAttention
                        )
                    )
                }
            }
            do {
                try engine.start()
            } catch {
                check("GazeEngine.start", false, "\(error)")
                sem.signal()
                return
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            engine.stop()
            task.cancel()
            sem.signal()
        }

        sem.wait()

        guard !samples.isEmpty else {
            check("live frames received", false, "no camera samples")
            return
        }

        let withAttention = samples.filter(\.onDisplayAttention)
        let withModelGaze = samples.filter {
            $0.onDisplayAttention && (abs($0.yawRadians) > 0.02 || abs($0.pitchRadians) > 0.02)
        }
        let maxYaw = samples.map { abs($0.yawRadians) }.max() ?? 0
        let maxPitch = samples.map { abs($0.pitchRadians) }.max() ?? 0

        print("    frames=\(samples.count) attentive=\(withAttention.count) model_gaze=\(withModelGaze.count)")
        print("    max |yaw|=\(String(format: "%.3f", maxYaw)) rad max |pitch|=\(String(format: "%.3f", maxPitch)) rad")

        guard let sample = withModelGaze.last ?? withAttention.last else {
            check(
                "face + model gaze detected",
                false,
                "all samples zero or away — center your face in the webcam for 5 s"
            )
            return
        }

        let dir = GazePipelineSmoke.gazeDirection(
            yawRadians: sample.yawRadians,
            pitchRadians: sample.pitchRadians
        )
        print("    last attentive sample:")
        print("    yaw   = \(String(format: "%.4f", sample.yawRadians)) rad (\(String(format: "%.1f", sample.yawRadians * 180 / .pi))°)")
        print("    pitch = \(String(format: "%.4f", sample.pitchRadians)) rad (\(String(format: "%.1f", sample.pitchRadians * 180 / .pi))°)")
        print("    gx=\(String(format: "%.4f", dir.gx)) gy=\(String(format: "%.4f", dir.gy)) gz=\(String(format: "%.4f", dir.gz))")
        print("    Tip: run again and look left vs right — yaw should change sign/magnitude")
        check("face + model gaze detected", true, "")
        check(
            "gaze vector unit length",
            abs(GazePipelineSmoke.vectorLength(gx: dir.gx, gy: dir.gy, gz: dir.gz) - 1) < 1e-3,
            ""
        )
    }
}

GazeSmokeTest.main()
