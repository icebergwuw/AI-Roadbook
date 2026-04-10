import SwiftUI
import SwiftData

struct ChatView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var vm = ChatViewModel()

    private var sortedMessages: [Message] {
        trip.messages.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if sortedMessages.isEmpty {
                                emptyState
                                    .padding(.top, 40)
                            }
                            ForEach(sortedMessages) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }
                            if vm.isLoading {
                                HStack {
                                    ProgressView().tint(AppTheme.gold)
                                    Text("AI 思考中…")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                    Spacer()
                                }
                                .padding(.horizontal, AppTheme.padding)
                                .id("loading")
                            }
                        }
                        .padding(AppTheme.padding)
                    }
                    .onChange(of: sortedMessages.count) {
                        if let last = sortedMessages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: vm.isLoading) {
                        if vm.isLoading {
                            withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                        }
                    }
                }

                // Error banner
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                }

                // Input bar
                HStack(spacing: 10) {
                    TextField("问问 AI…", text: $vm.inputText, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(10)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(20)
                        .foregroundColor(AppTheme.textPrimary)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border))

                    Button {
                        let text = vm.inputText
                        vm.inputText = ""
                        Task { await vm.send(text: text, trip: trip, context: modelContext) }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(vm.canSend ? AppTheme.gold : AppTheme.border)
                    }
                    .disabled(!vm.canSend)
                }
                .padding(AppTheme.padding)
                .background(AppTheme.cardBackground)
                .overlay(alignment: .top) {
                    Divider().background(AppTheme.border)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("💬")
                .font(.system(size: 40))
            Text("向 AI 提问关于这次旅行的任何问题")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MessageBubble: View {
    let message: Message

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            if !isUser {
                Text("🤖")
                    .font(.caption)
            }

            Text(message.content)
                .font(.subheadline)
                .foregroundColor(isUser ? .black : AppTheme.textPrimary)
                .padding(12)
                .background(isUser ? AppTheme.gold : AppTheme.cardBackground)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border))

            if !isUser { Spacer(minLength: 48) }
        }
    }
}
