import SwiftUI
import SwiftData

struct SettingsView: View {
    // AI 服务配置
    @AppStorage("travelai.apiKey")      private var apiKey: String = ""
    @AppStorage("travelai.baseURL")     private var baseURL: String = "https://api.minimax.chat/v1/text/chatcompletion_v2"
    @AppStorage("travelai.model")       private var model: String = "MiniMax-M1"
    // 生成偏好
    @AppStorage("travelai.defaultStyle") private var defaultStyle: String = "cultural"

    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]

    @State private var showClearAlert = false
    @State private var showApiKey = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                Form {
                    // MARK: AI 服务
                    Section {
                        // API Key
                        HStack {
                            Text("API Key")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            if showApiKey {
                                TextField("sk-...", text: $apiKey)
                                    .textFieldStyle(.plain)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .multilineTextAlignment(.trailing)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            } else {
                                SecureField("sk-...", text: $apiKey)
                                    .textFieldStyle(.plain)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .multilineTextAlignment(.trailing)
                            }
                            Button {
                                showApiKey.toggle()
                            } label: {
                                Image(systemName: showApiKey ? "eye.slash" : "eye")
                                    .foregroundColor(AppTheme.textSecondary)
                                    .font(.caption)
                            }
                        }

                        // 模型
                        HStack {
                            Text("模型")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            TextField("MiniMax-M1", text: $model)
                                .textFieldStyle(.plain)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        // Base URL
                        HStack {
                            Text("Base URL")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            TextField("https://...", text: $baseURL)
                                .textFieldStyle(.plain)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.caption)
                        }
                    } header: {
                        Text("AI 服务")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // MARK: 生成偏好
                    Section {
                        Picker("默认风格", selection: $defaultStyle) {
                            Text("文化深度").tag("cultural")
                            Text("休闲").tag("leisure")
                            Text("探险").tag("adventure")
                        }
                        .foregroundColor(AppTheme.textPrimary)
                        .tint(AppTheme.gold)

                        HStack {
                            Text("语言")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("中文")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    } header: {
                        Text("生成偏好")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // MARK: 数据管理
                    Section {
                        Button(role: .destructive) {
                            showClearAlert = true
                        } label: {
                            Text("清除所有旅行数据")
                        }
                    } header: {
                        Text("数据管理")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // MARK: 关于
                    Section {
                        HStack {
                            Text("版本")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    } header: {
                        Text("关于")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .listRowBackground(AppTheme.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .alert("清除所有旅行数据", isPresented: $showClearAlert) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    clearAllTrips()
                }
            } message: {
                Text("此操作不可撤销，所有旅行记录将被永久删除。")
            }
        }
    }

    private func clearAllTrips() {
        for trip in trips {
            modelContext.delete(trip)
        }
        try? modelContext.save()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Trip.self])
}
