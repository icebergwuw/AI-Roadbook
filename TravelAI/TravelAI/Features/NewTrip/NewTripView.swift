import SwiftUI
import SwiftData
import CoreLocation

// MARK: - NewTripView
// 轻量 bottom sheet：目的地已从主界面预填，只确认日期 + 风格
struct NewTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var vm: NewTripViewModel

    /// 生成进度回调 (progress 0-1, message)
    var onProgressUpdate: ((Double, String) -> Void)?
    /// 用户点击生成按钮时立刻回调（动画可以马上开始，不需要等AI）
    var onStartAnimation: ((String) -> Void)?
    /// 生成完成回调 (目的地名, 每天坐标数组)
    var onComplete: ((String, [[CLLocationCoordinate2D]]) -> Void)?
    /// 生成失败回调
    var onError: ((String) -> Void)?

    init(
        prefilled: String = "",
        onProgressUpdate: ((Double, String) -> Void)? = nil,
        onStartAnimation: ((String) -> Void)? = nil,
        onComplete: ((String, [[CLLocationCoordinate2D]]) -> Void)? = nil,
        onError: ((String) -> Void)? = nil
    ) {
        let m = NewTripViewModel()
        m.destination = prefilled
        m.onPhaseChanged = { phase in
            onProgressUpdate?(phase.progress, phase.message)
            if phase == .done {
                onComplete?(m.destination, m.generatedItineraryCoords)
            }
        }
        m.onError = onError
        _vm = State(initialValue: m)
        self.onProgressUpdate = onProgressUpdate
        self.onStartAnimation = onStartAnimation
        self.onComplete = onComplete
        self.onError = onError
    }

    var body: some View {
        // presentationDetents 让它只占半屏
        NavigationStack {
            ZStack {
                AppTheme.pageBGGradient.ignoresSafeArea()
                confirmSheet
            }
            .navigationTitle(vm.destination.isEmpty ? "新建旅行" : vm.destination)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(.ultraThinMaterial)
        .presentationBackgroundInteraction(.enabled)   // 允许与背景地图交互
    }

    // MARK: - 确认表单（紧凑悬浮卡片，不遮挡地图）
    private var confirmSheet: some View {
        VStack(spacing: 12) {
            // 目的地 + 日期 一行
            HStack(spacing: 16) {
                // 目的地
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(AppTheme.accent)
                        .font(.system(size: 15))
                    if vm.destination.isEmpty {
                        TextField("目的地", text: $vm.destination)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    } else {
                        Text(vm.destination)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                // 日期
                HStack(spacing: 4) {
                    DatePicker("", selection: $vm.startDate, displayedComponents: .date)
                        .datePickerStyle(.compact).tint(AppTheme.accent).labelsHidden()
                        .scaleEffect(0.9)
                    Text("→").font(.caption2).foregroundColor(AppTheme.textTertiary)
                    DatePicker("", selection: $vm.endDate, in: vm.startDate..., displayedComponents: .date)
                        .datePickerStyle(.compact).tint(AppTheme.accent).labelsHidden()
                        .scaleEffect(0.9)
                }
            }
            .padding(.horizontal, 20)

            // 风格选择
            HStack(spacing: 8) {
                ForEach(NewTripViewModel.TravelStyle.allCases, id: \.self) { style in
                    styleChip(style)
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            // 错误提示
            if let err = vm.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.red).font(.caption)
                    Text(err).font(.caption).foregroundColor(AppTheme.red)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 生成按钮
            generateButton
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
    }

    // MARK: - 生成按钮
    private var generateButton: some View {
        Button {
            let dest = vm.destination.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !dest.isEmpty else { return }
            // 立刻回调让地图开始动画，sheet 关闭，AI 在后台跑
            onStartAnimation?(dest)
            dismiss()
            Task { await vm.generate(context: modelContext) }
        } label: {
            HStack(spacing: 8) {
                if vm.isGenerating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.8)
                    Text(vm.generationPhase.message.isEmpty ? "AI 生成中…" : vm.generationPhase.message)
                        .font(.system(size: 15, weight: .semibold))
                } else {
                    Image(systemName: "sparkles").font(.system(size: 14, weight: .semibold))
                    Text("AI 生成攻略").font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                vm.isValid
                    ? AnyShapeStyle(AppTheme.accentGradient)
                    : AnyShapeStyle(AppTheme.sectionBG)
            )
            .cornerRadius(AppTheme.cardRadius)
        }
        .disabled(!vm.isValid || vm.isGenerating)
    }

    // MARK: - 风格 chip
    private func styleChip(_ style: NewTripViewModel.TravelStyle) -> some View {
        let selected = vm.selectedStyle == style
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                vm.selectedStyle = style
            }
        } label: {
            Text(style.rawValue)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selected ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(AppTheme.sectionBG))
                .foregroundColor(selected ? .white : AppTheme.textSecondary)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? AppTheme.accent.opacity(0.4) : AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(AccentButtonStyle())
    }
}
