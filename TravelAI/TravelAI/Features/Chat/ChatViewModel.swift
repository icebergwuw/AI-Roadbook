import SwiftData
import Foundation

@Observable
final class ChatViewModel {
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var lastPatchSummary: String?   // 显示"已更新行程"提示

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    func buildAPIMessages(from history: [Message], newMessage: String) -> [[String: String]] {
        var msgs = history.map { ["role": $0.role, "content": $0.content] }
        msgs.append(["role": "user", "content": newMessage])
        return msgs
    }

    func send(text: String, trip: Trip, context: ModelContext) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        lastPatchSummary = nil

        // 保存用户消息
        let userMsg = Message(role: "user", content: trimmed)
        trip.messages.append(userMsg)
        context.insert(userMsg)
        try? context.save()

        // 构建历史（排除刚添加的）
        let history = trip.messages
            .filter { $0.id != userMsg.id }
            .sorted { $0.createdAt < $1.createdAt }

        let tripContext = buildTripContext(trip)
        let apiMessages = buildAPIMessages(from: history, newMessage: trimmed)

        do {
            let rawResponse = try await AIService.chat(messages: apiMessages, tripContext: tripContext)

            // 解析是否含 patch
            let (displayMessage, patch) = TripPatchApplier.parse(aiText: rawResponse)

            // 应用 patch（如果有）
            if let patch {
                TripPatchApplier.apply(patch: patch, to: trip, context: context)
                lastPatchSummary = displayMessage
                print("[Chat] Patch applied")
            }

            // 保存 AI 回复（显示给用户的文字）
            let assistantMsg = Message(role: "assistant", content: displayMessage)
            trip.messages.append(assistantMsg)
            context.insert(assistantMsg)
            try? context.save()

        } catch {
            errorMessage = error.localizedDescription
            // 回滚用户消息
            if let idx = trip.messages.firstIndex(where: { $0.id == userMsg.id }) {
                trip.messages.remove(at: idx)
            }
            context.delete(userMsg)
            try? context.save()
        }

        isLoading = false
    }

    // MARK: - 构建行程上下文（给 AI 看的）

    private func buildTripContext(_ trip: Trip) -> String {
        let sortedDays = trip.days.sorted { $0.sortIndex < $1.sortIndex }
        var lines: [String] = [
            "目的地：\(trip.destination)",
            "日期：\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) — \(trip.endDate.formatted(date: .abbreviated, time: .omitted))",
            "共 \(sortedDays.count) 天"
        ]
        for (i, day) in sortedDays.enumerated() {
            let events = day.events.sorted { $0.sortIndex < $1.sortIndex }
            let eventList = events.map { "\($0.time) \($0.title)" }.joined(separator: "、")
            lines.append("Day\(i)（\(day.title)）：\(eventList.isEmpty ? "暂无安排" : eventList)")
        }
        return lines.joined(separator: "\n")
    }
}
