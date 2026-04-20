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
        // 第1天：出行交通 + 2个景点 + 晚餐 + 住宿
        // 第N天（中间）：早餐/交通 + 上午景点 + 午餐 + 下午景点 + 晚餐 + 住宿
        // 最后一天：上午景点 + 午餐 + 返程交通（无住宿）
        var itineraryTemplate = ""
        for (i, dateStr) in dateStrs.enumerated() {
            if i > 0 { itineraryTemplate += "," }
            let dayNum = i + 1
            let isFirst = i == 0
            let isLast  = i == dateStrs.count - 1
            let isSingleDay = dateStrs.count == 1

            var events: String
            if isSingleDay {
                events = """
                {"time":"09:00","title":"景点1","description":"简介","location":{"name":"地点","lat":0.0,"lng":0.0},"type":"attraction"},\
                {"time":"12:00","title":"午餐","description":"简介","location":{"name":"餐厅","lat":0.0,"lng":0.0},"type":"food"},\
                {"time":"14:00","title":"景点2","description":"简介","location":{"name":"地点","lat":0.0,"lng":0.0},"type":"attraction"},\
                {"time":"18:00","title":"晚餐","description":"简介","location":{"name":"餐厅","lat":0.0,"lng":0.0},"type":"food"}
                """
            } else if isFirst {
                events = """
                {"time":"09:00","title":"抵达\(destination)","description":"从出发地前往目的地","location":{"name":"机场或高铁站","lat":0.0,"lng":0.0},"type":"transport"},\
                {"time":"12:00","title":"午餐","description":"简介","location":{"name":"餐厅","lat":0.0,"lng":0.0},"type":"food"},\
                {"time":"14:00","title":"景点1","description":"简介","location":{"name":"地点","lat":0.0,"lng":0.0},"type":"attraction"},\
                {"time":"17:00","title":"景点2","description":"简介","location":{"name":"地点","lat":0.0,"lng":0.0},"type":"attraction"},\
                {"time":"19:30","title":"晚餐","description":"简介","location":{"name":"餐厅","lat":0.0,"lng":0.0},"type":"food"},\
                {"time":"21:00","title":"住宿","description":"入住酒店","location":{"name":"酒店名称","lat":0.0,"lng":0.0},"type":"accommodation"}
                """
            } else if isLast {
                events = """
                {"time":"09:00","title":"景点1","description":"简介","location":{"name":"地点","lat":0.0,"lng":0.0},"type":"attraction"},\
                {"time":"12:00","title":"午餐","description":"简介","location":{"name":"餐厅","lat":0.0,"lng":0.0},"type":"food"},\
                {"time":"14:00","title":"景点2","description":"简介","location":{"name":"地点","lat":0.0,"lng":0.0},"type":"attraction"},\
                {"time":"17:00","title":"返程","description":"前往机场或高铁站返回出发地","location":{"name":"机场或高铁站","lat":0.0,"lng":0.0},"type":"transport"}
                """
            } else {
                events = """
                {"time":"09:00","title":"景点1","description":"简介","location":{"name":"地点","lat":0.0,"lng":0.0},"type":"attraction"},\
                {"time":"12:00","title":"午餐","description":"简介","location":{"name":"餐厅","lat":0.0,"lng":0.0},"type":"food"},\
                {"time":"14:00","title":"景点2","description":"简介","location":{"name":"地点","lat":0.0,"lng":0.0},"type":"attraction"},\
                {"time":"17:00","title":"景点3","description":"简介","location":{"name":"地点","lat":0.0,"lng":0.0},"type":"attraction"},\
                {"time":"19:30","title":"晚餐","description":"简介","location":{"name":"餐厅","lat":0.0,"lng":0.0},"type":"food"},\
                {"time":"21:00","title":"住宿","description":"入住酒店","location":{"name":"酒店名称","lat":0.0,"lng":0.0},"type":"accommodation"}
                """
            }
            itineraryTemplate += """
            {"day":\(dayNum),"date":"\(dateStr)","title":"第\(dayNum)天主题","events":[\(events)]}
            """
        }

        let prompt = """
        只输出JSON，无其他文字。将下面模板中的占位内容替换为\(destination)（\(resolvedStyle)风格）的真实内容，保持JSON结构不变：

        {"destination":"\(destination)英文名","dateRange":{"start":"\(startStr)","end":"\(endStr)"},"itinerary":[\(itineraryTemplate)],"checklist":[{"id":"c1","title":"行前事项1","completed":false,"dayIndex":null},{"id":"c2","title":"行前事项2","completed":false,"dayIndex":null},{"id":"c3","title":"行前事项3","completed":false,"dayIndex":null}],"culture":{"type":"general","title":"\(destination)文化","nodes":[{"id":"n1","name":"文化节点1","subtitle":"副标题","description":"20字内描述","emoji":"🏛️","parentId":null},{"id":"n2","name":"文化节点2","subtitle":"副标题","description":"20字内描述","emoji":"🎭","parentId":"n1"},{"id":"n3","name":"文化节点3","subtitle":"副标题","description":"20字内描述","emoji":"🍜","parentId":null},{"id":"n4","name":"文化节点4","subtitle":"副标题","description":"20字内描述","emoji":"🎪","parentId":"n3"}]},"tips":["实用贴士1","实用贴士2","实用贴士3"],"sos":[{"title":"当地急救","phone":"急救电话","subtitle":"医疗急救","emoji":"🏥"},{"title":"当地报警","phone":"报警电话","subtitle":"警察","emoji":"👮"}]}

        要求：
        ①每个景点和住宿必须有真实GPS坐标（lat/lng为小数，不能为0）
        ②location.name只用纯地点名，不含逗号、括号、城市后缀
        ③description字段内不得包含双引号，改用单引号或省略
        ④所有字符串值不得包含未转义的双引号
        ⑤每天的景点按地理位置聚类安排，同一天内景点尽量集中在同一区域，避免来回穿越城市
        ⑥住宿位置选在当天最后一个景点附近，方便步行或短途交通
        ⑦多天行程整体按区域规划：第1天安排一个大区，第2天安排相邻区域，以此类推，形成合理的游览动线
        ⑧transport类型事件的location填写实际出发/到达的交通枢纽（机场/高铁站）真实坐标
        """

        let system = "只输出合法JSON，无任何额外文字。所有字符串值内禁止出现未转义双引号。"
        AILogger.shared.clear()
        // 真实测试数据（2026-04-20）：
        // 3天东京: completion=10870, reasoning=9803, JSON仅~1067tokens, 耗时134s
        // 5天巴黎: completion=10678, reasoning=8750, JSON仅~1928tokens, 耗时138s
        // 7天北京: completion=16000, reasoning=16000, 被截断(finish=length), 耗时224s
        // 结论：瓶颈是reasoning token，max_tokens动态计算无法解决问题
        // 必须固定16000保证7天以上不截断，后续通过thinking_budget=0禁用CoT来提速
        let maxTokens = 16000
        AILogger.shared.log("开始生成：\(destination) \(days)天 max_tokens=\(maxTokens)")
        return try await callWithRetry(system: system, user: prompt, maxTokens: maxTokens, maxRetries: 2)
    }

    // MARK: - Call with retry
    private static func callWithRetry(system: String, user: String, maxTokens: Int = 8000, maxRetries: Int = 1) async throws -> String {
        var lastError: Error = AIError.invalidResponse
        for attempt in 1...maxRetries {
            do {
                let result = try await call(system: system, user: user, maxTokens: maxTokens)
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
    private static func call(system: String, user: String, maxTokens: Int = 8000) async throws -> String {
        AILogger.shared.log("provider=\(provider.rawValue) model=\(minimaxModel)")
        switch provider {
        case .minimax:
            let messages: [[String: Any]] = [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
            let raw = try await postMiniMax(messages: messages, maxTokens: maxTokens)
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
    private static func postMiniMax(messages: [[String: Any]], maxTokens: Int = 8000) async throws -> Data {
        let url = "https://api.minimaxi.com/v1/chat/completions"
        AILogger.shared.log("→ POST \(url)")
        AILogger.shared.log("  model=\(minimaxModel) max_tokens=\(maxTokens)")
        guard let requestURL = URL(string: url) else { throw AIError.invalidURL }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(minimaxKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300
        let body: [String: Any] = [
            "model": minimaxModel,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": 0.3
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
        let promptTokens     = usage?["prompt_tokens"]     as? Int ?? 0
        let completionTokens = usage?["completion_tokens"] as? Int ?? 0
        let totalTokens      = usage?["total_tokens"]      as? Int ?? 0
        let reasoningTokens  = (usage?["completion_tokens_details"] as? [String: Any])?["reasoning_tokens"] as? Int ?? 0
        AILogger.shared.log("← MiniMax OK prompt=\(promptTokens) completion=\(completionTokens) reasoning=\(reasoningTokens) total=\(totalTokens) chars=\(cleaned.count)")
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
    // 预编译正则（只编译一次，避免每次 cleanJSON 重复编译）
    private static let rxThinkTag   = try? NSRegularExpression(pattern: "<think>[\\s\\S]*?</think>")
    private static let rxBadBrace   = try? NSRegularExpression(pattern: #"\},\{"?\{"#)
    private static let rxNumQuote   = try? NSRegularExpression(pattern: #"(\d+)"(\s*[,}\]])"#)
    private static let rxDateQuote  = try? NSRegularExpression(pattern: #""(\d{4}-\d{2}-\d{2})([\s,\n\r}])"#)
    private static let rxTimeQuote  = try? NSRegularExpression(pattern: #""(\d{2}:\d{2})([\s,\n\r}])"#)
    private static let rxMissingQ   = try? NSRegularExpression(pattern: #"(:\s*")([^"]{1,200}?)(?<!")([\n,])"#)

    private static func cleanJSON(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 去除 <think>...</think> 块
        if let r = rxThinkTag {
            s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        if s.contains("<think>") {
            if let last = s.lastIndex(of: "}"), let first = s[..<last].lastIndex(of: "{") {
                s = String(s[first...last])
            } else { s = "" }
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. 去除 markdown 代码块
        s = s.replacingOccurrences(of: "```json", with: "")
        s = s.replacingOccurrences(of: "```", with: "")

        // 3. 截取第一个 { 到最后一个 }
        if let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}") {
            s = String(s[first...last])
        }

        // 4. 修复 AI 常见 JSON bug（用预编译正则）
        func replace(_ r: NSRegularExpression?, tpl: String) {
            guard let r else { return }
            let range = NSRange(s.startIndex..., in: s)
            s = r.stringByReplacingMatches(in: s, range: range, withTemplate: tpl)
        }
        replace(rxBadBrace,  tpl: "},{\"")           // fix-a
        replace(rxNumQuote,  tpl: "$1$2")             // fix-b
        replace(rxDateQuote, tpl: "\"$1\"$2")         // fix-c
        replace(rxTimeQuote, tpl: "\"$1\"$2")         // fix-d
        replace(rxMissingQ,  tpl: "$1$2\"$3")         // fix-e pass1
        replace(rxMissingQ,  tpl: "$1$2\"$3")         // fix-e pass2
        s = fixSpuriousQuotesInJSONStrings(s)         // fix-f

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 逐字符扫描 JSON，修复字符串值内部因 AI 幻觉插入的多余双引号。
    private static func fixSpuriousQuotesInJSONStrings(_ input: String) -> String {
        var chars = Array(input)
        let n = chars.count
        var i = 0
        while i < n {
            guard chars[i] == "\"" else { i += 1; continue }
            // 进入字符串模式，找到"真正的"闭合引号
            var j = i + 1
            while j < n {
                if chars[j] == "\\" {
                    j += 2  // 跳过转义字符
                    continue
                }
                if chars[j] == "\"" {
                    // 候选闭合位置：检查后面第一个非空字符
                    var k = j + 1
                    while k < n && (chars[k] == " " || chars[k] == "\t") { k += 1 }
                    let nextIsValid = k < n && ":,}]\n\r".contains(chars[k])
                    if nextIsValid {
                        // 合法闭合，跳出字符串
                        i = k
                        break
                    } else {
                        // 多余引号：替换为空格，继续扫描
                        chars[j] = " "
                        j += 1
                        continue
                    }
                }
                j += 1
            }
            i += 1
        }
        return String(chars)
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
