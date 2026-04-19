import Foundation

// MARK: - 实时日志（供 UI 展示）
@Observable
final class AILogger {
    static let shared = AILogger()
    private init() {}

    var entries: [Entry] = []

    struct Entry: Identifiable {
        let id = UUID()
        let time: Date
        let text: String
        var isError: Bool = false
    }

    func log(_ msg: String, error: Bool = false) {
        let e = Entry(time: Date(), text: msg, isError: error)
        Task { @MainActor in
            entries.append(e)
            if entries.count > 80 { entries.removeFirst() }
        }
        print("[AIService] \(msg)")
    }

    func clear() {
        Task { @MainActor in entries.removeAll() }
    }
}

enum AIProvider: String {
    case minimax = "minimax"
    case gemini = "gemini"
    case claude = "claude"
}

enum AIService {

    // MARK: - Config
    private static var provider: AIProvider {
        let raw = UserDefaults.standard.string(forKey: "travelai.provider") ?? "minimax"
        return AIProvider(rawValue: raw) ?? .minimax
    }
    private static var minimaxKey: String {
        // App 启动时已在 TravelAIApp.init 预填，正常不会为空
        return UserDefaults.standard.string(forKey: "travelai.apiKey") ?? ""
    }
    private static let geminiKeyValue = "GEMINI_API_KEY_PLACEHOLDER"
    private static var geminiKey: String {
        let stored = UserDefaults.standard.string(forKey: "travelai.geminiKey") ?? ""
        return stored.isEmpty ? geminiKeyValue : stored
    }
    // Claude via newcli proxy
    private static let claudeKey   = "CLAUDE_API_KEY_PLACEHOLDER"
    private static let claudeBase  = "https://code.newcli.com/claude/v1/messages"
    private static let claudeModel = "claude-haiku-4-5"

    private static var minimaxModel: String {
        let stored = UserDefaults.standard.string(forKey: "travelai.model") ?? ""
        return stored.isEmpty ? "MiniMax-M2.5-highspeed" : stored
    }
    private static let geminiModel = "gemini-2.5-flash"

    // MARK: - Geocode（用 AI 获取坐标，适用于内置坐标表没有覆盖的目的地）
    /// 返回 (lat, lon)，失败返回 nil。
    static func geocode(_ destination: String) async -> (Double, Double)? {
        // 提示词：不让模型思考，直接输出数字，避免 <think> 截断 JSON
        let prompt = "地点：\(destination)\n请直接输出该地点的WGS84经纬度，格式：{\"lat\":纬度,\"lon\":经度}，只输出这一行JSON，数字用小数，不要任何解释。"
        let system = "你是地理坐标数据库。收到地点名称后，只输出一行JSON：{\"lat\":纬度数字,\"lon\":经度数字}。不输出任何其他内容，不输出思考过程。"
        do {
            let raw: String
            switch provider {
            case .minimax:
                let messages: [[String: Any]] = [
                    ["role": "system", "content": system],
                    ["role": "user",   "content": prompt]
                ]
                // max_tokens 需足够让思维链（<think>）完成后输出 JSON
                guard let url = URL(string: "https://api.minimaxi.com/v1/chat/completions") else { return nil }
                var req = URLRequest(url: url, timeoutInterval: 20)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer \(minimaxKey)", forHTTPHeaderField: "Authorization")
                let body: [String: Any] = [
                    "model": "MiniMax-M2.5-highspeed",
                    "messages": messages,
                    "max_tokens": 600,
                    "temperature": 0
                ]
                req.httpBody = try? JSONSerialization.data(withJSONObject: body)
                let (data, _) = try await session.data(for: req)
                guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = j["choices"] as? [[String: Any]],
                      let text = choices.first?["message"] as? [String: Any],
                      let content = text["content"] as? String else { return nil }
                raw = content
            case .gemini:
                let data = try await postGemini(system: system, user: prompt)
                raw = try extractGemini(from: data)
            case .claude:
                let data = try await postClaude(system: system, user: prompt)
                raw = try extractClaude(from: data)
            }
            // 解析 {"lat":..., "lon":...}
            let cleaned = cleanJSON(raw)
            guard let jsonData = cleaned.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let lat = (obj["lat"] as? Double) ?? Double("\(obj["lat"] ?? "")"),
                  let lon = (obj["lon"] as? Double) ?? Double("\(obj["lon"] ?? "")"),
                  lat != 0 || lon != 0,
                  lat >= -90, lat <= 90,
                  lon >= -180, lon <= 180
            else {
                AILogger.shared.log("geocode AI parse fail for '\(destination)': \(raw.prefix(60))")
                return nil
            }
            AILogger.shared.log("geocode AI ok '\(destination)': \(String(format:"%.3f",lat)),\(String(format:"%.3f",lon))")
            return (lat, lon)
        } catch {
            AILogger.shared.log("geocode AI error '\(destination)': \(error.localizedDescription)")
            return nil
        }
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
        let endStr   = formatter.string(from: endDate)

        // 计算天数，生成对应的日期列表
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 3
        var dateStrs: [String] = []
        for i in 0..<max(days, 1) {
            let d = calendar.date(byAdding: .day, value: i, to: startDate) ?? startDate
            dateStrs.append(formatter.string(from: d))
        }

        // 生成行程 JSON 模板（直接给结构让模型填值，减少 thinking）
        var itineraryTemplate = ""
        for (i, dateStr) in dateStrs.enumerated() {
            if i > 0 { itineraryTemplate += "," }
            itineraryTemplate += """
            {"day":\(i+1),"date":"\(dateStr)","title":"第\(i+1)天主题","events":[{"time":"09:00","title":"景点1","description":"简介","location":{"name":"地点","lat":0.0,"lng":0.0},"type":"attraction"},{"time":"14:00","title":"景点2","description":"简介","location":{"name":"地点","lat":0.0,"lng":0.0},"type":"attraction"},{"time":"19:00","title":"餐厅","description":"简介","location":{"name":"地点","lat":0.0,"lng":0.0},"type":"food"}]}
            """
        }

        let prompt = """
        只输出JSON，无其他文字。将下面模板中的占位内容替换为\(destination)（\(resolvedStyle)风格）的真实内容，保持JSON结构不变：

        {"destination":"\(destination)英文名","dateRange":{"start":"\(startStr)","end":"\(endStr)"},"itinerary":[\(itineraryTemplate)],"checklist":[{"id":"c1","title":"行前事项1","completed":false,"dayIndex":null},{"id":"c2","title":"行前事项2","completed":false,"dayIndex":null},{"id":"c3","title":"行前事项3","completed":false,"dayIndex":null}],"culture":{"type":"general","title":"\(destination)文化","nodes":[{"id":"n1","name":"文化节点1","subtitle":"副标题","description":"20字内描述","emoji":"🏛️","parentId":null},{"id":"n2","name":"文化节点2","subtitle":"副标题","description":"20字内描述","emoji":"🎭","parentId":"n1"},{"id":"n3","name":"文化节点3","subtitle":"副标题","description":"20字内描述","emoji":"🍜","parentId":null},{"id":"n4","name":"文化节点4","subtitle":"副标题","description":"20字内描述","emoji":"🎪","parentId":"n3"}]},"tips":["实用贴士1","实用贴士2","实用贴士3"],"sos":[{"title":"当地急救","phone":"急救电话","subtitle":"医疗急救","emoji":"🏥"},{"title":"当地报警","phone":"报警电话","subtitle":"警察","emoji":"👮"}]}

        要求：每个景点必须有真实GPS坐标（lat/lng）。
        """

        let system = "只输出合法JSON，无任何额外文字。"
        AILogger.shared.clear()
        AILogger.shared.log("开始生成：\(destination) \(days)天")
        return try await callWithRetry(system: system, user: prompt, maxRetries: 1)
    }

    // MARK: - Call with retry
    private static func callWithRetry(system: String, user: String, maxRetries: Int = 1) async throws -> String {
        var lastError: Error = AIError.invalidResponse
        for attempt in 1...maxRetries {
            do {
                let result = try await call(system: system, user: user)
                // extractMiniMax/extractGemini 已经清洗了 JSON，直接返回
                // 只做基本的非空检验，不重复完整 JSONSerialization 验证（避免 emoji/unicode 边缘问题）
                guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      result.contains("{") else {
                    let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                    try? result.write(to: docDir!.appendingPathComponent("validation_failed_\(attempt).json"), atomically: true, encoding: .utf8)
                    AILogger.shared.log("✗ attempt \(attempt): 结果为空或无JSON结构 len=\(result.count)", error: true)
                    lastError = AIError.invalidResponse
                    continue
                }
                AILogger.shared.log("✓ 返回结果有效 len=\(result.count)")
                return result
            } catch {
                AILogger.shared.log("✗ attempt \(attempt): \(error.localizedDescription)", error: true)
                lastError = error
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        throw lastError
    }

    // MARK: - Chat
    static func chat(
        messages: [[String: String]],
        tripContext: String
    ) async throws -> String {
        let system = """
        你是专业旅游助手。当前行程背景：\(tripContext)。

        【重要规则】
        当用户要求修改行程（如增加景点、删除活动、调整时间、修改某天内容）时，你必须返回如下 JSON 格式，不要加任何多余文字：
        {
          "type": "patch",
          "message": "已为你更新行程：[简短说明]",
          "patch": {
            "addEvents": [
              { "dayIndex": 0, "time": "14:00", "title": "活动名", "description": "说明", "locationName": "地点", "lat": 纬度, "lng": 经度, "type": "attraction" }
            ],
            "removeEvents": [
              { "dayIndex": 0, "eventTitle": "要删除的活动名" }
            ],
            "updateEvents": [
              { "dayIndex": 0, "eventTitle": "原活动名", "newTime": "15:00", "newTitle": "新名称", "newDescription": "新说明" }
            ],
            "updateDayTitle": [
              { "dayIndex": 0, "newTitle": "新的一天标题" }
            ],
            "addChecklist": [
              { "title": "新待办事项", "dayIndex": null }
            ]
          }
        }

        不需要修改行程时，返回如下格式（普通回复）：
        {
          "type": "message",
          "message": "你的回答内容（中文，200字以内）",
          "patch": null
        }

        dayIndex 从 0 开始计数。lat/lng 如不确定可省略。type 只能是 transport/attraction/food/accommodation 之一。
        """
        // Use last user message for Gemini simplicity; full history for MiniMax
        switch provider {
        case .minimax:
            var full: [[String: Any]] = [["role": "system", "content": system]]
            full.append(contentsOf: messages.map { $0 as [String: Any] })
            let raw = try await postMiniMax(messages: full)
            return try extractMiniMax(from: raw)
        case .gemini:
            let userText = messages.last?["content"] ?? ""
            let raw = try await postGemini(system: system, user: userText)
            return try extractGemini(from: raw)
        case .claude:
            let userText = messages.last?["content"] ?? ""
            let raw = try await postClaude(system: system, user: userText)
            return try extractClaude(from: raw)
        }
    }

    // MARK: - Unified call
    private static func call(system: String, user: String) async throws -> String {
        AILogger.shared.log("provider=\(provider.rawValue) model=\(minimaxModel)")
        switch provider {
        case .minimax:
            let messages: [[String: Any]] = [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
            let raw = try await postMiniMax(messages: messages)
            return try extractMiniMax(from: raw)
        case .gemini:
            let raw = try await postGemini(system: system, user: user)
            return try extractGemini(from: raw)
        case .claude:
            let raw = try await postClaude(system: system, user: user)
            return try extractClaude(from: raw)
        }
    }

    // MARK: - MiniMax POST
    private static func postMiniMax(messages: [[String: Any]]) async throws -> Data {
        let url = "https://api.minimaxi.com/v1/chat/completions"
        AILogger.shared.log("→ POST \(url)")
        AILogger.shared.log("  model=\(minimaxModel) max_tokens=16000")
        guard let requestURL = URL(string: url) else { throw AIError.invalidURL }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(minimaxKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300
        let body: [String: Any] = [
            "model": minimaxModel,
            "messages": messages,
            "max_tokens": 16000,
            "temperature": 0.7
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await execute(request: request)
    }

    // MARK: - Gemini POST
    private static func postGemini(system: String, user: String) async throws -> Data {
        let key = geminiKey
        let url = "https://generativelanguage.googleapis.com/v1beta/models/\(geminiModel):generateContent?key=\(key)"
        AILogger.shared.log("→ POST Gemini model=\(geminiModel)")
        guard let requestURL = URL(string: url) else { throw AIError.invalidURL }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": [["text": user]]]],
            "generationConfig": ["maxOutputTokens": 65536, "temperature": 0.7]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await execute(request: request)
    }

    // MARK: - Claude POST (via newcli proxy)
    private static func postClaude(system: String, user: String) async throws -> Data {
        AILogger.shared.log("→ POST Claude model=\(claudeModel)")
        guard let requestURL = URL(string: claudeBase) else { throw AIError.invalidURL }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(claudeKey)", forHTTPHeaderField: "Authorization")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 120
        let body: [String: Any] = [
            "model": claudeModel,
            "system": system,
            "messages": [["role": "user", "content": user]],
            "max_tokens": 8192
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await execute(request: request)
    }

    // MARK: - Extract Claude response
    private static func extractClaude(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String
        else {
            AILogger.shared.log("extractClaude failed", error: true)
            throw AIError.invalidResponse
        }
        AILogger.shared.log("← Claude OK len=\(text.count)")
        return cleanJSON(text)
    }

    // MARK: - Execute request（带硬超时保险，防止模拟器URLSession挂起）
    // 专用 session：关闭连接复用，防止模拟器 URLSession 永久挂起
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest  = 60    // 单次读写超时
        cfg.timeoutIntervalForResource = 310   // 总超时
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()

    private static func execute(request: URLRequest) async throws -> Data {
        let timeout = request.timeoutInterval
        AILogger.shared.log("  发起请求，超时=\(Int(timeout))s")
        let startTime = Date()

        // 双保险：URLSession task 和硬超时 timer 同时跑，谁先完成谁赢
        return try await withThrowingTaskGroup(of: Data.self) { group in
            // 网络任务
            group.addTask {
                let (data, response) = try await withTaskCancellationHandler {
                    // 用 URLSession task 包装，确保 cancel 能传播
                    try await session.data(for: request)
                } onCancel: {
                    // task 被取消时 URLSession 会自动收到 cancel
                }
                guard let http = response as? HTTPURLResponse else {
                    AILogger.shared.log("✗ 非HTTP响应", error: true)
                    throw AIError.serverError
                }
                let elapsed = Int(Date().timeIntervalSince(startTime))
                guard http.statusCode == 200 else {
                    let msg = String(data: data, encoding: .utf8) ?? ""
                    AILogger.shared.log("✗ HTTP \(http.statusCode) \(elapsed)s: \(msg.prefix(120))", error: true)
                    throw AIError.serverError
                }
                AILogger.shared.log("← HTTP 200 \(elapsed)s，收到 \(data.count) 字节")
                return data
            }
            // 硬超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64((timeout + 5) * 1_000_000_000))
                let elapsed = Int(Date().timeIntervalSince(startTime))
                AILogger.shared.log("✗ 硬超时 \(elapsed)s，强制终止", error: true)
                throw AIError.serverError
            }
            // 取第一个完成/失败的结果
            do {
                let result = try await group.next()!
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                let elapsed = Int(Date().timeIntervalSince(startTime))
                AILogger.shared.log("✗ 请求失败 \(elapsed)s: \(error.localizedDescription)", error: true)
                throw AIError.serverError
            }
        }
    }

    // MARK: - Extract MiniMax response
    private static func extractMiniMax(from data: Data) throws -> String {
        let raw = String(data: data, encoding: .utf8) ?? ""
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let content = first["message"] as? [String: Any],
              let text = content["content"] as? String
        else {
            AILogger.shared.log("✗ extractMiniMax failed: \(raw.prefix(300))", error: true)
            throw AIError.invalidResponse
        }

        // 写原始响应 + cleaned JSON 到 app Documents 目录方便调试
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        try? text.write(to: docDir!.appendingPathComponent("last_response.txt"), atomically: true, encoding: .utf8)
        AILogger.shared.log("raw content len=\(text.count) chars")

        let finishReason = first["finish_reason"] as? String ?? "unknown"
        AILogger.shared.log("finish_reason=\(finishReason)")

        let cleaned = cleanJSON(text)
        AILogger.shared.log("cleaned JSON len=\(cleaned.count), preview: \(cleaned.prefix(80))")
        try? cleaned.write(to: docDir!.appendingPathComponent("last_cleaned.json"), atomically: true, encoding: .utf8)

        if finishReason == "length" {
            AILogger.shared.log("⚠ 响应被截断，尝试修复", error: true)
            return repairTruncatedJSON(cleaned)
        }

        let usage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["usage"] as? [String: Any]
        let reasoningTokens = (usage?["completion_tokens_details"] as? [String: Any])?["reasoning_tokens"] as? Int ?? 0
        AILogger.shared.log("← MiniMax OK reasoning=\(reasoningTokens)tok output=\(cleaned.count)chars")
        return cleaned
    }

    // MARK: - Extract Gemini response
    private static func extractGemini(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String
        else {
            let keys = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?.keys.joined(separator: ",") ?? "nil"
            AILogger.shared.log("✗ extractGemini failed keys=\(keys)", error: true)
            throw AIError.invalidResponse
        }
        print("[AIService] Extracted text length: \(text.count)")
        let cleaned = cleanJSON(text)
        AILogger.shared.log("← Gemini OK output=\(cleaned.count)chars")
        return cleaned
    }

    // MARK: - Clean JSON string
    private static func cleanJSON(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 去除 <think>...</think> 块（用正则一次性处理，包含换行）
        if let r = try? NSRegularExpression(pattern: "<think>[\\s\\S]*?</think>", options: []) {
            let range = NSRange(s.startIndex..., in: s)
            s = r.stringByReplacingMatches(in: s, range: range, withTemplate: "")
        }
        // 没有闭合 </think> 时（token 截断）：直接截取最后一个 { } 对
        if s.contains("<think>") {
            // 找最后一个完整 {...} 对
            if let last = s.lastIndex(of: "}"),
               let first = s[..<last].lastIndex(of: "{") {
                s = String(s[first...last])
            } else {
                s = "" // 无法提取，返回空让 caller 处理 fallback
            }
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. 去除 markdown 代码块
        s = s.replacingOccurrences(of: "```json", with: "")
        s = s.replacingOccurrences(of: "```", with: "")

        // 3. 截取第一个 { 到最后一个 }
        if let first = s.firstIndex(of: "{"),
           let last  = s.lastIndex(of: "}") {
            s = String(s[first...last])
        }

        // 4. 修复 AI 常见 JSON bug
        // fix-a: 数组元素开始处多余的 {"：},{"{ -> },{
        if let r = try? NSRegularExpression(pattern: #"\},\{"?\{"#) {
            let range = NSRange(s.startIndex..., in: s)
            s = r.stringByReplacingMatches(in: s, range: range, withTemplate: "},{\"")
        }
        // fix-b: 数字字面量后多余引号：6" -> 6
        if let r = try? NSRegularExpression(pattern: #"(\d+)"(\s*[,}\]])"#) {
            let range = NSRange(s.startIndex..., in: s)
            s = r.stringByReplacingMatches(in: s, range: range, withTemplate: "$1$2")
        }
        // fix-c: 日期/时间字符串缺少结尾引号："2026-04-17, → "2026-04-17",
        if let r = try? NSRegularExpression(pattern: #""(\d{4}-\d{2}-\d{2})([\s,\n\r}])"#) {
            let range = NSRange(s.startIndex..., in: s)
            s = r.stringByReplacingMatches(in: s, range: range, withTemplate: "\"$1\"$2")
        }
        // fix-d: 时间字段缺少结尾引号："09:00, → "09:00",
        if let r = try? NSRegularExpression(pattern: #""(\d{2}:\d{2})([\s,\n\r}])"#) {
            let range = NSRange(s.startIndex..., in: s)
            s = r.stringByReplacingMatches(in: s, range: range, withTemplate: "\"$1\"$2")
        }
        // fix-e: 字符串值缺失闭合引号（MiniMax 偶发 bug）
        // 正常: "key": "value",   破损: "key": "value,  或  "key": "value\n
        // 用负向后顾 (?<!") 确保只在值没有正常闭合时才补引号
        // Pass 1: 值后跟 , 或 \n 但前面没有 "
        if let r = try? NSRegularExpression(pattern: #"(:\s*")([^"]{1,200}?)(?<!")([\n,])"#) {
            let range = NSRange(s.startIndex..., in: s)
            s = r.stringByReplacingMatches(in: s, range: range, withTemplate: "$1$2\"$3")
        }
        // Pass 2: 再跑一遍覆盖行末无逗号的情况
        if let r = try? NSRegularExpression(pattern: #"(:\s*")([^"]{1,200}?)(?<!")([\n,])"#) {
            let range = NSRange(s.startIndex..., in: s)
            s = r.stringByReplacingMatches(in: s, range: range, withTemplate: "$1$2\"$3")
        }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Repair truncated JSON (best-effort)
    private static func repairTruncatedJSON(_ s: String) -> String {
        var result = s
        // 补齐未闭合的字符串（末尾有孤立引号）
        let quoteCount = result.filter { $0 == "\"" }.count
        if quoteCount % 2 != 0 { result += "\"" }
        // 补齐括号
        let opens  = result.filter { $0 == "{" }.count
        let closes = result.filter { $0 == "}" }.count
        let arrOpens  = result.filter { $0 == "[" }.count
        let arrCloses = result.filter { $0 == "]" }.count
        // 砍掉末尾不完整的字段（逗号后没有闭合）
        if result.last == "," { result.removeLast() }
        // 补方括号
        if arrOpens > arrCloses {
            result += String(repeating: "]", count: arrOpens - arrCloses)
        }
        // 补花括号
        if opens > closes {
            result += String(repeating: "}", count: opens - closes)
        }
        return result
    }

    // MARK: - Errors
    enum AIError: Error, LocalizedError {
        case invalidURL
        case serverError
        case invalidResponse
        case responseTruncated

        var errorDescription: String? {
            switch self {
            case .invalidURL:        return "服务地址配置错误"
            case .serverError:       return "AI 服务暂时不可用，请稍后重试"
            case .invalidResponse:   return "返回数据格式错误，请重试"
            case .responseTruncated: return "行程天数较多，AI 输出被截断。请缩短旅行天数（建议5天以内）后重试"
            }
        }
    }
}
