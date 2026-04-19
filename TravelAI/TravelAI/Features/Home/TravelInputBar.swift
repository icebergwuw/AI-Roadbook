import SwiftUI

// MARK: - TravelInputBar（底部输入栏）
struct TravelInputBar: View {
    var ctrl: TripInputController
    var onWillGenerate: (() -> Void)? = nil

    @State private var inputText: String = ""
    @FocusState private var focused: Bool

    private let styles = ["文化探索", "自然风光", "美食之旅", "历史遗迹", "城市漫步", "亲子游", "浪漫蜜月"]
    private let daysOptions = [1, 2, 3, 5, 7, 10, 14]

    private var canSend: Bool {
        switch ctrl.chatStep {
        case .idle:    return !inputText.trimmingCharacters(in: .whitespaces).isEmpty
        case .date:    return true
        case .confirm: return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if ctrl.chatStep != .idle {
                chatBubbleArea
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            inputRow
        }
        .onAppear {
            if inputText.isEmpty && !ctrl.destination.isEmpty {
                inputText = ctrl.destination
            }
        }
        .onChange(of: ctrl.resetToken) {
            inputText = ctrl.destination
            focused = false   // 确保 confirm→idle 后输入框完全解锁
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: ctrl.chatStep)
    }

    // MARK: - 输入行
    private var inputRow: some View {
        HStack(spacing: 10) {
            Button { randomize() } label: {
                Image(systemName: "dice.fill")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 42, height: 42)
                    .glassEffect(.regular, in: .circle)
            }

            ZStack(alignment: .leading) {
                if inputText.isEmpty {
                    Text(placeholderText)
                        .font(.system(size: 15)).foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 14)
                }
                TextField("", text: $inputText)
                    .focused($focused)
                    .font(.system(size: 15)).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .submitLabel(.send)
                    .onSubmit { handleSend() }
                    .disabled(ctrl.chatStep != .idle)
            }
            .glassEffect(.regular, in: Capsule())
            .frame(height: 44)

            Button { handleSend() } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(canSend ? .white : .white.opacity(0.3))
                    .frame(width: 42, height: 42)
                    .glassEffect(.regular, in: .circle)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 聊天气泡区域
    @ViewBuilder
    private var chatBubbleArea: some View {
        let bindableCtrl = Bindable(ctrl)
        VStack(alignment: .leading, spacing: 10) {
            switch ctrl.chatStep {
            case .idle:
                EmptyView()

            case .date:
                // 天数
                bubbleAssistant("去\(ctrl.destination)，几天？")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(daysOptions, id: \.self) { day in
                            chipButton("\(day)天", selected: ctrl.selectedDays == day) {
                                ctrl.selectedDays = day
                            }
                        }
                    }.padding(.horizontal, 16)
                }

                // 出发日期
                HStack(spacing: 8) {
                    bubbleAssistant("出发")
                    DatePicker("", selection: bindableCtrl.selectedDate,
                               displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .padding(.trailing, 16)
                }

                // 出行方式
                bubbleAssistant("出行方式")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TransportMode.allCases, id: \.self) { mode in
                            chipButton("\(mode.emoji) \(mode.label)",
                                       selected: ctrl.transportMode == mode) {
                                ctrl.transportMode = mode
                            }
                        }
                    }.padding(.horizontal, 16)
                }

                // 游玩风格
                bubbleAssistant("风格")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(styles, id: \.self) { s in
                            chipButton(s, selected: ctrl.selectedStyle == s) {
                                ctrl.selectedStyle = s
                            }
                        }
                    }.padding(.horizontal, 16)
                }

            case .confirm:
                EmptyView() // 进度卡片已经显示目的地信息，这里不重复
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - 气泡 & 芯片
    private func bubbleAssistant(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.leading, 16)
    }

    private func chipButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(selected
                    ? AnyShapeStyle(AppTheme.accentGradient)
                    : AnyShapeStyle(Color.white.opacity(0.12)))
                .clipShape(Capsule())
        }
    }

    // MARK: - Placeholder
    private var placeholderText: String {
        switch ctrl.chatStep {
        case .idle:    return "去哪里旅行？"
        case .date:    return "确认后生成 →"
        case .confirm: return "正在生成…"
        }
    }

    // MARK: - 交互
    private func handleSend() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        switch ctrl.chatStep {
        case .idle:
            guard !text.isEmpty else { return }
            ctrl.destination = text
            inputText = ""
            focused = false
            withAnimation { ctrl.chatStep = .date }

        case .date:
            withAnimation { ctrl.chatStep = .confirm }
            onWillGenerate?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if ctrl.onStartGeneration != nil {
                    ctrl.onStartGeneration?(
                        ctrl.destination, ctrl.selectedDate,
                        ctrl.selectedDays, ctrl.selectedStyle,
                        ctrl.transportMode)
                } else {
                    ctrl.reset()
                }
            }

        case .confirm:
            break
        }
    }

    private func randomize() {
        let destinations = ["京都", "冰岛", "摩洛哥", "新西兰", "秘鲁", "北欧", "巴厘岛", "土耳其", "阿尔卑斯", "南极"]
        ctrl.destination = destinations.randomElement() ?? "东京"
        inputText = ctrl.destination
    }
}
