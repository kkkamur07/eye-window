import Foundation

/// Append-only JSONL store of implicitly labeled gaze rows (`~/Library/Application Support/Eye Window/implicit_gaze_dataset.jsonl`).
public final class ImplicitGazeDatasetStore: @unchecked Sendable {
    public static let shared = ImplicitGazeDatasetStore()

    public let fileURL: URL
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private var cachedCount: Int?
    private var cachedDisplay1: Int?
    private var cachedDisplay2: Int?

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = base.appendingPathComponent("Eye Window", isDirectory: true)
            self.fileURL = dir.appendingPathComponent("implicit_gaze_dataset.jsonl")
        }
    }

    public struct Stats: Equatable, Sendable {
        public var total: Int
        public var display1: Int
        public var display2: Int
    }

    @discardableResult
    public func append(_ sample: ImplicitGazeSample) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(sample)
            guard var line = String(data: data, encoding: .utf8) else { return false }
            line.append("\n")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                if let bytes = line.data(using: .utf8) {
                    try handle.write(contentsOf: bytes)
                }
            } else {
                try line.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            if let cachedCount {
                self.cachedCount = cachedCount + 1
                switch sample.display {
                case .one: cachedDisplay1 = (cachedDisplay1 ?? 0) + 1
                case .two: cachedDisplay2 = (cachedDisplay2 ?? 0) + 1
                }
            } else {
                cachedCount = nil
            }
            return true
        } catch {
            return false
        }
    }

    public func stats() -> Stats {
        lock.lock()
        if let cachedCount, let cachedDisplay1, let cachedDisplay2 {
            lock.unlock()
            return Stats(total: cachedCount, display1: cachedDisplay1, display2: cachedDisplay2)
        }
        lock.unlock()
        let loaded = loadAll()
        lock.lock()
        cachedCount = loaded.count
        cachedDisplay1 = loaded.filter { $0.display == .one }.count
        cachedDisplay2 = loaded.filter { $0.display == .two }.count
        let stats = Stats(total: cachedCount ?? 0, display1: cachedDisplay1 ?? 0, display2: cachedDisplay2 ?? 0)
        lock.unlock()
        return stats
    }

    public func loadAll() -> [ImplicitGazeSample] {
        lock.lock()
        defer { lock.unlock() }
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        var out: [ImplicitGazeSample] = []
        let decoder = JSONDecoder()
        for line in text.split(whereSeparator: \.isNewline) {
            guard !line.isEmpty, let data = String(line).data(using: .utf8) else { continue }
            if let sample = try? decoder.decode(ImplicitGazeSample.self, from: data) {
                out.append(sample)
            }
        }
        return out
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL)
        cachedCount = 0
        cachedDisplay1 = 0
        cachedDisplay2 = 0
    }
}

/// Result of attempting to append one implicitly labeled gaze row.
public enum ImplicitGazeRecordOutcome: Equatable, Sendable {
    case saved(ImplicitGazeSample)
    case rejected(ImplicitGazeRejectReason)
}

/// Records labeled rows when the user clicks or switches app focus.
public final class ImplicitGazeCollector: @unchecked Sendable {
    private let buffer: GazeSampleBuffer
    private let store: ImplicitGazeDatasetStore
    private let lock = NSLock()
    private var lastRecordedTime: TimeInterval = 0
    private var lastSavedSample: ImplicitGazeSample?
    public private(set) var rejectedThisSession: Int = 0
    public var onSampleRecorded: (@Sendable (ImplicitGazeSample, ImplicitGazeDatasetStore.Stats) -> Void)?
    public var onSampleRejected: (@Sendable (ImplicitGazeRejectReason) -> Void)?

    public init(
        buffer: GazeSampleBuffer,
        store: ImplicitGazeDatasetStore = .shared
    ) {
        self.buffer = buffer
        self.store = store
    }

    public func resetSessionCounters() {
        lock.lock()
        rejectedThisSession = 0
        lastRecordedTime = 0
        lastSavedSample = nil
        lock.unlock()
    }

    @discardableResult
    public func record(
        display: DisplayNumber,
        source: ImplicitLabelSource,
        at timestamp: TimeInterval = Date.timeIntervalSinceReferenceDate,
        mousePoint: CGPoint? = nil
    ) -> ImplicitGazeRecordOutcome {
        lock.lock()
        if timestamp - lastRecordedTime < ImplicitGazeSampleFilter.minIntervalBetweenSamples {
            lock.unlock()
            return reject(.debounced)
        }
        let lastSaved = lastSavedSample
        lock.unlock()

        guard let window = buffer.windowSnapshot(at: timestamp) else {
            return reject(.insufficientFrames)
        }
        if let reason = ImplicitGazeSampleFilter.evaluate(
            window: window,
            display: display,
            lastSaved: lastSaved
        ) {
            return reject(reason)
        }

        let sample = ImplicitGazeSample(
            timestamp: timestamp,
            display: display,
            feature: window.mean,
            source: source,
            mousePoint: mousePoint
        )
        guard store.append(sample) else {
            return reject(.invalidFeature)
        }

        lock.lock()
        lastRecordedTime = timestamp
        lastSavedSample = sample
        lock.unlock()

        let stats = store.stats()
        onSampleRecorded?(sample, stats)
        return .saved(sample)
    }

    private func reject(_ reason: ImplicitGazeRejectReason) -> ImplicitGazeRecordOutcome {
        lock.lock()
        rejectedThisSession += 1
        lock.unlock()
        onSampleRejected?(reason)
        return .rejected(reason)
    }

    public var stats: ImplicitGazeDatasetStore.Stats {
        store.stats()
    }
}
