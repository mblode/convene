import Foundation

/// What still stands between a fresh install and a recorded meeting.
///
/// Recomputed on every read rather than stored: the three facts it wraps live in the Keychain, in
/// the system's permission table, and in a security-scoped bookmark — none of which tell the app
/// when they change. A cached copy would go stale the moment someone flipped Convene's microphone
/// switch in iPhone Settings and came back, which is exactly the case the checklist exists for.
///
/// This is the one answer to "can we record yet?", asked by the root screen's empty state and by
/// the record button, so the two can't disagree about it.
struct SetupState: Equatable {
    let hasTranscriptionKey: Bool
    let microphone: MicrophonePermissionState
    let hasChosenFolder: Bool

    @MainActor
    init(store: MobileMeetingStore) {
        hasTranscriptionKey = store.assemblyAIKeyField.hasKey
        microphone = store.recorder.permissionState
        hasChosenFolder = store.persistence.hasConfiguredVault
    }

    /// Whether starting a meeting would get anywhere.
    ///
    /// An unasked microphone deliberately doesn't block. The system prompt is raised by the first
    /// record tap, which is the only moment it explains itself — asking at launch spends the one
    /// prompt iOS ever gives on a screen where nothing has been asked for yet. A *denied*
    /// microphone does block: that prompt won't come back, so the only way through is Settings.
    var canRecord: Bool {
        hasTranscriptionKey && microphone != .denied
    }

    /// Whether the checklist has anything left worth saying.
    ///
    /// The same condition as `canRecord`, because the folder step is a preference rather than a
    /// prerequisite — meetings save to Convene's own folder until someone says otherwise, and a
    /// card that lingered over an optional step would read as an error that can't be cleared.
    var isComplete: Bool {
        canRecord
    }

    var transcriptionKeyStatus: SetupStepStatus {
        hasTranscriptionKey ? .done : .waiting
    }

    var microphoneStatus: SetupStepStatus {
        switch microphone {
        case .granted: .done
        case .undetermined: .waiting
        case .denied: .blocked
        }
    }

    var folderStatus: SetupStepStatus {
        hasChosenFolder ? .done : .waiting
    }
}

enum SetupStepStatus: Equatable {
    /// Nothing left to do.
    case done
    /// Outstanding, and doable from here.
    case waiting
    /// Outstanding, and not fixable inside the app — the microphone switched off in iPhone Settings.
    case blocked
}

enum OnboardingDefaults {
    /// Set when the welcome screen's "Get started" is tapped, so it is shown once per install and
    /// never again. Deliberately not tied to whether setup was finished: someone who skips straight
    /// past it has still read it, and the checklist is what carries the unfinished work forward.
    static let hasSeenWelcomeKey = "hasSeenWelcome"
}
