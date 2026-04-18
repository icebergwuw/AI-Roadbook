import Foundation
import SwiftData

/// 解析 AI 返回的 patch 指令并应用到本地 Trip 数据
enum TripPatchApplier {

    // MARK: - Patch 结构

    /// AI 返回的顶层结构，区分普通回复和行程修改
    struct ChatResponse: Decodable {
        let type: String           // "message" | "patch"
        let message: String        // 给用户看的文字
        let patch: TripPatch?      // 仅 type == "patch" 时存在
    }

    struct TripPatch: Decodable {
        let addEvents: [AddEventOp]?
        let removeEvents: [RemoveEventOp]?
        let updateEvents: [UpdateEventOp]?
        let updateDayTitle: [UpdateDayTitleOp]?
        let addChecklist: [AddChecklistOp]?
    }

    struct AddEventOp: Decodable {
        let dayIndex: Int          // 0-based
        let time: String
        let title: String
        let description: String
        let locationName: String
        let lat: Double?
        let lng: Double?
        let type: String           // transport|attraction|food|accommodation
    }

    struct RemoveEventOp: Decodable {
        let dayIndex: Int
        let eventTitle: String     // 按标题匹配
    }

    struct UpdateEventOp: Decodable {
        let dayIndex: Int
        let eventTitle: String
        let newTime: String?
        let newTitle: String?
        let newDescription: String?
        let newLocationName: String?
        let newLat: Double?
        let newLng: Double?
        let newType: String?
    }

    struct UpdateDayTitleOp: Decodable {
        let dayIndex: Int
        let newTitle: String
    }

    struct AddChecklistOp: Decodable {
        let title: String
        let dayIndex: Int?
    }

    // MARK: - 解析

    /// 尝试解析 AI 回复：优先解析为 ChatResponse JSON，失败则视为纯文字
    static func parse(aiText: String) -> (displayMessage: String, patch: TripPatch?) {
        let cleaned = aiText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 扫描所有可能的 JSON 块（找每个 '{' 开始、平衡括号结束的子串，逐个尝试解码）
        if let resp = extractChatResponse(from: cleaned), resp.type == "patch" || resp.type == "message" {
            // patch 类型：返回 message 文字 + patch 数据
            if resp.type == "patch" {
                return (resp.message, resp.patch)
            }
            // message 类型：只返回 message 文字
            return (resp.message, nil)
        }

        // 无法解析为 ChatResponse，原样返回
        return (cleaned, nil)
    }

    /// 在任意文本中找第一个能成功解码为 ChatResponse 的 JSON 块
    private static func extractChatResponse(from text: String) -> ChatResponse? {
        var i = text.startIndex
        while i < text.endIndex {
            guard let openBrace = text[i...].firstIndex(of: "{") else { break }
            // 平衡括号，找对应的闭合 '}'
            var depth = 0
            var j = openBrace
            while j < text.endIndex {
                if text[j] == "{" { depth += 1 }
                else if text[j] == "}" {
                    depth -= 1
                    if depth == 0 {
                        // 尝试解码这段
                        let candidate = String(text[openBrace...j])
                        if let data = candidate.data(using: .utf8),
                           let resp = try? JSONDecoder().decode(ChatResponse.self, from: data) {
                            return resp
                        }
                        break
                    }
                }
                j = text.index(after: j)
            }
            // 继续往后找下一个 '{'
            i = text.index(after: openBrace)
        }
        return nil
    }

    // MARK: - 应用 patch

    static func apply(patch: TripPatch, to trip: Trip, context: ModelContext) {
        let sortedDays = trip.days.sorted { $0.sortIndex < $1.sortIndex }

        // 1. 新增事件
        for op in patch.addEvents ?? [] {
            guard op.dayIndex < sortedDays.count else { continue }
            let day = sortedDays[op.dayIndex]
            let maxIdx = day.events.map { $0.sortIndex }.max() ?? -1
            let event = TripEvent(
                time: op.time,
                title: op.title,
                description: op.description,
                locationName: op.locationName,
                latitude: op.lat,
                longitude: op.lng,
                eventType: op.type,
                sortIndex: maxIdx + 1
            )
            day.events.append(event)
            context.insert(event)
        }

        // 2. 删除事件
        for op in patch.removeEvents ?? [] {
            guard op.dayIndex < sortedDays.count else { continue }
            let day = sortedDays[op.dayIndex]
            if let idx = day.events.firstIndex(where: {
                $0.title.localizedCaseInsensitiveContains(op.eventTitle)
            }) {
                let event = day.events.remove(at: idx)
                context.delete(event)
            }
        }

        // 3. 更新事件
        for op in patch.updateEvents ?? [] {
            guard op.dayIndex < sortedDays.count else { continue }
            let day = sortedDays[op.dayIndex]
            if let event = day.events.first(where: {
                $0.title.localizedCaseInsensitiveContains(op.eventTitle)
            }) {
                if let v = op.newTime        { event.time = v }
                if let v = op.newTitle       { event.title = v }
                if let v = op.newDescription { event.eventDescription = v }
                if let v = op.newLocationName{ event.locationName = v }
                if let v = op.newLat         { event.latitude = v }
                if let v = op.newLng         { event.longitude = v }
                if let v = op.newType        { event.eventType = v }
            }
        }

        // 4. 更新天标题
        for op in patch.updateDayTitle ?? [] {
            guard op.dayIndex < sortedDays.count else { continue }
            sortedDays[op.dayIndex].title = op.newTitle
        }

        // 5. 新增 checklist
        for op in patch.addChecklist ?? [] {
            let item = ChecklistItem(
                title: op.title,
                isCompleted: false,
                dayIndex: op.dayIndex
            )
            trip.checklist.append(item)
            context.insert(item)
        }

        try? context.save()
    }
}
