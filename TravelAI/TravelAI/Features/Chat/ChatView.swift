import SwiftUI
import SwiftData

struct ChatView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var vm = ChatViewModel()
    // 缓存排序结果，避免键盘弹出时重复排序触发全量重渲染
    @State private var cachedMessages: [Message] = []

    private var sortedMessages: [Message] {
        trip.messages.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ZStack {
            AppTheme.pageBGGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if cachedMessages.isEmpty { emptyState.padding(.top, 48) }
                            ForEach(cachedMessages) { msg in
                                MessageBubble(message: msg).id(msg.id)
                            }
                            if vm.isLoading {
                                TypingIndicator().id("loading")
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                        }
                        .padding(.horizontal, AppTheme.padding)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: trip.messages.count) {
                        cachedMessages = sortedMessages
                        if let last = cachedMessages.last {
                            withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: vm.isLoading) {
                        if vm.isLoading {
                            withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("loading", anchor: .bottom) }
                        }
                    }
                    .onAppear {
                        cachedMessages = sortedMessages
                    }
                }

                if let summary = vm.lastPatchSummary {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(AppTheme.teal).font(.caption)
                        Text(summary).font(.caption).foregroundColor(AppTheme.teal)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(AppTheme.tealBG)
                    .overlay(alignment: .top) { Rectangle().fill(AppTheme.teal.opacity(0.2)).frame(height: 1) }
                }

                if let err = vm.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.caption)
                        Text(err).font(.caption)
                    }
                    .foregroundColor(AppTheme.red)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.redBG)
                    .overlay(alignment: .top) { Rectangle().fill(AppTheme.red.opacity(0.2)).frame(height: 1) }
                }

                inputBar
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("问问 AI…", text: $vm.inputText, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(AppTheme.cardBGAlt)
                .cornerRadius(20)
                .foregroundColor(AppTheme.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(vm.inputText.isEmpty ? AppTheme.border : PageAccent.chat.opacity(0.5), lineWidth: 1)
                )

            Button {
                let text = vm.inputText; vm.inputText = ""
                Task { await vm.send(text: text, trip: trip, context: modelContext) }
            } label: {
                ZStack {
                    Circle()
                        .fill(vm.canSend
                              ? AnyShapeStyle(LinearGradient(
                                    colors: [PageAccent.chat, Color(hex: "#1A4FC0")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(AppTheme.sectionBG))
                        .frame(width: 38, height: 38)
                        .shadow(color: vm.canSend ? PageAccent.chat.opacity(0.3) : .clear, radius: 6)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(vm.canSend ? .white : AppTheme.textTertiary)
                }
            }
            .buttonStyle(GoldButtonStyle(enabled: vm.canSend))
            .disabled(!vm.canSend)
        }
        .padding(.horizontal, AppTheme.padding).padding(.vertical, 11)
        .background(AppTheme.cardBG)
        .overlay(alignment: .top) { Rectangle().fill(AppTheme.border).frame(height: 1) }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(PageAccent.chatBG).frame(width: 88, height: 88)
                    .overlay(Circle().stroke(PageAccent.chat.opacity(0.15), lineWidth: 1))
                Text("💬").font(.system(size: 40))
            }
            VStack(spacing: 5) {
                Text("旅行助手")
                    .font(.system(size: 17, weight: .bold)).foregroundColor(AppTheme.textPrimary)
                Text("向 AI 提问关于这次旅行的任何问题")
                    .font(.system(size: 13)).foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button { vm.inputText = s } label: {
                        Text(s).font(.system(size: 13)).foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(AppTheme.cardBG)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var suggestions: [String] {
        ["这个目的地有什么必去景点？", "有什么当地美食推荐？", "需要注意什么文化礼仪？"]
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    @State private var appeared = false
    var isUser: Bool { message.role == "user" }

    // 缓存 markdown 解析结果，避免每次渲染重新计算
    private var markdownContent: AttributedString {
        (try? AttributedString(markdown: message.content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
        ?? AttributedString(message.content)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 56) }

            if !isUser {
                ZStack {
                    Circle().fill(PageAccent.chatBG).frame(width: 30, height: 30)
                        .overlay(Circle().stroke(PageAccent.chat.opacity(0.2), lineWidth: 1))
                    Text("🤖").font(.system(size: 15))
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                Group {
                    if isUser {
                        Text(message.content)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    } else {
                        // AI 消息支持 Markdown 渲染
                        Text(markdownContent)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textPrimary)
                            .tint(AppTheme.accent)
                    }
                }
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .background(
                        isUser
                        ? AnyShapeStyle(LinearGradient(
                            colors: [PageAccent.chat, Color(hex: "#1A4FC0")],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(AppTheme.cardBGAlt)
                    )
                    .cornerRadius(17)
                    .cornerRadius(isUser ? 4 : 17, corners: isUser ? .bottomRight : .bottomLeft)
                    .overlay(isUser ? nil : AnyView(
                        RoundedRectangle(cornerRadius: 17).stroke(AppTheme.border, lineWidth: 1)
                    ))
                    .shadow(color: isUser ? PageAccent.chat.opacity(0.2) : Color.black.opacity(0.05),
                            radius: isUser ? 6 : 3, x: 0, y: 2)

                Text(timeText(message.createdAt))
                    .font(.system(size: 10)).foregroundColor(AppTheme.textTertiary)
            }

            if !isUser { Spacer(minLength: 56) }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear { withAnimation(AppTheme.animSmooth) { appeared = true } }
    }

    private func timeText(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"; return fmt.string(from: date)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase = 0
    @State private var timer: Timer? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(PageAccent.chatBG).frame(width: 30, height: 30)
                    .overlay(Circle().stroke(PageAccent.chat.opacity(0.2), lineWidth: 1))
                Text("🤖").font(.system(size: 15))
            }

            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(PageAccent.chat.opacity(i == phase ? 0.8 : 0.25))
                        .frame(width: 6, height: 6)
                        .scaleEffect(i == phase ? 1.2 : 1.0)
                        .animation(AppTheme.animSmooth.delay(Double(i) * 0.15), value: phase)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(AppTheme.cardBGAlt)
            .cornerRadius(17)
            .cornerRadius(4, corners: .bottomLeft)
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(AppTheme.border))

            Spacer(minLength: 56)
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}
