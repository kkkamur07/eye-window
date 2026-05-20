import Foundation
import os

public enum Log {
    private static let logger = Logger(subsystem: "com.displayfocus.app", category: "focus")
    private static let maxRecentLines = 16
    private static var recentLines: [String] = []
    private static let lock = NSLock()

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
        lock.unlock()
        onLine?(line)
    }

    private static func timestamped(_ message: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: Date()))] \(message)"
    }
}
