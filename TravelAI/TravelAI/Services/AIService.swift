import Foundation

struct AIServiceConfig {
    var provider: String    // openai / claude / deepseek
    var baseURL: String     // Supabase Edge Function URL
    var authToken: String   // Supabase anon key
}

enum AIService {
    static var config: AIServiceConfig = AIServiceConfig(
        provider: "openai",
        baseURL: "https://<your-project>.supabase.co/functions/v1",
        authToken: "<your-anon-key>"
    )

    // MARK: - Generate full trip itinerary
    static func generateTrip(
        destination: String,
        startDate: Date,
        endDate: Date,
        style: String = "cultural"
    ) async throws -> String {
        let formatter = ISO8601DateFormatter()
        let body: [String: Any] = [
            "action": "generate_trip",
            "destination": destination,
            "startDate": formatter.string(from: startDate),
            "endDate": formatter.string(from: endDate),
            "style": style,
            "provider": config.provider
        ]
        return try await post(endpoint: "/travel-ai", body: body)
    }

    // MARK: - Chat
    static func chat(
        messages: [[String: String]],
        tripContext: String
    ) async throws -> String {
        let body: [String: Any] = [
            "action": "chat",
            "messages": messages,
            "tripContext": tripContext,
            "provider": config.provider
        ]
        return try await post(endpoint: "/travel-ai", body: body)
    }

    // MARK: - Internal POST
    private static func post(endpoint: String, body: [String: Any]) async throws -> String {
        guard let url = URL(string: config.baseURL + endpoint) else {
            throw AIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.serverError
        }
        guard let result = String(data: data, encoding: .utf8) else {
            throw AIError.invalidResponse
        }
        return result
    }

    enum AIError: Error, LocalizedError {
        case invalidURL
        case serverError
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "服务地址配置错误"
            case .serverError: return "AI 服务暂时不可用，请稍后重试"
            case .invalidResponse: return "返回数据格式错误"
            }
        }
    }
}
