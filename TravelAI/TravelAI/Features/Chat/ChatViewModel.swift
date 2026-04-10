import SwiftData
import Foundation

@Observable
final class ChatViewModel {
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

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

        // Save user message immediately
        let userMsg = Message(role: "user", content: trimmed)
        trip.messages.append(userMsg)
        context.insert(userMsg)
        try? context.save()

        // Build sorted history (excluding the message we just added)
        let history = trip.messages
            .filter { $0.role != userMsg.role || $0.content != userMsg.content || $0.createdAt != userMsg.createdAt }
            .sorted { $0.createdAt < $1.createdAt }

        let tripContext = "目的地：\(trip.destination)，日期：\(trip.startDate)—\(trip.endDate)，共\(trip.days.count)天行程"
        let apiMessages = buildAPIMessages(from: history, newMessage: trimmed)

        do {
            let response = try await AIService.chat(messages: apiMessages, tripContext: tripContext)
            let assistantMsg = Message(role: "assistant", content: response)
            trip.messages.append(assistantMsg)
            context.insert(assistantMsg)
            try? context.save()
        } catch {
            errorMessage = error.localizedDescription
            // Remove the failed user message
            if let idx = trip.messages.firstIndex(where: { $0.content == userMsg.content && $0.role == userMsg.role }) {
                trip.messages.remove(at: idx)
            }
            context.delete(userMsg)
        }

        isLoading = false
    }
}
