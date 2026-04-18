# TravelAI — 行程 Tab & 设置 Tab 补全设计

**日期：** 2026-04-10
**状态：** 已确认，待实施

---

## 1. 背景

当前 `ContentView.swift` 中，底部 TabBar 的「行程」「探索」「设置」三个 Tab 均为 `Text()` 占位符。「探索」Tab 留待后期，本次补全以下两个：

- **行程 Tab** — 今日概览 Dashboard
- **设置 Tab** — AI 配置 + 生成偏好 + 数据管理

---

## 2. 行程 Tab — 今日概览 Dashboard

### 2.1 功能描述

点击底部「行程」Tab，显示当前进行中（或最近一次）旅行的**今日概览**。

### 2.2 有旅行时的布局

```
┌─────────────────────────────┐
│  埃及之旅                    │  ← 旅行名
│  今天 · 3月29日  Day 4/10   │  ← 日期 + Day N/总天数
├─────────────────────────────┤
│  今日行程                    │
│  ● 09:00  卡纳克神庙        │
│  ● 13:00  尼罗河午餐游轮    │
│  ● 19:00  帝王谷夜游        │
├─────────────────────────────┤
│  今日待办  2 / 5 完成        │
│  [████░░░░░░]               │  ← 进度条
├─────────────────────────────┤
│  [查看完整行程 →]            │  ← 跳转 TripDetailView
└─────────────────────────────┘
```

### 2.3 无旅行时的空态

```
┌─────────────────────────────┐
│                             │
│       🗺️                   │
│   还没有旅行计划             │
│   [+ 新建旅行]              │  ← 跳转 NewTripView
│                             │
└─────────────────────────────┘
```

### 2.4 数据逻辑

- 用 `@Query(sort: \\.createdAt, order: .reverse)` 获取所有旅行，取第一条（最近创建）
- 根据 `Date()` 匹配对应的 `TripDay`：找 `tripDay.date` 与今天同一天的那条；若无匹配（旅行已结束或未开始），显示第一天的内容并标注"旅行未在进行中"
- 今日待办：筛选 `trip.checklist` 中 `dayIndex` 匹配当天 `sortIndex` 的条目，统计完成数

### 2.5 交互

- 整个卡片或「查看完整行程」按钮 → `NavigationLink` 跳转到 `TripDetailView(trip:)`
- 空态「新建旅行」按钮 → 切换到新建 Tab（通过 `@Binding selectedTab`）

### 2.6 新增文件

- `TravelAI/Features/TodayOverview/TodayOverviewView.swift`

---

## 3. 设置 Tab

### 3.1 功能描述

管理 AI 服务配置和 App 偏好，解决 API Key 硬编码问题——Key 改为存 `UserDefaults`，`AIService` 启动时读取。

### 3.2 布局（三个 Section）

```
┌─────────────────────────────┐
│  AI 服务                    │  Section Header
│  API Key      [sk-••••••]   │  SecureField，可编辑
│  模型         [MiniMax-M1]  │  TextField，可编辑
│  Base URL     [api.mini…]   │  TextField，可编辑
├─────────────────────────────┤
│  生成偏好                   │  Section Header
│  默认风格     文化深度 ›    │  Picker：文化深度/休闲/探险
│  语言         中文          │  只读，固定中文
├─────────────────────────────┤
│  数据管理                   │  Section Header
│  清除所有旅行数据            │  红色文字，点击弹 Alert 确认
└─────────────────────────────┘
```

### 3.3 数据存储

所有设置项存 `UserDefaults`（key 前缀 `travelai.`）：

| UserDefaults Key | 类型 | 默认值 |
|---|---|---|
| `travelai.apiKey` | String | `""` （原硬编码值迁移） |
| `travelai.baseURL` | String | `"https://api.minimax.chat/v1/text/chatcompletion_v2"` |
| `travelai.model` | String | `"MiniMax-M1"` |
| `travelai.defaultStyle` | String | `"cultural"` |

用 `@AppStorage` 属性包装器直接绑定到 UI。

### 3.4 AIService 改动

移除硬编码 API Key，改为：

```swift
// AIService.swift
private static var apiKey: String {
    UserDefaults.standard.string(forKey: "travelai.apiKey") ?? ""
}
private static var baseURL: String {
    UserDefaults.standard.string(forKey: "travelai.baseURL") ?? "https://api.minimax.chat/v1/text/chatcompletion_v2"
}
private static var model: String {
    UserDefaults.standard.string(forKey: "travelai.model") ?? "MiniMax-M1"
}
```

### 3.5 清除数据逻辑

点击「清除所有旅行数据」→ Alert 确认 → 通过 `@Environment(\.modelContext)` 删除所有 `Trip` 对象（cascade 删除会清理关联数据）。

### 3.6 新增文件

- `TravelAI/Features/Settings/SettingsView.swift`

---

## 4. ContentView 改动

### 4.1 Tab 切换协调

为支持空态「新建旅行」按钮切换 Tab，`ContentView` 需要一个共享的 `@State var selectedTab: Int`：

```swift
@State private var selectedTab = 0

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
    // 探索：继续占位
    NavigationStack { Text("探索").foregroundColor(AppTheme.textPrimary) }
        .tabItem { Label("探索", systemImage: "safari.fill") }
        .tag(3)
    SettingsView()
        .tabItem { Label("设置", systemImage: "gearshape.fill") }
        .tag(4)
}
```

---

## 5. 不在本次范围内

- 探索 Tab（后期）
- 单元测试（独立任务）
- iCloud 同步

---

## 6. 文件变更清单

| 操作 | 文件 |
|------|------|
| 新增 | `TravelAI/Features/TodayOverview/TodayOverviewView.swift` |
| 新增 | `TravelAI/Features/Settings/SettingsView.swift` |
| 修改 | `TravelAI/ContentView.swift` |
| 修改 | `TravelAI/Services/AIService.swift` |
