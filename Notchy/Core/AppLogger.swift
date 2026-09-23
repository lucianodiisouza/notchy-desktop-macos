import Foundation
import os

/// Diagnostics that show up in Console.app (filter by subsystem "dev.oprimo.notchy").
enum AppLogger {
    private static let log = Logger(subsystem: "dev.oprimo.notchy", category: "app")

    static func info(_ message: String) {
        log.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        log.error("\(message, privacy: .public)")
    }
}
