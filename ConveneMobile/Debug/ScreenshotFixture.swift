#if DEBUG
import Foundation
import SwiftUI

/// The App Store screenshot fixture: a library of plausible meetings, a cleared setup checklist,
/// and one meeting posed as if it were running right now.
///
/// Gated on the `CONVENE_UI_TEST_SCREENSHOT_MODE` launch argument *and* on `#if DEBUG`, so a
/// Release build cannot contain a line of it and a normal `make ios-run` launch never reaches it.
/// `screenshots/capture.sh` is the only thing that passes the argument.
///
/// Meetings are seeded through the real write path — `MobilePersistenceService` →
/// `MeetingFileWriter` → `MarkdownRenderer` — rather than pushed into the views, so the markdown on
/// disk and the library read back off it are exactly what a recorded meeting produces. The one
/// thing genuinely faked is the live meeting behind slide 1, which can't be had honestly without a
/// microphone in a room and a billed transcription socket.
@MainActor
enum ScreenshotFixture {
    static let launchArgument = "CONVENE_UI_TEST_SCREENSHOT_MODE"
    /// Companion flag for the dark slides. The simulator's own appearance would do, but flipping it
    /// between runs means two `xcodebuild test` invocations and two result bundles to merge.
    static let darkModeArgument = "CONVENE_UI_TEST_DARK_MODE"
    /// Separate from the rest, because the posed meeting turns the floating record pill red and
    /// puts a running clock in it — which is the point of slide 1 and wrong on every other slide
    /// that shows the list.
    static let liveMeetingArgument = "CONVENE_UI_TEST_LIVE_MEETING"

    static var isEnabled: Bool { hasArgument(launchArgument) }

    /// `nil` — leave the system to decide — unless the dark flag is set, so this is a no-op in
    /// every launch that isn't a screenshot run.
    static var preferredColorScheme: ColorScheme? {
        isEnabled && hasArgument(darkModeArgument) ? .dark : nil
    }

    /// Called at the end of `MobileMeetingStore.prepare()`. Returns immediately unless the flag is
    /// set, which is what keeps a normal launch identical to what it was.
    static func seed(into store: MobileMeetingStore) {
        guard isEnabled else { return }

        clearOnboarding()
        storePlaceholderKeys(into: store)
        let vault = useFixtureVault(store.persistence)
        discardPreviousSeed(vault: vault)

        for meeting in savedMeetings() {
            store.persistence.save(meeting)
        }
        store.library.reload()

        if hasArgument(liveMeetingArgument) {
            poseRunningMeeting(in: store)
        }
        logInfo("ScreenshotFixture: seeded \(store.library.meetings.count) meetings")
    }

    private static func hasArgument(_ name: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(name)
    }

    // MARK: - Setup state

    /// `WelcomeView` is a `fullScreenCover` over everything, so without this every capture is the
    /// welcome screen.
    private static func clearOnboarding() {
        UserDefaults.standard.set(true, forKey: OnboardingDefaults.hasSeenWelcomeKey)
    }

    /// Placeholders, not keys: `SetupState.canRecord` only asks whether one is stored, and Settings
    /// only shows a "Saved" tick beside a `SecureField` full of dots. Nothing in a screenshot run
    /// ever opens a socket with these.
    private static func storePlaceholderKeys(into store: MobileMeetingStore) {
        store.assemblyAIKeyField.value = String(repeating: "0", count: 32)
        store.assemblyAIKeyField.save()
        store.claudeKeyField.value = "sk-ant-" + String(repeating: "0", count: 32)
        store.claudeKeyField.save()
        store.openAIKeyField.value = "sk-" + String(repeating: "0", count: 32)
        store.openAIKeyField.save()
    }

    /// A real folder inside the app's own Documents, named so Settings' "Saving to" row reads
    /// "Obsidian › Meetings" — which is the arrangement the listing describes, and the one the
    /// markdown genuinely lands in for the rest of the run.
    @discardableResult
    private static func useFixtureVault(_ persistence: MobilePersistenceService) -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        let vault =
            documents
            .appendingPathComponent("Obsidian", isDirectory: true)
            .appendingPathComponent("Meetings", isDirectory: true)
        try? FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        persistence.debugUseFolder(vault)
        return vault
    }

    /// Empty the transcripts directory and the fixture vault before writing.
    ///
    /// A meeting's filename is built from its start time, and the two meetings dated "today" move
    /// with the clock — so a second launch would write a second copy under a new name rather than
    /// replacing the first, and the library, which reads every file it finds, would show the
    /// screenshot set twice.
    private static func discardPreviousSeed(vault: URL?) {
        let fileManager = FileManager.default
        for directory in [MeetingFileWriter.internalTranscriptDirectory(), vault].compactMap({ $0 }) {
            let contents =
                (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for file in contents {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    // MARK: - The live meeting

    /// Dresses the store as a meeting seven minutes in: capture running, a level on the meter, a
    /// transcript mid-flow and two moments already flagged.
    private static func poseRunningMeeting(in store: MobileMeetingStore) {
        store.meetingTitle = "Onboarding walkthrough with Rae"
        store.meetingNotes =
            "Rae wants the trial to start from an import, not an empty account. Ask design for a "
            + "first-run screen that offers it."

        // -20 dBFS: a room being talked in from a metre away, which lights most of the meter
        // without pinning it.
        store.recorder.debugPoseAsCapturing(level: 0.1)
        store.session.debugPoseAsRunningMeeting(
            startedAt: Date().addingTimeInterval(-444),
            transcript: liveTranscript(),
            keyMoments: [
                KeyMoment(offset: 156, text: "Import-first trial"),
                KeyMoment(offset: 302, text: "Seat pricing question")
            ]
        )
    }

    private static func liveTranscript() -> [TranscriptSegment] {
        turns([
            (
                "A", 236, 251,
                "So the part we keep coming back to is the empty account. People sign up, they land on nothing, and about half of them never come back to it."
            ),
            (
                "B", 252, 268,
                "Right, and the ones who do come back are the ones who imported something in the first session. That's the whole difference in the retention numbers."
            ),
            (
                "A", 269, 281,
                "Then the trial should start from an import. Not offer one somewhere in settings — start from it."
            ),
            (
                "C", 282, 297,
                "We'd need the importer to handle the messy cases before we put it in front of everyone. Right now it gives up on a file with a stray column."
            ),
            (
                "B", 298, 312,
                "How long is that? If it's two weeks I'd rather wait and ship it properly than put a fragile importer on the first screen everyone sees."
            ),
            (
                "A", 313, 328,
                "Let's scope it this week. I'll write it up and we can decide on Thursday whether it goes in this cycle or the next one."
            )
        ])
    }

    // MARK: - The library

    /// Six saved meetings, newest first once the library sorts them. The newest is the richest,
    /// because it is the one the detail, summary and transcript slides open.
    private static func savedMeetings() -> [Meeting] {
        [
            designReview(),
            productSync(),
            oneOnOne(),
            customerCall(),
            sprintPlanning(),
            roadmapCheckIn()
        ]
    }

    private static func designReview() -> Meeting {
        let startedAt = minutesAgo(70)
        return Meeting(
            id: uuid(1),
            title: "Design review — recording sheet",
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(34 * 60),
            transcript: turns([
                (
                    "A", 12, 34,
                    "The thing I want to settle today is what the sheet shows while a meeting is running. At the moment it's a title, a timer and a wall of transcript, and the transcript wins."
                ),
                (
                    "B", 35, 58,
                    "It wins because it moves. Anything that updates four times a minute is going to pull the eye off everything that doesn't."
                ),
                (
                    "A", 59, 76,
                    "So either the transcript gets quieter or the controls get louder. I'd rather the controls got louder — they're the reason the screen is open."
                ),
                (
                    "C", 77, 104,
                    "Can we pin them? Key moment and Stop sitting below the scroll rather than in it. Then it doesn't matter how long the transcript runs, they're always in the same place under your thumb."
                ),
                (
                    "B", 105, 121,
                    "That's the version I'd ship. It also means we stop worrying about where the scroll is when someone needs to stop the meeting."
                ),
                (
                    "A", 122, 148,
                    "Agreed. Pin the bar, keep the transcript scrolling behind it. And the meter goes under the timer rather than beside it — it's the thing people check when they're not sure the phone is hearing them."
                ),
                (
                    "C", 149, 172,
                    "One more: the sheet opens at half height. Do we grow it when the first transcript lands, or leave it where the user put it?"
                ),
                (
                    "A", 173, 196,
                    "Grow it once, on the first turn, and then never again. If it springs back every time someone speaks you can't push it out of the way to look at the list."
                ),
                (
                    "B", 197, 214,
                    "I'll write that up. Half height, promote on the first turn, and after that the detent belongs to whoever is holding the phone."
                ),
                (
                    "A", 215, 232,
                    "Good. Last thing — discard. It's currently next to the key moment button and that's a mistake waiting to happen."
                ),
                (
                    "C", 233, 256,
                    "Move it into the overflow menu behind a confirmation. Stopping saves, discarding throws the whole meeting away, and those two shouldn't sit next to each other."
                ),
                ("A", 257, 274, "Do that. Anything else and we'll pick it up on Thursday.")
            ]),
            keyMoments: [
                KeyMoment(offset: 104, text: "Pin the control bar below the scroll"),
                KeyMoment(offset: 196, text: "Promote the detent once, then leave it alone"),
                KeyMoment(offset: 256, text: "Discard moves behind a confirmation")
            ],
            notes:
                "Rough consensus in the room: the live screen is a control surface first and a\n"
                + "transcript second. Nobody argued for the current layout.\n\n"
                + "Open: whether the meter belongs on the record pill as well, or only in the sheet.",
            summary: MeetingSummary(
                overview:
                    "The team settled the layout of the live recording sheet. Key moment and Stop move "
                    + "into a bar pinned below the scroll so they stay reachable however long the "
                    + "transcript runs, the level meter moves under the timer, and the sheet grows to "
                    + "full height once — on the first transcribed turn — after which its size belongs "
                    + "to the user. Discard moves into an overflow menu behind a confirmation.",
                topics: ["Live recording sheet", "Control placement", "Sheet detents"],
                keyPoints: [
                    "The transcript dominates the screen because it is the only thing that moves.",
                    "Pinning the controls below the scroll makes Stop reachable at any scroll position.",
                    "The level meter answers \"is this thing hearing us?\", so it sits with the timer.",
                    "A sheet that resizes on every turn can't be pushed out of the way."
                ],
                details: [
                    SummaryDetail(
                        title: "Pinning the control bar",
                        narrative:
                            "Key moment and Stop are the reason the sheet is open, so they move out of "
                            + "the scrolling content and into a bar below it. The transcript scrolls "
                            + "behind, and the length of a meeting stops affecting whether the controls "
                            + "can be reached.",
                        timestamps: ["01:44", "02:01"]
                    ),
                    SummaryDetail(
                        title: "Detent promotion",
                        narrative:
                            "The sheet opens at half height and grows once, when the first transcribed "
                            + "turn lands. After that the detent is the user's — springing back on every "
                            + "turn would make it impossible to push the sheet aside and check the list.",
                        timestamps: ["03:16"]
                    )
                ],
                actionItems: [
                    "Write up the pinned control bar and the one-shot detent promotion.",
                    "Move Discard into the overflow menu behind a confirmation.",
                    "Bring the meter-on-the-record-pill question back on Thursday."
                ],
                decisions: [
                    "Key moment and Stop are pinned below the scroll.",
                    "The level meter sits under the elapsed timer, not beside it.",
                    "The sheet promotes to full height once, on the first transcribed turn."
                ],
                openQuestions: [
                    "Does the level meter belong on the floating record pill as well?"
                ],
                followUps: ["Pick the remaining sheet questions up on Thursday."],
                generatedAt: startedAt.addingTimeInterval(35 * 60),
                provider: "anthropic",
                model: "claude-sonnet-4-5",
                promptVersion: "2"
            )
        )
    }

    private static func productSync() -> Meeting {
        let startedAt = minutesAgo(150)
        return Meeting(
            id: uuid(2),
            title: "Weekly product sync",
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(28 * 60),
            transcript: turns([
                (
                    "A", 8, 26,
                    "Quick pass round the board. Import is in review, the settings rewrite is behind by about three days, and search hasn't started."
                ),
                (
                    "B", 27, 48,
                    "Search hasn't started because we still don't know whether it indexes transcripts or only titles and summaries. That's a product call, not an engineering one."
                ),
                (
                    "A", 49, 66,
                    "Transcripts. If it doesn't search what was said it isn't a search feature, it's a filter."
                ),
                (
                    "C", 67, 84,
                    "Then I'd like a week to look at what that does to the index size before we commit to it in this cycle."
                )
            ]),
            keyMoments: [KeyMoment(offset: 66, text: "Search indexes transcripts")],
            notes: "Settings rewrite slipping — check whether that pushes the release.",
            summary: MeetingSummary(
                overview:
                    "Import is in review and the settings rewrite has slipped by roughly three days. "
                    + "Search was unblocked by a product call: it indexes transcript text, not just "
                    + "titles and summaries, with a week set aside first to measure what that does to "
                    + "the index.",
                topics: ["Cycle status", "Search scope"],
                keyPoints: [
                    "Search was blocked on a product decision, not on engineering capacity.",
                    "The settings rewrite is about three days behind."
                ],
                actionItems: [
                    "Measure index size for full transcript search.",
                    "Confirm whether the settings slip moves the release date."
                ],
                decisions: ["Search indexes transcript text."],
                openQuestions: ["Does the settings slip push the release?"],
                generatedAt: startedAt.addingTimeInterval(30 * 60),
                provider: "anthropic",
                model: "claude-sonnet-4-5",
                promptVersion: "2"
            )
        )
    }

    private static func oneOnOne() -> Meeting {
        Meeting(
            id: uuid(3),
            title: "1:1 with Priya",
            startedAt: at(daysAgo: 1, hour: 15, minute: 30),
            endedAt: at(daysAgo: 1, hour: 15, minute: 30).addingTimeInterval(27 * 60),
            transcript: turns([
                (
                    "A", 15, 38,
                    "How did the handover land? You've had the importer for two weeks now and I haven't heard you complain, which either means it's fine or you're being polite."
                ),
                (
                    "B", 39, 62,
                    "It's fine. The parsing is clearer than I expected. What I'd like is a second pair of eyes on the error paths before it ships, because that's where I'm least sure."
                )
            ]),
            keyMoments: [],
            notes: "Priya wants a reviewer on the importer error paths. Ask Sam.",
            summary: MeetingSummary(
                overview:
                    "The importer handover has gone smoothly. Priya asked for a reviewer on the error "
                    + "paths before it ships, which is the part she is least confident in.",
                topics: ["Importer handover"],
                keyPoints: ["Parsing is in good shape; error handling needs review."],
                actionItems: ["Ask Sam to review the importer error paths."],
                decisions: [],
                generatedAt: at(daysAgo: 1, hour: 16, minute: 5),
                provider: "anthropic",
                model: "claude-sonnet-4-5",
                promptVersion: "2"
            )
        )
    }

    private static func customerCall() -> Meeting {
        Meeting(
            id: uuid(4),
            title: "Northwind onboarding call",
            startedAt: at(daysAgo: 1, hour: 10, minute: 15),
            endedAt: at(daysAgo: 1, hour: 10, minute: 15).addingTimeInterval(41 * 60),
            transcript: turns([
                (
                    "A", 22, 48,
                    "Where we've got stuck is the export. Everything else has gone in fine, but our notes have to end up in the same folder the rest of the team already works out of."
                ),
                (
                    "B", 49, 72,
                    "That's a folder you choose once and then forget about. Point it at the shared vault and every meeting lands there as markdown — nothing else to configure."
                ),
                ("A", 73, 91, "Markdown is what we wanted to hear. Half the team is in Obsidian already.")
            ]),
            keyMoments: [KeyMoment(offset: 72, text: "Shared vault is the whole requirement")],
            notes: "Send the vault setup steps and follow up Friday.",
            summary: MeetingSummary(
                overview:
                    "Northwind's only blocker is getting notes into the shared folder their team "
                    + "already works from. Pointing Convene at that vault covers it — half the team is "
                    + "on Obsidian, and markdown was the answer they were hoping for.",
                topics: ["Onboarding", "Vault setup"],
                keyPoints: ["Shared-folder output is the requirement, not an extra."],
                actionItems: ["Send Northwind the vault setup steps.", "Follow up on Friday."],
                decisions: [],
                generatedAt: at(daysAgo: 1, hour: 11, minute: 0),
                provider: "anthropic",
                model: "claude-sonnet-4-5",
                promptVersion: "2"
            )
        )
    }

    private static func sprintPlanning() -> Meeting {
        Meeting(
            id: uuid(5),
            title: "Sprint planning — cycle 12",
            startedAt: at(daysAgo: 2, hour: 14, minute: 0),
            endedAt: at(daysAgo: 2, hour: 14, minute: 0).addingTimeInterval(52 * 60),
            transcript: turns([
                (
                    "A", 30, 54,
                    "Twelve items on the board and room for about eight. So the question isn't what we do, it's what comes off."
                ),
                (
                    "B", 55, 78,
                    "The two smallest are the ones I'd keep — they're both a day and they both unblock someone else. Everything else can be argued about."
                )
            ]),
            keyMoments: [],
            notes: "",
            summary: MeetingSummary(
                overview:
                    "Twelve candidates for a cycle with room for eight. The two smallest items stay "
                    + "because they each unblock someone else; the rest of the cut was argued through "
                    + "item by item.",
                topics: ["Cycle planning"],
                keyPoints: ["Capacity is eight items, not twelve."],
                actionItems: ["Update the board with the agreed cut."],
                decisions: ["Keep the two unblocking items regardless of priority order."],
                generatedAt: at(daysAgo: 2, hour: 15, minute: 0),
                provider: "anthropic",
                model: "claude-sonnet-4-5",
                promptVersion: "2"
            )
        )
    }

    private static func roadmapCheckIn() -> Meeting {
        Meeting(
            id: uuid(6),
            title: "Roadmap check-in",
            startedAt: at(daysAgo: 4, hour: 9, minute: 30),
            endedAt: at(daysAgo: 4, hour: 9, minute: 30).addingTimeInterval(38 * 60),
            transcript: turns([
                (
                    "A", 18, 44,
                    "The half we're confident about is the recording work. The half we're guessing at is everything downstream of it, and that's the half with the dates on it."
                ),
                (
                    "B", 45, 66,
                    "Then take the dates off the second half until the first half ships. A roadmap that's half guesses reads as entirely guesses."
                )
            ]),
            keyMoments: [KeyMoment(offset: 66, text: "Drop dates from the unconfident half")],
            notes: "",
            summary: MeetingSummary(
                overview:
                    "The recording work is well understood; everything downstream of it is not, and "
                    + "that is where the published dates sit. The agreement was to drop dates from the "
                    + "second half until the first half ships.",
                topics: ["Roadmap confidence"],
                keyPoints: ["Dates on guesses undermine the dates on the certain work."],
                actionItems: ["Republish the roadmap without dates past the recording work."],
                decisions: ["No dates on the downstream half until recording ships."],
                generatedAt: at(daysAgo: 4, hour: 10, minute: 15),
                provider: "anthropic",
                model: "claude-sonnet-4-5",
                promptVersion: "2"
            )
        )
    }

    // MARK: - Builders

    /// `(diarization label, start, end, text)` → segments on the single `.others` stream the iPhone
    /// app records, which is what renders them as "Speaker A"/"Speaker B".
    private static func turns(_ raw: [(String, TimeInterval, TimeInterval, String)]) -> [TranscriptSegment] {
        raw.map { label, start, end, text in
            TranscriptSegment(
                speaker: .others,
                startedAt: start,
                endedAt: end,
                text: text,
                isFinal: true,
                diarizedSpeaker: label
            )
        }
    }

    /// A fixed UUID per meeting, so re-seeding overwrites rather than duplicates: the filename stem
    /// is built from the id and the start date, and a screenshot run launches the app more than
    /// once.
    private static func uuid(_ index: Int) -> UUID {
        // Varied in the first block, not the last: `MarkdownRenderer.filenameStem` takes the first
        // eight characters, so six ids differing only in their tail would produce six filenames
        // ending in the same suffix.
        UUID(uuidString: String(format: "C04E4E%02d-0000-4000-8000-000000000000", index))!
    }

    /// Today's meetings, placed relative to now rather than at a fixed clock time — a fixed 11:40
    /// files itself under "Yesterday" for any capture run before lunch, and the list's first
    /// heading is the one that has to say "Today".
    private static func minutesAgo(_ minutes: Int) -> Date {
        let seconds = Date().timeIntervalSince1970 - Double(minutes * 60)
        // Snapped to five minutes, so the chip reads "9:05 am" rather than "9:03 am".
        return Date(timeIntervalSince1970: (seconds / 300).rounded(.down) * 300)
    }

    /// A wall-clock time on an earlier day. Always in the past, so no rollback is needed.
    private static func at(daysAgo: Int, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date()))!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}
#endif
