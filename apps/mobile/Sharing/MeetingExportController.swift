import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A single action coordinator prevents double taps from opening competing share sheets and gives
/// clipboard actions the same immediate, accessible confirmation in both reading surfaces.
@MainActor
final class MeetingExportController: ObservableObject {
    @Published private(set) var isPreparing = false
    @Published private(set) var feedback: String?
    @Published var errorMessage: String?
    @Published var sharedFile: PreparedTextExport?

    private let pasteboard: UIPasteboard
    private let prepareFile: (Meeting) throws -> PreparedTextExport
    private var feedbackTask: Task<Void, Never>?
    private var activeFile: PreparedTextExport?

    init(
        pasteboard: UIPasteboard = .general,
        prepareFile: @escaping (Meeting) throws -> PreparedTextExport = {
            try PreparedTextExport(meeting: $0)
        }
    ) {
        self.pasteboard = pasteboard
        self.prepareFile = prepareFile
    }

    func copyMarkdown(_ meeting: Meeting) {
        copy(MarkdownRenderer.renderMarkdown(meeting), confirmation: "Markdown copied")
    }

    func copyTranscript(_ meeting: Meeting) {
        copy(MeetingTextExport.transcript(meeting), confirmation: "Transcript copied")
    }

    private func copy(_ text: String, confirmation: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "There’s no transcript to copy yet."
            return
        }
        // Publish a standard UTF-8 text representation so Notes, editors and other paste targets
        // receive the actual Markdown source (or transcript), never an attributed preview.
        pasteboard.setItems([[UTType.utf8PlainText.identifier: text]])
        feedbackTask?.cancel()
        feedback = confirmation
        UIAccessibility.post(notification: .announcement, argument: confirmation)
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.feedback = nil
        }
    }

    func share(_ meeting: Meeting) {
        guard !isPreparing, activeFile == nil else { return }
        errorMessage = nil
        isPreparing = true
        defer { isPreparing = false }
        do {
            let file = try prepareFile(meeting)
            activeFile = file
            sharedFile = file
        } catch {
            errorMessage = "The text file couldn’t be prepared. Try again. \(error.localizedDescription)"
        }
    }

    func finishSharing(id: UUID, error: Error? = nil) {
        guard activeFile?.id == id else { return }
        // Keep the URL alive until the system activity has finished or the sheet is dismissed.
        sharedFile = nil
        if let error { errorMessage = "Sharing failed. \(error.localizedDescription)" }
    }

    func dismissShare() {
        // Release our ownership. UIKit's item source can still retain the export while an
        // extension finishes reading, so only the export's final deinit removes its directory.
        activeFile = nil
        sharedFile = nil
    }
}

struct TextFileShareSheet: UIViewControllerRepresentable {
    let file: PreparedTextExport
    let completion: (Error?) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [TextFileActivityItem(file: file)], applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, error in completion(error) }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private final class TextFileActivityItem: NSObject, UIActivityItemSource {
    // Retain ownership for as long as UIKit can request the file, including a share extension.
    private let file: PreparedTextExport
    init(file: PreparedTextExport) { self.file = file }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        file.url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? { file.url }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String { UTType.plainText.identifier }
}

struct ExportFeedback: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .padding()
                .allowsHitTesting(false)
                .accessibilityIdentifier("exportFeedback")
        }
    }
}
