import Foundation

enum AIService {
    private static var apiKey: String {
        let stored = UserDefaults.standard.string(forKey: "travelai.apiKey") ?? ""
        if stored.isEmpty {
            let fallback = "sk-cp-UeAsUVnn0oFByLJjHCI3bUFLU4_t69n3nqvRshLiY1BePgzxNVUI2ThqZmgfSzha1SMVnWJjwP91SJ1Cnbtbtse5mq3BZPGnm2LQGlrR_5DWT7zpuLoLsKA"
            UserDefaults.standard.set(fallback, forKey: "travelai.apiKey")
            return fallback
        }
        return stored
    }
    private static var baseURL: String {
        UserDefaults.standard.string(forKey: "travelai.baseURL")
            ?? "https://api.minimax.chat/v1/text/chatcompletion_v2"
    }
    private static var model: String {
        UserDefaults.standard.string(forKey: "travelai.model") ?? "MiniMax-M1"
    }

    // MARK: - Generate full trip itinerary
    static func generateTrip(
        destination: String,
        startDate: Date,
        endDate: Date,
        style: String? = nil
    ) async throws -> String {
        let resolvedStyle = style
            ?? UserDefaults.standard.string(forKey: "travelai.defaultStyle")
            ?? "cultural"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)

        let prompt = """
        你是一位专业旅游规划师。请为以下旅行生成完整的攻略，只返回JSON，不要有任何额外文字或markdown代码块。

        目的地：\(destination)
        出发日期：\(startStr)
        返回日期：\(endStr)
        旅行风格：\(resolvedStyle)

        JSON格式：
        {
          "destination": "目的地名称（英文）",
          "dateRange": { "start": "YYYY-MM-DD", "end": "YYYY-MM-DD" },
          "itinerary": [
            {
              "day": 1,
              "date": "YYYY-MM-DD",
              "title": "城市A → 城市B",
              "events": [
                {
                  "time": "HH:MM",
                  "title": "活动名称",
                  "description": "简短说明",
                  "location": { "name": "地点名称", "lat": 纬度, "lng": 经度 },
                  "type": "transport|attraction|food|accommodation"
                }
              ]
            }
          ],
          "checklist": [
            { "id": "1", "title": "待办事项", "completed": false, "dayIndex": null }
          ],
          "culture": {
            "type": "mythology_tree|dynasty_tree|general",
            "title": "知识图谱标题",
            "nodes": [
              { "id": "唯一id", "name": "名称", "subtitle": "副标题", "description": "描述（100字内）", "emoji": "emoji", "parentId": null }
            ]
          },
          "tips": ["贴士1", "贴士2"],
          "sos": [
            { "title": "机构名称", "phone": "电话", "subtitle": "说明", "emoji": "emoji" }
          ]
        }

        要求：每个景点有真实GPS坐标，文化图谱至少8个节点有父子层级，SOS包含中国大使馆电话，checklist 5-8项，tips 5-8条。
        """

        let messages: [[String: String]] = [
            ["role": "user", "content": prompt]
        ]
        let raw = try await post(messages: messages)
        return try extractContent(from: raw)
    }

    // MARK: - Chat
    static func chat(
        messages: [[String: String]],
        tripContext: String
    ) async throws -> String {
        var fullMessages: [[String: String]] = [
            ["role": "system", "content": "你是专业旅游助手。当前行程背景：\(tripContext)。请用中文简洁回答，控制在200字以内。"]
        ]
        fullMessages.append(contentsOf: messages)
        let raw = try await post(messages: fullMessages)
        return try extractContent(from: raw)
    }

    // MARK: - Internal POST
    private static func post(messages: [[String: String]]) async throws -> Data {
        guard let url = URL(string: baseURL) else {
            throw AIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 8192,
            "temperature": 0.7
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.serverError
        }
        guard http.statusCode == 200 else {
            let errMsg = String(data: data, encoding: .utf8) ?? "unknown"
            print("[AIService] HTTP \(http.statusCode): \(errMsg)")
            throw AIError.serverError
        }
        return data
    }

    // MARK: - Extract content from OpenAI-compatible response
    private static func extractContent(from data: Data) throws -> String {
        let rawString = String(data: data, encoding: .utf8) ?? "(unreadable)"
        print("[AIService] Raw response: \(rawString)")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw AIError.invalidResponse
        }
        // Strip markdown code fences if present
        let cleaned = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }

    // MARK: - Errors
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
