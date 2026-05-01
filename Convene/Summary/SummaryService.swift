import Foundation

/// Posts the transcript + notes to OpenAI Chat Completions with a JSON-schema response format
/// to produce a structured `MeetingSummary`.
@MainActor
final class SummaryService: ObservableObject {
    @Published private(set) var isGenerating: Bool = false
    @Published private(set) var lastError: String?

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    private struct SummaryPayload: Decodable {
        let overview: String
        let keyPoints: [String]
        let decisions: [String]
        let actionItems: [String]
    }

    /// Returns a `MeetingSummary` or nil on failure (`lastError` populated).
    func generate(meeting: Meeting, apiKey: String, model: String) async -> MeetingSummary? {
        guard !apiKey.isEmpty else {
            lastError = "API key required"
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
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
                logError("SummaryService: \(serverMessage)")
                return nil
            }
            return parseSummary(data: data)
        } catch {
            lastError = "Network error: \(error.localizedDescription)"
            logError("SummaryService: network error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Request

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
        """

        let systemPrompt = """
        You analyze meeting transcripts and produce concise structured summaries.
        Be specific: use names, numbers, and exact phrasing from the transcript and notes.
        Don't invent decisions or action items that aren't in the source material.
        Action items should include the assignee when mentioned (e.g. "Matt: send the contract").
        """

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["overview", "keyPoints", "decisions", "actionItems"],
            "properties": [
                "overview": [
                    "type": "string",
                    "description": "A one or two paragraph summary of what happened in the meeting."
                ] as [String: Any],
                "keyPoints": [
                    "type": "array",
                    "items": ["type": "string"]
                ] as [String: Any],
                "decisions": [
                    "type": "array",
                    "items": ["type": "string"]
                ] as [String: Any],
                "actionItems": [
                    "type": "array",
                    "items": ["type": "string"]
                ] as [String: Any]
            ]
        ]

        return [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "MeetingSummary",
                    "strict": true,
                    "schema": schema
                ] as [String: Any]
            ] as [String: Any],
            "temperature": 0.2
        ]
    }

    // MARK: - Response

    private func parseServerError(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            let code = error["code"] as? String
            return OpenAIErrorFormatter.userMessage(code: code, message: message, operation: "Summary")
        }
        return nil
    }

    private func parseSummary(data: Data) -> MeetingSummary? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            lastError = "Could not parse response JSON"
            return nil
        }
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            lastError = "Response missing expected choices/message/content"
            return nil
        }
        guard let contentData = content.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(SummaryPayload.self, from: contentData) else {
            lastError = "Summary content was not valid JSON"
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
