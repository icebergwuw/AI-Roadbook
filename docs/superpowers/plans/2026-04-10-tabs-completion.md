# 行程 Tab & 设置 Tab 补全 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补全 TravelAI 底部 TabBar 中的「行程」Tab（今日概览 Dashboard）和「设置」Tab（AI配置 + 生成偏好 + 数据管理），并将 AIService 中的硬编码 API Key 迁移到 UserDefaults。

**Architecture:** 新增 `TodayOverviewView` 和 `SettingsView` 两个独立 View，不引入 ViewModel（数据简单，直接用 `@Query` + `@AppStorage`）。`ContentView` 改用 `@State selectedTab` 管理 Tab 切换。`AIService` 改为从 UserDefaults 动态读取配置。

**Tech Stack:** Swift 5.10+, SwiftUI, SwiftData (`@Query`, `@Environment(\.modelContext)`), `@AppStorage` (UserDefaults), Xcode 16+

**Spec:** `docs/superpowers/specs/2026-04-10-tabs-completion-design.md`

---

## 文件变更清单

| 操作 | 文件 | 职责 |
|------|------|------|
| 新增 | `TravelAI/Features/TodayOverview/TodayOverviewView.swift` | 行程 Tab 今日概览 |
| 新增 | `TravelAI/Features/Settings/SettingsView.swift` | 设置 Tab |
| 修改 | `TravelAI/ContentView.swift` | 接入两个新 View，加 selectedTab 状态 |
| 修改 | `TravelAI/Services/AIService.swift` | 移除硬编码，改读 UserDefaults |

---

## Task 1: 更新 ContentView — 加入 selectedTab 状态

**Files:**
- Modify: `TravelAI/ContentView.swift`

- [ ] **Step 1: 读取当前 ContentView.swift 内容（已完成，已知内容）**

- [ ] **Step 2: 将 ContentView 改为带 selection 的 TabView**

将 `TravelAI/ContentView.swift` 全部替换为：

```swift
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(0)

            TodayOverviewView(selectedTab: $selectedTab)
                .tabItem { Label("行程", systemImage: "calendar") }
                .tag(1)

            NewTripView()
                .tabItem { Label("新建", systemImage: "plus.circle.fill") }
                .tag(2)

            NavigationStack {
                Text("探索")
                    .foregroundColor(AppTheme.textPrimary)
            }
            .tabItem { Label("探索", systemImage: "safari.fill") }
            .tag(3)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(AppTheme.gold)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 3: 编译确认（此时 TodayOverviewView / SettingsView 未定义，预期报错）**

Xcode 会报 `Cannot find type 'TodayOverviewView'` 和 `Cannot find type 'SettingsView'`，这是正常的，继续下一个 Task。

---

## Task 2: 新建 TodayOverviewView

**Files:**
- Create: `TravelAI/Features/TodayOverview/TodayOverviewView.swift`

此 View 读取最近一条旅行，展示今日行程和待办进度。

- [ ] **Step 1: 在 Xcode 中创建目录和文件**

在 `TravelAI/Features/` 下新建 Group `TodayOverview`，然后在其中新建 Swift 文件 `TodayOverviewView.swift`。

- [ ] **Step 2: 写入完整实现**

```swift
import SwiftUI
import SwiftData

struct TodayOverviewView: View {
    @Binding var selectedTab: Int
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @Environment(\.modelContext) private var modelContext

    private var latestTrip: Trip? { trips.first }

    private var todayDay: TripDay? {
        guard let trip = latestTrip else { return nil }
        let calendar = Calendar.current
        return trip.days
            .sorted { $0.sortIndex < $1.sortIndex }
            .first { calendar.isDateInToday($0.date) }
    }

    private var displayDay: TripDay? {
        guard let trip = latestTrip else { return nil }
        return todayDay ?? trip.days.sorted { $0.sortIndex < $1.sortIndex }.first
    }

    private var isTodayActive: Bool { todayDay != nil }

    private var dayIndex: Int {
        guard let trip = latestTrip, let day = displayDay else { return 1 }
        return (trip.days.sorted { $0.sortIndex < $1.sortIndex }.firstIndex(where: { $0.persistentModelID == day.persistentModelID }) ?? 0) + 1
    }

    private var totalDays: Int { latestTrip?.days.count ?? 0 }

    private var todayChecklist: [ChecklistItem] {
        guard let trip = latestTrip, let day = displayDay else { return [] }
        let idx = trip.days.sorted { $0.sortIndex < $1.sortIndex }
            .firstIndex(where: { $0.persistentModelID == day.persistentModelID }) ?? 0
        return trip.checklist.filter { $0.dayIndex == idx }
    }

    private var completedCount: Int { todayChecklist.filter { $0.isCompleted }.count }
    private var totalCount: Int { todayChecklist.count }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if let trip = latestTrip, let day = displayDay {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // 旅行标题
                            tripHeader(trip: trip, day: day)

                            // 今日行程
                            eventsSection(day: day)

                            // 今日待办
                            if totalCount > 0 {
                                checklistSection()
                            }

                            // 跳转按钮
                            NavigationLink(destination: TripDetailView(trip: trip)) {
                                HStack {
                                    Text("查看完整行程")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppTheme.background)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(AppTheme.background)
                                }
                                .padding()
                                .background(AppTheme.gold)
                                .cornerRadius(AppTheme.cardRadius)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                    }
                } else {
                    emptyState()
                }
            }
            .navigationTitle("行程")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func tripHeader(trip: Trip, day: TripDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.destination)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.gold)

            HStack(spacing: 8) {
                Text(formattedToday())
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)

                Text("·")
                    .foregroundColor(AppTheme.textSecondary)

                Text("Day \(dayIndex)/\(totalDays)")
                    .font(.subheadline)
                    .foregroundColor(isTodayActive ? AppTheme.gold : AppTheme.textSecondary)

                if !isTodayActive {
                    Text("（旅行未在进行中）")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func eventsSection(day: TripDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日行程")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal)

            let events = day.events.sorted { $0.sortIndex < $1.sortIndex }
            if events.isEmpty {
                Text("暂无行程安排")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.persistentModelID) { idx, event in
                        HStack(alignment: .top, spacing: 12) {
                            // 时间线圆点 + 竖线
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(eventColor(for: event.eventType))
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 4)
                                if idx < events.count - 1 {
                                    Rectangle()
                                        .fill(AppTheme.border)
                                        .frame(width: 1)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(event.time)
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                    Text("·")
                                        .foregroundColor(AppTheme.textSecondary)
                                    Text(event.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                                if !event.locationName.isEmpty {
                                    Label(event.locationName, systemImage: "mappin")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.cardRadius)
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func checklistSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日待办")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(completedCount) / \(totalCount) 完成")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.border)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.gold)
                        .frame(
                            width: totalCount > 0
                                ? geo.size.width * CGFloat(completedCount) / CGFloat(totalCount)
                                : 0,
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cardRadius)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func emptyState() -> some View {
        VStack(spacing: 20) {
            Text("🗺️")
                .font(.system(size: 60))
            Text("还没有旅行计划")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.textPrimary)
            Text("创建你的第一个旅行攻略")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            Button {
                selectedTab = 2
            } label: {
                Label("新建旅行", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.background)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.gold)
                    .cornerRadius(AppTheme.cardRadius)
            }
        }
    }

    // MARK: - Helpers

    private func formattedToday() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return "今天 · " + f.string(from: Date())
    }

    private func eventColor(for type: String) -> Color {
        switch type {
        case "transport":     return AppTheme.textSecondary
        case "food":          return AppTheme.goldSecondary
        case "accommodation": return AppTheme.goldSecondary
        default:              return AppTheme.gold  // attraction
        }
    }
}

#Preview {
    TodayOverviewView(selectedTab: .constant(1))
        .modelContainer(for: [Trip.self, TripDay.self, TripEvent.self, ChecklistItem.self])
}
```

- [ ] **Step 3: 编译，确认 TodayOverviewView 编译通过（SettingsView 仍报错，正常）**

---

## Task 3: 新建 SettingsView

**Files:**
- Create: `TravelAI/Features/Settings/SettingsView.swift`

- [ ] **Step 1: 在 Xcode 中创建目录和文件**

在 `TravelAI/Features/` 下新建 Group `Settings`，然后新建 `SettingsView.swift`。

- [ ] **Step 2: 写入完整实现**

```swift
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
```

- [ ] **Step 3: 编译，确认两个新 View 均编译通过，ContentView 报错消除**

---

## Task 4: 更新 AIService — 移除硬编码，改读 UserDefaults

**Files:**
- Modify: `TravelAI/Services/AIService.swift`

- [ ] **Step 1: 将 AIService 开头的三个 `static let` 改为从 UserDefaults 动态读取**

将以下三行：

```swift
private static let apiKey = "sk-cp-UeAsUVnn0oFByLJjHCI3bUFLU4_t69n3nqvRshLiY1BePgzxNVUI2ThqZmgfSzha1SMVnWJjwP91SJ1Cnbtbtse5mq3BZPGnm2LQGlrR_5DWT7zpuLoLsKA"
private static let baseURL = "https://api.minimax.chat/v1/text/chatcompletion_v2"
private static let model = "MiniMax-M1"
```

替换为：

```swift
private static var apiKey: String {
    let stored = UserDefaults.standard.string(forKey: "travelai.apiKey") ?? ""
    // 首次启动时迁移硬编码 key
    if stored.isEmpty {
        let fallback = "sk-cp-UeAsUVnn0oFByLJjHCI3bUFLU4_t69n3nqvRshLiY1BePgzxNVUI2ThqZmgfSzha1SMVnWJjwP91SJ1Cnbtbtse5mq3BZPGnm2LQGlrR_5DWT7zpuLoLsKA"
        UserDefaults.standard.set(fallback, forKey: "travelai.apiKey")
        return fallback
    }
    return stored
}
private static var baseURL: String {
    UserDefaults.standard.string(forKey: "travelai.baseURL")
        ?? "https://api.minimax.chat/v1/text/chatcompletion_v2"
}
private static var model: String {
    UserDefaults.standard.string(forKey: "travelai.model") ?? "MiniMax-M1"
}
```

- [ ] **Step 2: 更新 `generateTrip` 中使用 `style` 参数的地方，改为优先用 UserDefaults 的 defaultStyle**

找到 `generateTrip` 函数签名：

```swift
static func generateTrip(
    destination: String,
    startDate: Date,
    endDate: Date,
    style: String = "cultural"
) async throws -> String {
```

将默认值改为读取 UserDefaults：

```swift
static func generateTrip(
    destination: String,
    startDate: Date,
    endDate: Date,
    style: String? = nil
) async throws -> String {
    let resolvedStyle = style
        ?? UserDefaults.standard.string(forKey: "travelai.defaultStyle")
        ?? "cultural"
```

同时将函数体内所有用到 `style` 变量的地方改为 `resolvedStyle`：

```swift
旅行风格：\(resolvedStyle)
```

- [ ] **Step 3: 编译，确认无报错**

- [ ] **Step 4: 在模拟器运行，进入设置 Tab，确认 API Key 字段显示已有值（迁移成功）**

- [ ] **Step 5: Commit**

```bash
git add TravelAI/TravelAI/Features/TodayOverview/TodayOverviewView.swift \
        TravelAI/TravelAI/Features/Settings/SettingsView.swift \
        TravelAI/TravelAI/ContentView.swift \
        TravelAI/TravelAI/Services/AIService.swift
git commit -m "feat: add TodayOverview and Settings tabs, migrate API key to UserDefaults"
```

---

## Task 5: 端到端验证

- [ ] **Step 1: 在模拟器运行 App**

- [ ] **Step 2: 验证「行程」Tab 空态**

无旅行数据时，「行程」Tab 应显示 🗺️ 空态和「新建旅行」按钮。点击按钮，底部 Tab 应切换到「新建」。

- [ ] **Step 3: 创建一条测试旅行**

点击「新建」，输入任意目的地和日期，点击「AI 生成攻略」，等待生成完成。

- [ ] **Step 4: 验证「行程」Tab 有数据时的展示**

生成完成后，切换到「行程」Tab，确认：
- 显示旅行名称和日期
- 显示某一天的行程事件列表
- 「查看完整行程」按钮可跳转到 TripDetailView

- [ ] **Step 5: 验证「设置」Tab**

切换到「设置」Tab，确认：
- API Key 字段有值（迁移自硬编码）
- 可修改模型名称
- 默认风格 Picker 可选择
- 「清除所有旅行数据」弹出 Alert

- [ ] **Step 6: 验证设置生效**

在设置中修改「默认风格」为「休闲」，返回新建 Tab，创建新旅行，确认 AI 生成的攻略风格偏休闲。

- [ ] **Step 7: Final commit（如有小修复）**

```bash
git add -A
git commit -m "fix: post-integration tweaks for tabs completion"
```
