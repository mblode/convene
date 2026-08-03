import SwiftUI

/// The full transcript, one tap off the note.
///
/// A transcript is the longest thing in the app and the least often read. Inline it pushed the
/// summary, the user's own notes and every flagged moment above the fold, so the note read as a
/// dump with a preamble. Behind a chip it stays a scroll away and the note reads as a note.
struct TranscriptSheet: View {
    let meeting: Meeting

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                TranscriptView(
                    segments: meeting.transcript,
                    selfName: meeting.selfName,
                    othersName: meeting.othersName
                )
                .padding(MobileTheme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.appBackground)
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
