import Foundation

enum OpenAIErrorFormatter {
    static func userMessage(code: String?, message: String, operation: String) -> String {
        let normalizedCode = code?.lowercased()
        let normalizedMessage = message.lowercased()

        if normalizedCode == "insufficient_quota" || normalizedMessage.contains("insufficient quota") {
            return "\(operation) could not run because this OpenAI project has no usable quota. Check billing or project limits, then retry."
        }

        if normalizedCode == "invalid_api_key"
            || normalizedCode == "incorrect_api_key"
            || normalizedMessage.contains("invalid api key")
            || normalizedMessage.contains("incorrect api key") {
            return "\(operation) could not run because the OpenAI API key was rejected. Update the key in Settings."
        }

        if normalizedCode == "rate_limit_exceeded" || normalizedMessage.contains("rate limit") {
            return "\(operation) hit an OpenAI rate limit. Wait a moment, then retry."
        }

        if normalizedCode == "model_not_found" || normalizedMessage.contains("model") && normalizedMessage.contains("not found") {
            return "\(operation) could not run because the selected OpenAI model is unavailable for this key or project."
        }

        return "\(operation) failed: \(message)"
    }
}
