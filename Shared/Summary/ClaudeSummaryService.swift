import Foundation

@MainActor
final class ClaudeSummaryService: ObservableObject {
    @Published private(set) var isGenerating: Bool = false
    @Published private(set) var lastError: String?

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func generate(meeting: Meeting, apiKey: String, model: String = "claude-fable-5") async -> MeetingSummary? {
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

    /// Transport-only request body. Note: `claude-fable-5` and `claude-opus-4-8` reject
    /// `temperature`/`top_p`/`top_k` and any `thinking` parameter — never add them here.
    private func requestBody(meeting: Meeting, model: String) -> [String: Any] {
        let userPrompt = SummaryPrompt.userPrompt(meeting: meeting) + "\n\n" + SummaryPrompt.claudeUserSuffix
        let systemPrompt = SummaryPrompt.systemPrompt + "\n" + SummaryPrompt.claudeSystemSuffix

        return [
            "model": model,
            "max_tokens": 8192,
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
        let topics: [String]?
        let keyPoints: [String]?
        let details: [SummaryDetail]?
        let decisions: [String]?
        let actionItems: [String]?
        let openQuestions: [String]?
        let followUps: [String]?
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
            topics: parsed.topics ?? [],
            keyPoints: parsed.keyPoints ?? [],
            details: parsed.details ?? [],
            actionItems: parsed.actionItems ?? [],
            decisions: parsed.decisions ?? [],
            openQuestions: parsed.openQuestions ?? [],
            followUps: parsed.followUps ?? [],
            generatedAt: Date(),
            provider: "anthropic",
            model: json["model"] as? String,
            promptVersion: SummaryPrompt.version
        )
    }
}
