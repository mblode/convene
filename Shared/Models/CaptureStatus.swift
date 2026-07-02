import Foundation

/// The recording lifecycle's user-facing status. Replaces free-form status strings so the
/// header banner can switch exhaustively over cases instead of matching string prefixes.
/// `error`/`transcriptionWarning` carry an already-formatted message; `displayText`
/// reproduces the exact strings the UI showed before.
enum CaptureStatus: Equatable {
    case idle
    case recording
    case connecting
    case generatingSummary
    case busy
    case alreadyRecording
    case needsAPIKey
    case cancelled
    case error(String)
    case transcriptionWarning(String)
    case saved(message: String)
    case saveFailed(message: String)

    var displayText: String {
        switch self {
        case .idle: return "Idle"
        case .recording: return "Recording…"
        case .connecting: return "Connecting to AssemblyAI…"
        case .generatingSummary: return "Generating summary…"
        case .busy: return "Busy - wait for previous action to finish"
        case .alreadyRecording: return "Already recording"
        case .needsAPIKey: return "Add your AssemblyAI API key in Settings to start recording"
        case .cancelled: return "Recording cancelled"
        case .error(let message): return message
        case .transcriptionWarning(let message): return message
        case .saved(let message): return message
        case .saveFailed(let message): return message
        }
    }
}
