import Foundation
import os

/// On-device gaze/focus logging (Console.app: subsystem `com.eyewindow.app`).
public enum EyeWindowLog {
    private static let logger = Logger(subsystem: "com.eyewindow.app", category: "gaze")
    private static let maxRecentLines = 16
    private static var recentLines: [String] = []
    private static let lock = NSLock()

    /// Optional hook (e.g. SessionCoordinator) to mirror lines into the menu UI.
    public static var onLine: ((String) -> Void)?

    public static func info(_ message: String) {
        let line = timestamped(message)
        logger.info("\(line, privacy: .public)")
        fputs(line + "\n", stderr)
        fflush(stderr)
        lock.lock()
        recentLines.append(line)
        if recentLines.count > maxRecentLines {
            recentLines.removeFirst(recentLines.count - maxRecentLines)
        }
        let snapshot = recentLines
        lock.unlock()
        onLine?(line)
        _ = snapshot
    }

    public static func recent() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return recentLines
    }

    public static func clearRecent() {
        lock.lock()
        recentLines.removeAll()
        lock.unlock()
    }

    private static func timestamped(_ message: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: Date()))] \(message)"
    }
}
