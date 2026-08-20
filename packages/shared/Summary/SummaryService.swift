import Foundation

@MainActor
final class SummaryService: ObservableObject {
    @Published private(set) var isGenerating: Bool = false
    @Published private(set) var lastError: String?

    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    private struct SummaryPayload: Decodable {
        let overview: String
        let topics: [String]
        let keyPoints: [String]
        let details: [SummaryDetail]?
        let decisions: [String]
        let actionItems: [String]
        let openQuestions: [String]
        let followUps: [String]
    }

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
            let (data, response) = try await sendWithRetry(request)
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
        [
            "model": model,
            "store": false,
            "instructions": SummaryPrompt.systemPrompt,
            "input": SummaryPrompt.userPrompt(meeting: meeting),
            "max_output_tokens": 4000,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "MeetingSummary",
                    "strict": true,
                    "schema": SummaryPrompt.jsonSchema
                ] as [String: Any]
            ] as [String: Any]
        ]
    }

    // MARK: - Response

    private func sendWithRetry(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var lastResult: (Data, URLResponse)?

        for attempt in 0..<3 {
            let result = try await URLSession.shared.data(for: request)
            lastResult = result

            guard let httpResponse = result.1 as? HTTPURLResponse,
                isRetryable(statusCode: httpResponse.statusCode),
                attempt < 2
            else {
                return result
            }

            let baseDelay = pow(2.0, Double(attempt)) * 0.5
            let jitter = Double.random(in: 0...0.25)
            try await Task.sleep(nanoseconds: UInt64((baseDelay + jitter) * 1_000_000_000))
        }

        guard let lastResult else {
            throw URLError(.unknown)
        }
        return lastResult
    }

    private func isRetryable(statusCode: Int) -> Bool {
        statusCode == 429 || statusCode == 500 || statusCode == 502 || statusCode == 503 || statusCode == 504
    }

    private func parseServerError(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            let code = error["code"] as? String
            return SummaryService.userMessage(code: code, message: message, operation: "Summary")
        }
        return nil
    }

    private func parseSummary(data: Data) -> MeetingSummary? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            lastError = "Could not parse response JSON"
            return nil
        }
        guard let content = responseText(from: json),
            let contentData = content.data(using: .utf8),
            let parsed = try? JSONDecoder().decode(SummaryPayload.self, from: contentData)
        else {
            lastError = "Summary content was not valid JSON"
            return nil
        }
        return MeetingSummary(
            overview: parsed.overview,
            topics: parsed.topics,
            keyPoints: parsed.keyPoints,
            details: parsed.details ?? [],
            actionItems: parsed.actionItems,
            decisions: parsed.decisions,
            openQuestions: parsed.openQuestions,
            followUps: parsed.followUps,
            generatedAt: Date(),
            provider: "openai",
            model: json["model"] as? String,
            promptVersion: SummaryPrompt.version
        )
    }

    private func responseText(from json: [String: Any]) -> String? {
        if let text = json["output_text"] as? String {
            return text
        }

        guard let output = json["output"] as? [[String: Any]] else {
            return nil
        }

        for item in output {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            for contentItem in content {
                if let text = contentItem["text"] as? String {
                    return text
                }
            }
        }

        return nil
    }

    static func userMessage(code: String?, message: String, operation: String) -> String {
        let normalizedCode = code?.lowercased()
        let normalizedMessage = message.lowercased()

        if normalizedCode == "insufficient_quota" || normalizedMessage.contains("insufficient quota") {
            return "\(operation) could not run because this OpenAI project has no usable quota."
        }
        if normalizedCode == "invalid_api_key" || normalizedCode == "incorrect_api_key"
            || normalizedMessage.contains("invalid api key")
            || normalizedMessage.contains("incorrect api key")
        {
            return "\(operation) could not run because the API key was rejected. Update the key in Settings."
        }
        if normalizedCode == "rate_limit_exceeded" || normalizedMessage.contains("rate limit") {
            return "\(operation) hit a rate limit. Wait a moment, then retry."
        }
        if normalizedCode == "model_not_found"
            || (normalizedMessage.contains("model") && normalizedMessage.contains("not found"))
        {
            return "\(operation) could not run because the selected model is unavailable."
        }
        return "\(operation) failed: \(message)"
    }
}
