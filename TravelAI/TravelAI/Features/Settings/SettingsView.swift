import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("travelai.provider")           private var provider: String = "minimax"
    @AppStorage("travelai.apiKey")             private var apiKey: String = ""
    @AppStorage("travelai.geminiKey")          private var geminiKey: String = ""
    @AppStorage("travelai.model")              private var model: String = "MiniMax-M2.5-highspeed"
    @AppStorage("travelai.defaultTravelStyle") private var defaultTravelStyle: String = "文化探索"
    @AppStorage("travelai.defaultTransport")   private var defaultTransport: String = "plane"

    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]

    @State private var showClearAlert = false

    private let travelStyles = ["文化探索", "自然风光", "美食之旅", "历史遗迹", "城市漫步", "亲子游", "浪漫蜜月"]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBGGradient.ignoresSafeArea()
                List {
                    // AI 服务
                    Section {
                        pickerRow(label: "服务商") {
                            Picker("", selection: $provider) {
                                Text("Claude").tag("claude")
                                Text("MiniMax").tag("minimax")
                                Text("Gemini").tag("gemini")
                            }.tint(AppTheme.gold)
                        }
                        if provider == "minimax" {
                            apiKeyRow(label: "API Key", placeholder: "sk-...", text: $apiKey)
                            textRow(label: "模型", placeholder: "MiniMax-M2.5", text: $model)
                        } else if provider == "gemini" {
                            apiKeyRow(label: "Gemini Key", placeholder: "AIzaSy...", text: $geminiKey)
                            staticRow(label: "模型", value: "gemini-2.5-flash")
                        } else {
                            staticRow(label: "模型", value: "claude-haiku-4-5")
                        }
                    } header: { sectionHeader("AI 服务", icon: "cpu") }

                    // 出行偏好
                    Section {
                        // 默认出行方式
                        VStack(alignment: .leading, spacing: 10) {
                            Text("默认出行方式")
                                .font(.subheadline).foregroundColor(AppTheme.textPrimary)
                            HStack(spacing: 10) {
                                ForEach(TransportMode.allCases, id: \.self) { mode in
                                    Button {
                                        defaultTransport = mode.rawValue
                                        TripInputController.shared.transportMode = mode
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: mode.icon)
                                                .font(.system(size: 18))
                                            Text(mode.label)
                                                .font(.system(size: 11, weight: .medium))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .foregroundColor(defaultTransport == mode.rawValue ? .white : AppTheme.textSecondary)
                                        .background(defaultTransport == mode.rawValue
                                            ? AnyShapeStyle(AppTheme.accentGradient)
                                            : AnyShapeStyle(AppTheme.cardBGAlt))
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .stroke(defaultTransport == mode.rawValue
                                                ? Color.clear : AppTheme.borderSubtle, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        // 默认游玩风格
                        VStack(alignment: .leading, spacing: 10) {
                            Text("默认游玩风格")
                                .font(.subheadline).foregroundColor(AppTheme.textPrimary)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(travelStyles, id: \.self) { style in
                                    Button {
                                        defaultTravelStyle = style
                                        TripInputController.shared.selectedStyle = style
                                    } label: {
                                        Text(style)
                                            .font(.system(size: 12, weight: .medium))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .foregroundColor(defaultTravelStyle == style ? .white : AppTheme.textSecondary)
                                            .background(defaultTravelStyle == style
                                                ? AnyShapeStyle(AppTheme.accentGradient)
                                                : AnyShapeStyle(AppTheme.cardBGAlt))
                                            .cornerRadius(8)
                                            .overlay(RoundedRectangle(cornerRadius: 8)
                                                .stroke(defaultTravelStyle == style
                                                    ? Color.clear : AppTheme.borderSubtle, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        staticRow(label: "输出语言", value: "中文")
                    } header: { sectionHeader("出行偏好", icon: "slider.horizontal.3") }

                    // 数据管理
                    Section {
                        Button { showClearAlert = true } label: {
                            HStack {
                                Image(systemName: "trash.fill").font(.subheadline).foregroundColor(AppTheme.red)
                                Text("清除所有旅行数据").font(.subheadline.bold()).foregroundColor(AppTheme.red)
                                Spacer()
                                Text("\(trips.count) 条记录").font(.caption).foregroundColor(AppTheme.textTertiary)
                            }
                        }.buttonStyle(.plain)
                    } header: { sectionHeader("数据管理", icon: "externaldrive") }

                    // 关于
                    Section {
                        staticRow(label: "版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        staticRow(label: "技术栈", value: "SwiftUI · SwiftData · MapKit")
                    } header: { sectionHeader("关于", icon: "info.circle") }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppTheme.navBG, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .alert("清除所有旅行数据", isPresented: $showClearAlert) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) { clearAllTrips() }
            } message: {
                Text("此操作不可撤销，所有旅行记录将被永久删除。")
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundColor(AppTheme.gold)
            Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundColor(AppTheme.textSecondary).tracking(0.8)
        }
    }

    @ViewBuilder
    private func pickerRow<Content: View>(label: String, @ViewBuilder picker: () -> Content) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(AppTheme.textPrimary)
            Spacer()
            picker()
        }
    }

    private func staticRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(AppTheme.textPrimary)
            Spacer()
            Text(value).font(.subheadline).foregroundColor(AppTheme.textSecondary)
        }
    }

    private func textRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(AppTheme.textPrimary)
            Spacer()
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.trailing)
                .font(.subheadline)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .frame(maxWidth: 160)
        }
    }

    @ViewBuilder
    private func apiKeyRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).foregroundColor(AppTheme.textPrimary)
            HStack(spacing: 8) {
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .foregroundColor(AppTheme.textSecondary)
                    .font(.system(size: 12, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(maxWidth: .infinity)
                if !text.wrappedValue.isEmpty {
                    Image(systemName: "checkmark.circle.fill").font(.caption).foregroundColor(AppTheme.teal)
                }
            }
            .padding(8)
            .background(AppTheme.cardBGAlt)
            .cornerRadius(8)
        }
        .padding(.vertical, 2)
    }

    private func clearAllTrips() {
        for trip in trips { modelContext.delete(trip) }
        try? modelContext.save()
    }
}

#Preview {
    SettingsView().modelContainer(for: [Trip.self])
}
