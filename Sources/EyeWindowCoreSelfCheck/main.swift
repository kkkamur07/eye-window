import CoreGraphics
import CoreML
import Foundation
import EyeWindowCore

precondition(!EyeWindowCore.version.isEmpty, "version empty")

// MARK: - GazeModelLoader

func testGazeModelLoadsFromBundle() {
    let model = try! GazeModelLoader.loadModel()
    let description = model.modelDescription
    precondition(description.inputDescriptionsByName[GazeModelIO.inputName] != nil, "missing input")
    precondition(description.outputDescriptionsByName[GazeModelIO.yawOutputName] != nil, "missing yaw output")
    precondition(description.outputDescriptionsByName[GazeModelIO.pitchOutputName] != nil, "missing pitch output")
}

// MARK: - FocusHistory

func testFocusHistoryRecordAndQuery() {
    let history = FocusHistory()
    let app = AppRef(bundleIdentifier: "com.example.app")

    history.recordFocusChange(app: app, display: .one)

    precondition(history.lastFocused(display: .one) == app, "display 1 should return recorded app")
    precondition(history.lastFocused(display: .two) == nil, "display 2 should be empty")
}

func testFocusHistoryIndependentDisplays() {
    let history = FocusHistory()
    let app1 = AppRef(bundleIdentifier: "com.example.left")
    let app2 = AppRef(bundleIdentifier: "com.example.right")

    history.recordFocusChange(app: app1, display: .one)
    history.recordFocusChange(app: app2, display: .two)

    precondition(history.lastFocused(display: .one) == app1, "display 1 should keep its app")
    precondition(history.lastFocused(display: .two) == app2, "display 2 should keep its app")

    history.recordFocusChange(app: app2, display: .one)
    precondition(history.lastFocused(display: .one) == app2, "display 1 should update independently")
    precondition(history.lastFocused(display: .two) == app2, "display 2 should be unchanged")
}

func testFocusHistoryReset() {
    let history = FocusHistory()
    history.recordFocusChange(app: AppRef(bundleIdentifier: "com.example.a"), display: .one)
    history.recordFocusChange(app: AppRef(bundleIdentifier: "com.example.b"), display: .two)

    history.reset()

    precondition(history.lastFocused(display: .one) == nil, "reset should clear display 1")
    precondition(history.lastFocused(display: .two) == nil, "reset should clear display 2")
}

// MARK: - GazePipelineSmoke

func testGazePipelineSmokePeakDecodeMatchesYakhyo() {
    for bin in [0, 22, 45, 67] {
        let logits = GazePipelineSmoke.peakLogits(bin: bin)
        let rad = GazeInference.decodeAngleRadians(logits: logits)
        let deg = rad * 180 / Double.pi
        let expected = GazePipelineSmoke.expectedDegreesForPeak(bin: bin)
        precondition(abs(deg - expected) < 0.5, "bin \(bin): got \(deg) expected \(expected)")
    }
}

func testGazePipelineSmokeVectorUnitAndForward() {
    let f = GazePipelineSmoke.gazeDirection(yawRadians: 0, pitchRadians: 0)
    precondition(abs(f.gz - 1) < 1e-6 && abs(f.gx) < 1e-6, "forward gaze")
    let len = GazePipelineSmoke.vectorLength(gx: f.gx, gy: f.gy, gz: f.gz)
    precondition(abs(len - 1) < 1e-6, "unit length")
    let v = GazeFeatureVector.fromGaze(yawRadians: 0.4, pitchRadians: -0.2)
    precondition(abs(v.yawRadians - 0.4) < 1e-9, "yaw stored in vector")
    let d = GazePipelineSmoke.gazeDirection(yawRadians: v.yawRadians, pitchRadians: v.pitchRadians)
    precondition(abs(v.gx - d.gx) < 1e-9 && abs(v.gy - d.gy) < 1e-9 && abs(v.gz - d.gz) < 1e-9, "trig consistent")
}

func testGazePipelineSmokeCoreMLUniformGray() {
    let model = try! GazeModelLoader.loadModel()
    let sample = try! GazePipelineSmoke.runUniformGrayInference(model: model)
    precondition(sample.yawRadians.isFinite && sample.pitchRadians.isFinite, "finite angles")
    let dir = GazePipelineSmoke.gazeDirection(yawRadians: sample.yawRadians, pitchRadians: sample.pitchRadians)
    let len = GazePipelineSmoke.vectorLength(gx: dir.gx, gy: dir.gy, gz: dir.gz)
    precondition(abs(len - 1) < 1e-3, "vector length \(len)")
}

// MARK: - GazeInference

func testDecodeAngleRadiansCenterBin() {
    var logits = [Float](repeating: -20, count: GazeModelIO.logitBinCount)
    logits[45] = 20
    let radians = GazeInference.decodeAngleRadians(logits: logits)
    precondition(abs(radians) < 0.02, "peak at bin 45 → ~0°")
}

func testDecodeAngleRadiansUniform() {
    let logits = [Float](repeating: 0, count: GazeModelIO.logitBinCount)
    let radians = GazeInference.decodeAngleRadians(logits: logits)
    let expected = -2.0 * Double.pi / 180
    precondition(abs(radians - expected) < 0.02, "uniform logits → mean bin 44.5 → ~-2°")
}

func testOnDisplayAttentionFromPitch() {
    precondition(GazeInference.onDisplayAttention(pitchRadians: 0), "level gaze is attentive")
    precondition(GazeInference.onDisplayAttention(pitchRadians: -0.7), "wide band includes moderate down")
    precondition(!GazeInference.onDisplayAttention(pitchRadians: -1.5), "extreme down is not attentive")
}

func testGazeSampleMapsToHeadPose() {
    let logits = [Float](repeating: 0, count: GazeModelIO.logitBinCount)
    let sample = GazeInference.gazeSample(yawLogits: logits, pitchLogits: logits)
    let pose = sample.headPose
    precondition(abs(pose.yawRadians - sample.yawRadians) < 0.001, "headPose yaw matches sample")
    precondition(pose.onDisplayAttention == sample.onDisplayAttention, "headPose attention matches sample")
}

func testGazeFeatureVectorFromPoseUsesGazeYaw() {
    let pose = HeadPose(yawRadians: 0.35, pitchRadians: -0.15, onDisplayAttention: true)
    let feature = GazeFeatureVector.fromPose(pose)
    precondition(abs(feature.yawRadians - 0.35) < 1e-9, "fromPose must use gaze yaw not head heuristic")
    precondition(abs(feature.pitchRadians - (-0.15)) < 1e-9, "fromPose must use gaze pitch")
    let dir = GazePipelineSmoke.gazeDirection(yawRadians: feature.yawRadians, pitchRadians: feature.pitchRadians)
    precondition(abs(feature.gx - dir.gx) < 1e-9 && abs(feature.gy - dir.gy) < 1e-9 && abs(feature.gz - dir.gz) < 1e-9, "vector from pose matches trig")
}

// MARK: - GazeStateMachine

@discardableResult
func stableFeed(
    _ sm: inout GazeStateMachine,
    pose: HeadPose,
    layout: DualLayout,
    start: TimeInterval,
    profile: CalibrationProfile? = nil
) -> FocusIntent? {
    let frameCount = profile != nil
        ? max(GazeStateMachine.requiredStableFrames, GazeStateMachine.sessionWarmupFrames)
        : GazeStateMachine.requiredStableFrames
    var last: (intent: FocusIntent?, status: GazeStatus)?
    for i in 0 ..< frameCount {
        last = sm.feed(
            pose: pose,
            layout: layout,
            now: start + Double(i) * 0.01,
            profile: profile
        )
    }
    return last?.intent
}

func afterDwell(_ start: TimeInterval) -> TimeInterval {
    start
        + Double(GazeStateMachine.requiredStableFrames - 1) * 0.01
        + GazeStateMachine.mediumDwellDuration
        + 0.05
}

func testDwellNotMetReturnsNil() {
    var sm = GazeStateMachine()
    let layout = DualLayout(display1IsLeft: true)
    let leftPose = HeadPose(yawRadians: -0.5, onDisplayAttention: true)

    let beforeDwell = stableFeed(&sm, pose: leftPose, layout: layout, start: 0)
    precondition(beforeDwell == nil, "dwell not met should return nil")

    let stillBeforeDwell = sm.feed(pose: leftPose, layout: layout, now: 0.2).intent
    precondition(stillBeforeDwell == nil, "0.2s before dwell completes should return nil")
}

func testDwellMetEmitsIntent() {
    var sm = GazeStateMachine()
    let layout = DualLayout(display1IsLeft: true)
    let leftPose = HeadPose(yawRadians: -0.5, onDisplayAttention: true)

    _ = stableFeed(&sm, pose: leftPose, layout: layout, start: 0)
    let intent = sm.feed(pose: leftPose, layout: layout, now: afterDwell(0)).intent
    precondition(intent?.display == .one, "dwell met on left should intent display 1")
}

func testFocusLockBlocksBriefOppositePose() {
    var sm = GazeStateMachine()
    let layout = DualLayout(display1IsLeft: true)
    let leftPose = HeadPose(yawRadians: -0.5, onDisplayAttention: true)
    let rightPose = HeadPose(yawRadians: 0.5, onDisplayAttention: true)

    _ = stableFeed(&sm, pose: leftPose, layout: layout, start: 0)
    _ = sm.feed(pose: leftPose, layout: layout, now: afterDwell(0))

    let briefGlance = sm.feed(pose: rightPose, layout: layout, now: 1.0).intent
    precondition(briefGlance == nil, "brief opposite pose should not emit intent")

    let afterGlance = sm.feed(pose: leftPose, layout: layout, now: 1.2).intent
    precondition(afterGlance == nil, "return to locked display should not re-emit intent")

    _ = stableFeed(&sm, pose: rightPose, layout: layout, start: 1.3)
    let switchIntent = sm.feed(pose: rightPose, layout: layout, now: afterDwell(1.3)).intent
    precondition(switchIntent?.display == .two, "full dwell on other display should switch")
}

func testPlaceholderPoseIsInvalid() {
    let placeholder = HeadPose(yawRadians: 0, pitchRadians: 0, onDisplayAttention: false)
    precondition(!placeholder.isValidGazeSample, "legacy no-face placeholder")
    let real = HeadPose(yawRadians: 0, pitchRadians: 0, onDisplayAttention: true)
    precondition(real.isValidGazeSample, "forward gaze is valid")
}

func testCenterYawReturnsNil() {
    var sm = GazeStateMachine()
    let layout = DualLayout(display1IsLeft: true)
    let left = HeadPose(yawRadians: -0.5, onDisplayAttention: true)
    let center = HeadPose(yawRadians: 0.05, onDisplayAttention: true)

    _ = stableFeed(&sm, pose: left, layout: layout, start: 0)
    let centerIntent = sm.feed(pose: center, layout: layout, now: 0.5).intent
    precondition(centerIntent == nil, "center yaw should not switch")

    let afterLeft = sm.feed(pose: left, layout: layout, now: 1.0).intent
    precondition(afterLeft == nil, "dwell resets after center; 0.5s not enough")
}

func testGazeStateMachineCalibratedMapping() {
    let d1 = GazeFeatureVector.fromGaze(yawRadians: -0.5, pitchRadians: 0)
    let d2 = GazeFeatureVector.fromGaze(yawRadians: 0.5, pitchRadians: 0)
    let profile = CalibrationProfile(display1: d1, display2: d2)
    let layout = DualLayout(display1IsLeft: true)
    let leftPose = HeadPose(yawRadians: -0.48, pitchRadians: 0, onDisplayAttention: true)
    let rightPose = HeadPose(yawRadians: 0.48, pitchRadians: 0, onDisplayAttention: true)

    var smLeft = GazeStateMachine()
    _ = stableFeed(&smLeft, pose: leftPose, layout: layout, start: 0, profile: profile)
    let leftIntent = smLeft.feed(pose: leftPose, layout: layout, now: afterDwell(0), profile: profile).intent
    precondition(leftIntent?.display == .one, "nearest D1 prototype → display 1")

    var smRight = GazeStateMachine()
    _ = stableFeed(&smRight, pose: rightPose, layout: layout, start: 0, profile: profile)
    let rightIntent = smRight.feed(pose: rightPose, layout: layout, now: afterDwell(0), profile: profile).intent
    precondition(rightIntent?.display == .two, "nearest D2 prototype → display 2")
}

func testYawMapsToCorrectDisplay() {
    let layoutLeftFirst = DualLayout(display1IsLeft: true)
    let layoutRightFirst = DualLayout(display1IsLeft: false)
    let leftYaw = HeadPose(yawRadians: -0.5, onDisplayAttention: true)
    let rightYaw = HeadPose(yawRadians: 0.5, onDisplayAttention: true)

    var sm1 = GazeStateMachine()
    _ = stableFeed(&sm1, pose: leftYaw, layout: layoutLeftFirst, start: 0)
    let leftIntent = sm1.feed(pose: leftYaw, layout: layoutLeftFirst, now: afterDwell(0)).intent
    precondition(leftIntent?.display == .one, "left yaw + display1 left → display 1")

    var sm2 = GazeStateMachine()
    _ = stableFeed(&sm2, pose: rightYaw, layout: layoutLeftFirst, start: 0)
    let rightIntent = sm2.feed(pose: rightYaw, layout: layoutLeftFirst, now: afterDwell(0)).intent
    precondition(rightIntent?.display == .two, "right yaw + display1 left → display 2")

    var sm3 = GazeStateMachine()
    _ = stableFeed(&sm3, pose: leftYaw, layout: layoutRightFirst, start: 0)
    let swappedLeft = sm3.feed(pose: leftYaw, layout: layoutRightFirst, now: afterDwell(0)).intent
    precondition(swappedLeft?.display == .two, "left yaw + display1 right → display 2")

    var sm4 = GazeStateMachine()
    _ = stableFeed(&sm4, pose: rightYaw, layout: layoutRightFirst, start: 0)
    let swappedRight = sm4.feed(pose: rightYaw, layout: layoutRightFirst, now: afterDwell(0)).intent
    precondition(swappedRight?.display == .one, "right yaw + display1 right → display 1")
}

// MARK: - FocusDisplayMapping

func testPointOnDisplay1() {
    let display1 = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let display2 = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
    let point = CGPoint(x: 960, y: 540)

    let display = FocusDisplayMapping.display(for: point, display1Frame: display1, display2Frame: display2)
    precondition(display == .one, "center of display 1 should map to display 1")
}

func testPointOnDisplay2() {
    let display1 = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let display2 = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
    let point = CGPoint(x: 2880, y: 540)

    let display = FocusDisplayMapping.display(for: point, display1Frame: display1, display2Frame: display2)
    precondition(display == .two, "center of display 2 should map to display 2")
}

func testPointBetweenDisplaysUsesNearest() {
    let display1 = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let display2 = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
    let point = CGPoint(x: 2000, y: 540)

    let display = FocusDisplayMapping.display(for: point, display1Frame: display1, display2Frame: display2)
    precondition(display == .two, "point nearer display 2 center should map to display 2")
}

func testPointOutsideBothUsesNearest() {
    let display1 = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let display2 = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
    let point = CGPoint(x: -100, y: 540)

    let display = FocusDisplayMapping.display(for: point, display1Frame: display1, display2Frame: display2)
    precondition(display == .one, "off-screen point nearer display 1 should map to display 1")
}

// MARK: - Implicit learning

func testGazeSampleBufferRepresentativeFeature() {
    let buffer = GazeSampleBuffer(capacity: 30)
    let f1 = GazeFeatureVector.fromGaze(yawRadians: -0.5, pitchRadians: 0)
    let f2 = GazeFeatureVector.fromGaze(yawRadians: -0.4, pitchRadians: 0)
    buffer.append(f1, at: 1.0)
    buffer.append(f2, at: 1.1)
    buffer.append(f2, at: 1.2)
    let mean = buffer.representativeFeature(at: 1.25, maxAge: 0.5, minFrames: 3)
    precondition(mean != nil, "3 frames in window → representative feature")
    precondition(abs(mean!.yawRadians - (-0.43)) < 0.05, "mean yaw near -0.43")
}

func testImplicitGazeDatasetStoreRoundTrip() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = dir.appendingPathComponent("implicit.jsonl")
    let store = ImplicitGazeDatasetStore(fileURL: url)
    let sample = ImplicitGazeSample(
        timestamp: 100,
        display: .one,
        feature: GazeFeatureVector.fromGaze(yawRadians: 0.2, pitchRadians: -0.1),
        source: .mouseClick,
        mousePoint: CGPoint(x: 400, y: 300)
    )
    precondition(store.append(sample), "append should succeed")
    let loaded = store.loadAll()
    precondition(loaded.count == 1, "one row loaded")
    precondition(loaded[0].display == .one, "display label preserved")
    precondition(abs(loaded[0].yawRadians - 0.2) < 1e-9, "yaw preserved")
    let stats = store.stats()
    precondition(stats.total == 1 && stats.display1 == 1, "stats updated")
    try? FileManager.default.removeItem(at: dir)
}

func testImplicitGazeRecordFromBuffer() {
    let buffer = GazeSampleBuffer()
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = ImplicitGazeDatasetStore(fileURL: dir.appendingPathComponent("implicit.jsonl"))
    let f = GazeFeatureVector.fromGaze(yawRadians: 0.3, pitchRadians: 0)
    for i in 0 ..< 5 {
        buffer.append(f, at: 10.0 + Double(i) * 0.05)
    }
    guard let feature = buffer.representativeFeature(at: 10.3) else {
        preconditionFailure("buffer window → feature")
    }
    precondition(
        store.append(ImplicitGazeSample(timestamp: 10.3, display: .one, feature: feature, source: .mouseClick)),
        "saves row"
    )
    guard let feature2 = buffer.representativeFeature(at: 10.35) else {
        preconditionFailure("second window → feature")
    }
    precondition(
        store.append(ImplicitGazeSample(timestamp: 10.35, display: .two, feature: feature2, source: .appFocus)),
        "saves second row"
    )
    precondition(store.stats().total == 2, "two rows in dataset")
    try? FileManager.default.removeItem(at: dir)
}

// MARK: - Calibration (vector prototypes)

func testGazeFeatureVectorFromGaze() {
    let v = GazeFeatureVector.fromGaze(yawRadians: 0, pitchRadians: 0)
    precondition(abs(v.gx) < 0.001 && abs(v.gy) < 0.001 && abs(v.gz - 1) < 0.001, "forward gaze unit vector")
    precondition(abs(v.yawRadians) < 0.001, "yaw stored")
}

func testGazeCalibrationRulesNearestDisplay() {
    let profile = CalibrationProfile(
        display1: GazeFeatureVector.fromGaze(yawRadians: -0.5, pitchRadians: 0),
        display2: GazeFeatureVector.fromGaze(yawRadians: 0.5, pitchRadians: 0)
    )
    let left = GazeFeatureVector.fromGaze(yawRadians: -0.48, pitchRadians: 0)
    let right = GazeFeatureVector.fromGaze(yawRadians: 0.48, pitchRadians: 0)
    precondition(
        GazeCalibrationRules.mapDisplay(feature: left, profile: profile) == .one,
        "near D1 prototype"
    )
    precondition(
        GazeCalibrationRules.mapDisplay(feature: right, profile: profile) == .two,
        "near D2 prototype"
    )
}

func testCalibrationProfile5DMapping() {
    let d1 = GazeFeatureVector.fromGaze(yawRadians: -0.4, pitchRadians: 0.05)
    let d2 = GazeFeatureVector.fromGaze(yawRadians: 0.35, pitchRadians: 0.02)
    let profile = CalibrationProfile(
        display1: d1,
        display2: d2,
        display1Spread: GazeFeatureSpread(gx: 0.02, gy: 0.02, gz: 0.02, yawRadians: 0.02, pitchRadians: 0.02),
        display2Spread: GazeFeatureSpread(gx: 0.02, gy: 0.02, gz: 0.02, yawRadians: 0.02, pitchRadians: 0.02)
    )
    precondition(profile.mappedDisplay(feature: d1) == .one, "D1 prototype → D1")
    precondition(profile.mappedDisplay(feature: d2) == .two, "D2 prototype → D2")
}

func testGazeFeatureSpreadFromSamples() {
    var samples: [GazeFeatureVector] = []
    for _ in 0 ..< 20 {
        samples.append(GazeFeatureVector.fromGaze(yawRadians: 0.3, pitchRadians: -0.1))
    }
    let spread = GazeFeatureSpread.fromSamples(samples)
    precondition(abs(spread.maxComponent - GazeFeatureSpread.minStd) < 1e-9, "identical samples → min std floor")
}

func testMahalanobisWeightsNoisyAxisLess() {
    let proto = GazeFeatureVector.fromGaze(yawRadians: 0.3, pitchRadians: 0)
    let tight = GazeFeatureSpread(gx: 0.02, gy: 0.02, gz: 0.02, yawRadians: 0.02, pitchRadians: 0.02)
    let loose = GazeFeatureSpread(gx: 0.2, gy: 0.02, gz: 0.02, yawRadians: 0.02, pitchRadians: 0.02)
    let shiftedGx = GazeFeatureVector.fromGaze(yawRadians: 0.32, pitchRadians: 0)
    let dTight = shiftedGx.mahalanobisSquared(to: proto, spread: tight)
    let dLoose = shiftedGx.mahalanobisSquared(to: proto, spread: loose)
    precondition(dLoose < dTight, "large gx std should down-weight gx offset")
}

func testSwitchHysteresisKeepsLockedDisplay() {
    let d1 = GazeFeatureVector.fromGaze(yawRadians: -0.4, pitchRadians: 0)
    let d2 = GazeFeatureVector.fromGaze(yawRadians: 0.4, pitchRadians: 0)
    let spread = GazeFeatureSpread(gx: 0.02, gy: 0.02, gz: 0.02, yawRadians: 0.02, pitchRadians: 0.02)
    let profile = CalibrationProfile(
        display1: d1,
        display2: d2,
        display1Spread: spread,
        display2Spread: spread
    )
    let between = GazeFeatureVector.fromGaze(yawRadians: 0.0, pitchRadians: 0)
    precondition(
        profile.nearestDisplay(current: between, lockedDisplay: .one) == .one,
        "near-tie with lock on D1 should not flip to D2"
    )
    precondition(
        profile.nearestDisplay(current: between, lockedDisplay: nil) == .one,
        "without lock, tie still picks D1"
    )
}

func testCalibrationTuningTighterYawGapIsStickier() {
    let wide = CalibrationTuning.derive(
        display1: GazeFeatureVector.fromGaze(yawRadians: 0.10, pitchRadians: 0),
        display2: GazeFeatureVector.fromGaze(yawRadians: 0.20, pitchRadians: 0),
        display1Spread: .default,
        display2Spread: .default
    )
    let tight = CalibrationTuning.derive(
        display1: GazeFeatureVector.fromGaze(yawRadians: 0.18, pitchRadians: 0),
        display2: GazeFeatureVector.fromGaze(yawRadians: 0.20, pitchRadians: 0),
        display1Spread: .default,
        display2Spread: .default
    )
    precondition(
        tight.switchAdvantageRatio > wide.switchAdvantageRatio,
        "smaller yaw gap → larger switch margin"
    )
    precondition(tight.requiredStableFrames >= wide.requiredStableFrames, "smaller yaw gap → more stable frames")
    precondition(tight.mediumDwellDuration >= wide.mediumDwellDuration, "smaller yaw gap → longer dwell")
}

func testCalibrationQualityRejectsLowReplay() {
    let d1 = GazeFeatureVector.fromGaze(yawRadians: -0.5, pitchRadians: 0.05)
    let d2 = GazeFeatureVector.fromGaze(yawRadians: 0.5, pitchRadians: 0.05)
    let profile = CalibrationProfile.derive(display1Samples: [d1], display2Samples: [d2], refine: false)
    // Mixed frames: half labeled D1, half D2 — replay should be ~50%.
    let mixed = [d1, d2, d1, d2]
    let report = CalibrationQuality.evaluate(profile: profile, display1Samples: mixed, display2Samples: mixed)
    precondition(report.vecGap >= CalibrationQuality.minVecSeparation, "well-separated prototypes")
    precondition(!report.passed, "ambiguous replay should fail quality gate")
    precondition(
        CalibrationQuality.failureLines(report).contains { $0.contains("replay") },
        "failure message mentions replay"
    )
}

func testCalibrationQualityRejectsSmallYawGap() {
    let d1 = GazeFeatureVector.fromGaze(yawRadians: -0.5, pitchRadians: 0.05)
    let d2 = GazeFeatureVector.fromGaze(yawRadians: -0.48, pitchRadians: -0.12)
    let d1s = (0..<40).map { _ in d1 }
    let d2s = (0..<40).map { _ in d2 }
    let profile = CalibrationProfile.derive(display1Samples: d1s, display2Samples: d2s, refine: false)
    let report = CalibrationQuality.evaluate(profile: profile, display1Samples: d1s, display2Samples: d2s)
    precondition(report.yawGapRadians < CalibrationQuality.minYawGapRadians, "fixtures under 3° yaw gap")
    precondition(!report.passed, "yaw gap < 3° must fail quality gate")
    precondition(
        CalibrationQuality.failureLines(report).contains { $0.contains("yaw gap") },
        "failure message mentions yaw gap"
    )
}

func testCalibrationYawOnlyReplaySeparatesDisplays() {
    let d1 = GazeFeatureVector.fromGaze(yawRadians: -0.5, pitchRadians: 0.05)
    let d2 = GazeFeatureVector.fromGaze(yawRadians: 0.5, pitchRadians: 0.05)
    let profile = CalibrationProfile(display1: d1, display2: d2)
    let d1s = (0..<30).map { _ in d1 }
    let d2s = (0..<30).map { _ in d2 }
    let report = CalibrationQuality.evaluate(profile: profile, display1Samples: d1s, display2Samples: d2s)
    precondition(report.yawGapRadians >= CalibrationQuality.minYawGapRadians, "≥3° yaw separation")
    precondition(report.yawReplayAccuracy >= 0.95, "yaw-only nearest should separate D1/D2")
    precondition(
        GazeCalibrationRules.mapDisplayYawOnly(yawRadians: -0.48, profile: profile) == .one,
        "left yaw → D1"
    )
    precondition(
        GazeCalibrationRules.mapDisplayYawOnly(yawRadians: 0.48, profile: profile) == .two,
        "right yaw → D2"
    )
}

func testNearestMeanTieBreaksToDisplay1() {
    let profile = CalibrationProfile(
        display1: GazeFeatureVector.fromGaze(yawRadians: -0.3, pitchRadians: 0),
        display2: GazeFeatureVector.fromGaze(yawRadians: 0.3, pitchRadians: 0)
    )
    let mid = GazeFeatureVector.fromGaze(yawRadians: 0, pitchRadians: 0)
    precondition(profile.mappedDisplay(feature: mid) == .one, "equal Mahalanobis distance → display 1")
}

func testCalibrationProfileSmokeYawGap() {
    let d1 = GazeFeatureVector.fromGaze(yawRadians: 0.4827, pitchRadians: -0.1179)
    let d2 = GazeFeatureVector.fromGaze(yawRadians: 0.3309, pitchRadians: -0.1052)
    let profile = CalibrationProfile.derive(display1Samples: [d1], display2Samples: [d2], refine: false)
    precondition(profile.mappedDisplay(feature: d1) == .one, "laptop gaze → D1")
    precondition(profile.mappedDisplay(feature: d2) == .two, "right monitor gaze → D2")
}

func testCalibrationQualityRefinementImprovesGxGap() {
    var d1: [GazeFeatureVector] = []
    var d2: [GazeFeatureVector] = []
    for _ in 0 ..< 40 {
        d1.append(GazeFeatureVector.fromGaze(yawRadians: 0.10, pitchRadians: -0.12))
        d2.append(GazeFeatureVector.fromGaze(yawRadians: 0.40, pitchRadians: -0.10))
    }
    // Outliers: D1 frames that look like D2
    for _ in 0 ..< 8 {
        d1.append(GazeFeatureVector.fromGaze(yawRadians: 0.38, pitchRadians: -0.10))
    }
    let raw = CalibrationProfile.derive(display1Samples: d1, display2Samples: d2, refine: false)
    let refined = CalibrationProfile.derive(display1Samples: d1, display2Samples: d2, refine: true)
    let rawGx = abs(raw.display1.gx - raw.display2.gx)
    let refinedGx = abs(refined.display1.gx - refined.display2.gx)
    precondition(refinedGx >= rawGx * 0.9, "refined gx gap \(refinedGx) vs raw \(rawGx)")
    let r = CalibrationQuality.refineSamples(display1: d1, display2: d2)
    let report = CalibrationQuality.evaluate(
        profile: refined,
        display1Samples: r.display1,
        display2Samples: r.display2
    )
    precondition(report.gxGap >= 0.15, "gx gap \(report.gxGap)")
}

func testCalibrationFlowMultiTarget() {
    var flow = CalibrationFlow()
    flow.begin()
    precondition(flow.phase == .lookAt(display: .one, target: .center), "flow starts at D1 center")

    var t = 0.0
    let d1Feature = GazeFeatureVector.fromGaze(yawRadians: -0.4, pitchRadians: 0.05)
    let d2Feature = GazeFeatureVector.fromGaze(yawRadians: 0.35, pitchRadians: 0.02)

    func feedUntilPhaseChanges(_ feature: GazeFeatureVector) -> CalibrationProfile? {
        let before = flow.phase
        var guardCount = 0
        while flow.phase == before, guardCount < 200 {
            if let profile = flow.feed(feature: feature, now: t) {
                return profile
            }
            t += 0.08
            guardCount += 1
        }
        precondition(flow.phase != before, "calibration step should advance")
        return nil
    }

    for target in CalibrationFlow.targetSequence {
        precondition(flow.phase == .lookAt(display: .one, target: target))
        precondition(feedUntilPhaseChanges(d1Feature) == nil)
    }
    precondition(flow.phase == .lookAt(display: .two, target: .center))

    for (index, target) in CalibrationFlow.targetSequence.enumerated() {
        precondition(flow.phase == .lookAt(display: .two, target: target))
        if index < CalibrationFlow.targetSequence.count - 1 {
            precondition(feedUntilPhaseChanges(d2Feature) == nil)
        } else if let profile = feedUntilPhaseChanges(d2Feature) {
            precondition(abs(profile.display1.yawRadians - (-0.4)) < 0.05)
            precondition(abs(profile.display2.yawRadians - 0.35) < 0.05)
            precondition(flow.phase == .complete)
        } else {
            var guardCount = 0
            var profile: CalibrationProfile?
            while profile == nil, guardCount < 200 {
                profile = flow.feed(feature: d2Feature, now: t)
                t += 0.08
                guardCount += 1
            }
            guard let profile else { preconditionFailure("D2 last step should finish calibration") }
            precondition(abs(profile.display1.yawRadians - (-0.4)) < 0.05)
            precondition(abs(profile.display2.yawRadians - 0.35) < 0.05)
            precondition(flow.phase == .complete)
        }
    }
}

func testCalibrationStoreRoundTrip() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = dir.appendingPathComponent("calibration.json")
    let store = CalibrationStore(fileURL: url)
    precondition(!store.isCalibrated, "fresh store is not calibrated")

    let profile = CalibrationProfile(
        display1: GazeFeatureVector.fromGaze(yawRadians: -0.3, pitchRadians: 0),
        display2: GazeFeatureVector.fromGaze(yawRadians: 0.25, pitchRadians: 0),
        display1Spread: GazeFeatureSpread(gx: 0.03, gy: 0.03, gz: 0.03, yawRadians: 0.02, pitchRadians: 0.02),
        display2Spread: GazeFeatureSpread(gx: 0.03, gy: 0.03, gz: 0.03, yawRadians: 0.02, pitchRadians: 0.02)
    )
    precondition(store.save(profile), "save should succeed")

    let reloaded = CalibrationStore(fileURL: url)
    precondition(reloaded.isCalibrated, "reloaded store is calibrated")
    let loaded = reloaded.load()
    precondition(loaded == profile, "round-trip profile match")

    reloaded.clear()
    precondition(!reloaded.isCalibrated, "clear removes calibration")
    try? FileManager.default.removeItem(at: dir)
}

func testGazeCalibrationRulesPoseLabel() {
    let profile = CalibrationProfile(
        display1: GazeFeatureVector.fromGaze(yawRadians: -0.5, pitchRadians: 0),
        display2: GazeFeatureVector.fromGaze(yawRadians: 0.5, pitchRadians: 0)
    )
    let left = HeadPose(yawRadians: -0.48, pitchRadians: 0, onDisplayAttention: true)
    let center = HeadPose(yawRadians: 0.0, pitchRadians: 0, onDisplayAttention: true)
    precondition(GazeCalibrationRules.poseLabel(pose: left, profile: profile) == "D1", "near D1")
    precondition(GazeCalibrationRules.poseLabel(pose: center, profile: profile) == "D1", "tie → D1")
}

func testSessionCoordinatorPoseLabelUncalibratedFallback() {
    let left = HeadPose(yawRadians: -0.5, onDisplayAttention: true)
    precondition(SessionCoordinator.poseLabelUncalibrated(for: left) == "L", "uncalibrated uses global threshold")
}

// MARK: - DisplayMonitor

func testTwoDisplaysDisplay1Left() {
    let layout = DisplayMonitor.layoutFromDisplayCount(2, display1MinX: 0, display2MinX: 1920)
    guard case .dual(let dual) = layout else {
        preconditionFailure("two displays should be dual")
    }
    precondition(dual.display1IsLeft, "display 1 left of display 2 → display1IsLeft")
}

func testTwoDisplaysDisplay1Right() {
    let layout = DisplayMonitor.layoutFromDisplayCount(2, display1MinX: 1920, display2MinX: 0)
    guard case .dual(let dual) = layout else {
        preconditionFailure("two displays should be dual")
    }
    precondition(!dual.display1IsLeft, "display 1 right of display 2 → not display1IsLeft")
}

func testThreeDisplaysNotDual() {
    let layout = DisplayMonitor.layoutFromDisplayCount(3, display1MinX: 0, display2MinX: 1920)
    precondition(layout == .notDual, "three displays should be notDual")
}

func testOneDisplayNotDual() {
    let layout = DisplayMonitor.layoutFromDisplayCount(1, display1MinX: 0, display2MinX: 0)
    precondition(layout == .notDual, "one display should be notDual")
}

func testZeroDisplaysNotDual() {
    let layout = DisplayMonitor.layoutFromDisplayCount(0, display1MinX: 0, display2MinX: 0)
    precondition(layout == .notDual, "zero displays should be notDual")
}

testFocusHistoryRecordAndQuery()
testFocusHistoryIndependentDisplays()
testFocusHistoryReset()

testPointOnDisplay1()
testPointOnDisplay2()
testPointBetweenDisplaysUsesNearest()
testPointOutsideBothUsesNearest()

testGazePipelineSmokePeakDecodeMatchesYakhyo()
testGazePipelineSmokeVectorUnitAndForward()
testGazePipelineSmokeCoreMLUniformGray()

testDecodeAngleRadiansCenterBin()
testDecodeAngleRadiansUniform()
testOnDisplayAttentionFromPitch()
testGazeSampleMapsToHeadPose()
testGazeFeatureVectorFromPoseUsesGazeYaw()

testGazeSampleBufferRepresentativeFeature()
testImplicitGazeDatasetStoreRoundTrip()
testImplicitGazeRecordFromBuffer()

testDwellNotMetReturnsNil()
testDwellMetEmitsIntent()
testFocusLockBlocksBriefOppositePose()
testPlaceholderPoseIsInvalid()
testCenterYawReturnsNil()
testYawMapsToCorrectDisplay()
testGazeStateMachineCalibratedMapping()

testGazeFeatureVectorFromGaze()
testGazeCalibrationRulesNearestDisplay()
testCalibrationProfile5DMapping()
testGazeFeatureSpreadFromSamples()
testMahalanobisWeightsNoisyAxisLess()
testSwitchHysteresisKeepsLockedDisplay()
testNearestMeanTieBreaksToDisplay1()
testCalibrationProfileSmokeYawGap()
testCalibrationQualityRefinementImprovesGxGap()
testCalibrationQualityRejectsLowReplay()
testCalibrationQualityRejectsSmallYawGap()
testCalibrationYawOnlyReplaySeparatesDisplays()
testCalibrationFlowMultiTarget()
testCalibrationStoreRoundTrip()
testGazeCalibrationRulesPoseLabel()
testSessionCoordinatorPoseLabelUncalibratedFallback()

testTwoDisplaysDisplay1Left()
testTwoDisplaysDisplay1Right()
testThreeDisplaysNotDual()
testOneDisplayNotDual()
testZeroDisplaysNotDual()

testGazeModelLoadsFromBundle()

print("EyeWindowCoreSelfCheck OK")
