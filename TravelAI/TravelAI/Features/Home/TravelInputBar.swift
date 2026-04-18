import SwiftUI

// MARK: - TravelInputBar（底部输入栏 + 聊天气泡流程）
struct TravelInputBar: View {
    var ctrl: TripInputController
    /// 生成即将触发前的回调（例如 TripListSheet 用来先 dismiss）
    var onWillGenerate: (() -> Void)? = nil

    @State private var inputText: String = ""
    @FocusState private var focused: Bool

    // 旅行风格选项
    private let styles = ["文化探索", "自然风光", "美食之旅", "历史遗迹", "城市漫步", "亲子游", "浪漫蜜月"]
    private let daysOptions = [1, 2, 3, 5, 7, 10, 14]

    private var canSend: Bool {
        switch ctrl.chatStep {
        case .idle:    return !inputText.trimmingCharacters(in: .whitespaces).isEmpty
        case .date:    return true
        case .style:   return true
        case .confirm: return false  // 生成中禁止重复提交
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if ctrl.chatStep != .idle {
                chatBubbleArea.transition(.move(edge: .bottom).combined(with: .opacity))
            }
            inputRow
        }
        .onAppear {
            // 首次显示时同步 ctrl.destination → inputText
            if inputText.isEmpty && !ctrl.destination.isEmpty {
                inputText = ctrl.destination
            }
        }
        // reset() 后刷新 inputText 为新的随机目的地
        .onChange(of: ctrl.resetToken) {
            inputText = ctrl.destination
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: ctrl.chatStep)
    }

    // MARK: - 输入行
    private var inputRow: some View {
        HStack(spacing: 10) {
            // 骰子按钮
            Button { randomize() } label: {
                Image(systemName: "dice.fill")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 42, height: 42)
                    .glassEffect(.regular, in: .circle)
            }

            // 文本框
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
                    .disabled(ctrl.chatStep == .date || ctrl.chatStep == .style)
            }
            .glassEffect(.regular, in: Capsule())
            .frame(height: 44)

            // 发送按钮
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
            case .idle: EmptyView()

            case .date:
                bubbleAssistant("要去\(ctrl.destination)，几天比较好？")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(daysOptions, id: \.self) { day in
                            Button { ctrl.selectedDays = day } label: {
                                Text("\(day) 天")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(ctrl.selectedDays == day ? .white : .white.opacity(0.7))
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(ctrl.selectedDays == day
                                                ? AnyShapeStyle(AppTheme.accentGradient)
                                                : AnyShapeStyle(Color.white.opacity(0.12)))
                                    .clipShape(Capsule())
                            }
                        }
                    }.padding(.horizontal, 16)
                }
                HStack(spacing: 8) {
                    bubbleAssistant("出发时间？")
                    DatePicker("", selection: bindableCtrl.selectedDate,
                               displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .padding(.trailing, 16)
                }

            case .style:
                bubbleAssistant("选一个旅行风格吧 ✈️")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(styles, id: \.self) { s in
                            Button { ctrl.selectedStyle = s } label: {
                                Text(s)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(ctrl.selectedStyle == s ? .white : .white.opacity(0.7))
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(ctrl.selectedStyle == s
                                                ? AnyShapeStyle(AppTheme.accentGradient)
                                                : AnyShapeStyle(Color.white.opacity(0.12)))
                                    .clipShape(Capsule())
                            }
                        }
                    }.padding(.horizontal, 16)
                }

            case .confirm:
                bubbleAssistant("好！准备生成\(ctrl.destination)\(ctrl.selectedDays)天\(ctrl.selectedStyle)攻略🚀")
            }
        }
        .padding(.vertical, 8)
    }

    private func bubbleAssistant(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
    }

    // MARK: - 交互逻辑
    private var placeholderText: String {
        switch ctrl.chatStep {
        case .idle:    return "去哪里旅行？"
        case .date:    return "确认后下一步 →"
        case .style:   return "确认后生成 →"
        case .confirm: return "正在生成…"
        }
    }

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
            withAnimation { ctrl.chatStep = .style }

        case .style:
            withAnimation { ctrl.chatStep = .confirm }
            onWillGenerate?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if ctrl.onStartGeneration != nil {
                    ctrl.onStartGeneration?(
                        ctrl.destination, ctrl.selectedDate,
                        ctrl.selectedDays, ctrl.selectedStyle)
                } else {
                    // onStartGeneration 未注册，立即 reset 避免卡在 .confirm
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
