import Foundation

/// Builds the AssemblyAI streaming `keyterms_prompt` list from meeting context.
/// The API accepts at most 100 terms, each at most 50 characters.
enum KeytermsBuilder {
    private static let maxTerms = 100
    private static let maxTermLength = 50

    /// Lowercased English words too generic to bias transcription toward.
    private static let stopwords: Set<String> = [
        "with", "from", "this", "that", "meeting", "call", "sync",
        "weekly", "monthly", "catch", "catchup", "chat", "team",
        "and", "the", "for", "about", "into", "over", "your", "our",
        "daily", "review", "standup", "check", "discussion"
    ]

    /// Builds a deduped keyterm list: attendee display names first, then title
    /// words of length >= 4 that aren't stopwords or pure numbers/dates.
    static func build(attendees: [String], title: String) -> [String] {
        var candidates: [String] = []

        for attendee in attendees {
            candidates.append(TranscriptFormatter.attendeeDisplayName(attendee))
        }

        let words = title.components(
            separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'’")).inverted
        )
        for word in words {
            guard word.count >= 4 else { continue }
            guard !stopwords.contains(word.lowercased()) else { continue }
            guard !isNumericOrDate(word) else { continue }
            candidates.append(word)
        }

        var seen = Set<String>()
        var result: [String] = []
        for candidate in candidates {
            let term = String(
                candidate.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxTermLength)
            )
            guard !term.isEmpty else { continue }
            guard seen.insert(term.lowercased()).inserted else { continue }
            result.append(term)
            if result.count == maxTerms { break }
        }
        return result
    }

    /// True for terms made entirely of digits and date punctuation ("2026", "10/06/2026").
    private static func isNumericOrDate(_ word: String) -> Bool {
        let dateCharacters = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "/-.:"))
        return word.unicodeScalars.allSatisfy(dateCharacters.contains)
    }
}
