import Foundation

@MainActor
final class ClaudeSummaryService: ObservableObject {
    @Published private(set) var isGenerating: Bool = false
    @Published private(set) var lastError: String?

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func generate(meeting: Meeting, apiKey: String, model: String = "claude-haiku-4-5-20251001") async -> MeetingSummary? {
        guard !apiKey.isEmpty else {
            lastError = "Claude API key required"
            return nil
        }
        guard !meeting.transcript.isEmpty || !meeting.notes.isEmpty else {
            lastError = "Nothing to summarize"
            return nil
        }

        isGenerating = true
        lastError = nil
        defer { isGenerating = false }

        let body = requestBody(meeting: meeting, model: model)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            lastError = "Could not encode request: \(error.localizedDescription)"
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = "Invalid HTTP response"
                return nil
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let serverMessage = parseServerError(data: data) ?? "HTTP \(httpResponse.statusCode)"
                lastError = serverMessage
                logError("ClaudeSummaryService: \(serverMessage)")
                return nil
            }
            return parseSummary(data: data)
        } catch {
            lastError = "Network error: \(error.localizedDescription)"
            logError("ClaudeSummaryService: network error: \(error.localizedDescription)")
            return nil
        }
    }

    private func requestBody(meeting: Meeting, model: String) -> [String: Any] {
        let formattedTranscript = meeting.transcript
            .filter { !$0.text.isEmpty }
            .map { segment -> String in
                let mm = Int(segment.startedAt) / 60
                let ss = Int(segment.startedAt) % 60
                return String(format: "%@ [%02d:%02d]: %@", segment.speaker.displayName, mm, ss, segment.text)
            }
            .joined(separator: "\n")

        let userPrompt = """
        Title: \(meeting.title)

        Notes (typed by the participant during the meeting):
        \(meeting.notes.isEmpty ? "(none)" : meeting.notes)

        Transcript (You = the participant, Others = the remote side of the call):
        \(formattedTranscript.isEmpty ? "(no transcript captured)" : formattedTranscript)

        Respond with a JSON object containing: overview (string), keyPoints (array of strings), decisions (array of strings), actionItems (array of strings). No other text.
        """

        let systemPrompt = """
        You analyze meeting transcripts and produce concise structured summaries as JSON.
        Be specific: use names, numbers, and exact phrasing from the transcript and notes.
        Don't invent decisions or action items that aren't in the source material.
        Action items should include the assignee when mentioned (e.g. "Matt: send the contract").
        Respond with only valid JSON, no markdown fences or explanation.
        """

        return [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]
    }

    private func parseServerError(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else { return nil }
        return "Claude summary failed: \(message)"
    }

    private struct SummaryPayload: Decodable {
        let overview: String
        let keyPoints: [String]
        let decisions: [String]
        let actionItems: [String]
    }

    private func parseSummary(data: Data) -> MeetingSummary? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            lastError = "Could not parse Claude response"
            return nil
        }
        guard let textData = text.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(SummaryPayload.self, from: textData) else {
            lastError = "Claude response was not valid JSON"
            return nil
        }
        return MeetingSummary(
            overview: parsed.overview,
            keyPoints: parsed.keyPoints,
            actionItems: parsed.actionItems,
            decisions: parsed.decisions,
            generatedAt: Date()
        )
    }
}
