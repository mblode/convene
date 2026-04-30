import Foundation
import AppKit

class Logger {
    static let shared = Logger()

    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(label: "co.blode.convene.logger")

    enum LogLevel: String {
        case info = "INFO"
        case error = "ERROR"
        case debug = "DEBUG"
    }

    private init() {
        let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let logsDirectory = libraryDirectory.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        self.logFileURL = logsDirectory.appendingPathComponent("Convene.log")
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        log("Convene application launched", level: .info)
    }

    func log(_ message: String, level: LogLevel = .info) {
        queue.async {
            let timestamp = self.dateFormatter.string(from: Date())
            let logMessage = "[\(timestamp)] [\(level.rawValue)] \(message)\n"

            print("[\(level.rawValue)] \(message)")

            do {
                if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                    let fileHandle = try FileHandle(forWritingTo: self.logFileURL)
                    fileHandle.seekToEndOfFile()
                    if let data = logMessage.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                } else {
                    try logMessage.write(to: self.logFileURL, atomically: true, encoding: .utf8)
                }
            } catch {
                print("Error writing to log file: \(error)")
            }
        }
    }

    func info(_ message: String) { log(message, level: .info) }
    func error(_ message: String) { log(message, level: .error) }
    func debug(_ message: String) { log(message, level: .debug) }

    func openLogFile() { NSWorkspace.shared.open(logFileURL) }

    deinit {
        log("Convene application terminated", level: .info)
    }
}

func logInfo(_ message: String) { Logger.shared.info(message) }
func logError(_ message: String) { Logger.shared.error(message) }
func logDebug(_ message: String) { Logger.shared.debug(message) }
