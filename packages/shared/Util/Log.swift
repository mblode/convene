import Foundation
import os

private let logger = os.Logger(subsystem: "co.blode.convene", category: "app")

func logInfo(_ message: String) {
    logger.info("\(message, privacy: .public)")
}

func logError(_ message: String) {
    logger.error("\(message, privacy: .public)")
}

func logDebug(_ message: String) {
    logger.debug("\(message, privacy: .public)")
}
