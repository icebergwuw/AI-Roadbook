---
title: TravelAI Project Overview
tags: [ios, swiftui, ai, travel, swiftdata, mapkit, photos, liquid-glass, ios26]
date: 2026-04-18
status: active-development
---

# TravelAI — Project Overview

## Summary

TravelAI 是面向中文用户的 AI 旅行规划 iOS 应用。用户在主界面输入目的地，飞机立即起飞动画飞向目的地，同时 AI 在后台生成多天行程攻略并保存。支持文化知识图谱、每日地图路线、AI 聊天修改行程、照片记忆光点等功能。

当前处于**功能迭代阶段**：核心流程已通，正在修复 Trip 保存问题和 UI 细节。

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | SwiftUI (iOS 26+) |
| UI 风格 | **Apple Liquid Glass**（`.glassEffect(.regular, in:)`）|
| Persistence | SwiftData (`@Model`, cascade delete) |
| State Management | `@Observable` (Swift 5.9) |
| Networking | `async/await` + 自定义 `URLSession`（ephemeral，防模拟器挂起）|
| AI Provider | MiniMax-M2.5-highspeed（默认）/ Gemini 2.5 Flash（备用）|
| Maps | MapKit — `Map()` + `.hybrid(elevation: .realistic)` 3D 卫星地图 |
| Location | `CoreLocation` (`CLLocationManager`) |
| Photos | `Photos` framework (`PHAsset` GPS 读取) |
| Min Deployment | iOS 26+ |
| Dependencies | 无（纯 Apple 框架）|

---

## UI 设计原则（重要）

### Liquid Glass 优先

**所有 UI 元素使用 Apple iOS 26 原生 Liquid Glass**，让元素自然融入地图背景：

```swift
// 按钮
.glassEffect(.regular, in: .circle)
.glassEffect(.regular, in: .capsule)
// 输入框、卡片
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
```

**例外**：进度卡片、日志面板等高对比度信息区域，用深色半透明背景（`opacity:0.92` + `.ultraThinMaterial`）。

### 常驻底部输入栏

`TravelInputBar` 出现在所有页面底部，共享 `TripInputController.shared` 单例状态。

---

## Architecture

### 导航模型

```
TravelAIApp
└── ContentView
    └── HomeView（全屏地图 + 常驻输入栏）
          ├── sheet: TripListSheet（行程列表 + 相同输入栏）
          └── NavigationLink: TripDetailView
                └── (top tab bar)
                      ├── ItineraryView
                      ├── CultureView
                      ├── TripMapView
                      ├── ChatView
                      └── ToolsView
```

### 输入流程（聊天气泡式）

```
TravelInputBar（常驻底部）
  .idle   → 用户输入目的地 → 点发送
  .date   → AI气泡问"几天？" → 用户选天数+日期 → 点发送
  .style  → AI气泡问"什么风格？" → 用户选 → 点发送
  .confirm→ AI气泡确认 → 触发生成
```

### 生成数据流

```
TripInputController.onStartGeneration(dest, date, days, style)
  → HomeView.startGeneration()
  → FlightRouteAnimator.startPreview()     ← 立即飞行动画
  → NewTripViewModel.generate(context:)    ← 异步 AI 生成
      → AIService.generateTrip()          ← MiniMax API
      → cleanJSON() / repairTruncatedJSON()
      → AIResponseParser.parse()
      → 内联写入 SwiftData + context.save()
      → onPhaseChanged(.done)
  → FlightRouteAnimator.continueWithItinerary()  ← 行程路线动画
```

### SwiftData 模型图

```
Trip
├── [TripDay] → [TripEvent]   (lat/lng GPS 坐标)
├── [ChecklistItem]
├── CultureData → [CultureNode]
├── [Tip]
├── [SOSContact]
└── [Message]
```

---

## 功能模块状态

| 模块 | 文件 | 状态 | 说明 |
|---|---|---|---|
| 主地图界面 | `HomeView.swift` + `GlobeView.swift` | ✅ | Liquid Glass UI，飞行动画，照片光点 |
| 常驻输入栏 | `TravelInputBar.swift` | ✅ | 聊天气泡流程，全局复用 |
| 全局输入状态 | `TripInputController.swift` | ✅ | `@Observable` 单例，预填随机目的地 |
| 行程列表 | `TripListSheet`（HomeView.swift 内）| ✅ | 含相同输入栏 |
| 新建旅行 VM | `NewTripViewModel.swift` | ✅ | 生成阶段机，SwiftData 写入 |
| 行程详情 | `TripDetailView.swift` | ✅ | 顶部 tab 导航 |
| 每日行程 | `ItineraryView.swift` | ✅ | 时间轴 + 清单 |
| 文化知识图谱 | `CultureView.swift` | ✅ | 树形节点 |
| 行程地图 | `TripMapView.swift` | ✅ | Day 选择器 + Polyline |
| AI 聊天 | `ChatView.swift` | ✅ | JSON patch 修改行程 |
| 工具箱 | `ToolsView.swift` | ✅ | 清单/SOS/贴士 |
| 照片记忆光点 | `PhotoMemoryService.swift` | ✅ | 相册GPS，MapKit Annotation |
| 飞行路线动画 | `FlightRouteAnimator.swift` | ✅ | 硬编码坐标字典 + SLERP |
| Trip 保存 | `NewTripViewModel.generate()` | 🔧 调试中 | cleanJSON后JSON结构待验证 |

---

## 服务层关键点

### FlightRouteAnimator — 地理编码

**内置100+目的地硬编码坐标字典**，完全绕过 CLGeocoder 对中文地名的误判：
- "冰岛"→ Iceland (64.96, -19.02) 而非内蒙古
- "摩洛哥"→ Morocco (31.79, -7.09) 而非浙江
- CLGeocoder 仅作 fallback，且会过滤掉落在中国大陆的结果

### AIService — JSON 处理

1. `cleanJSON()`：剥离 `<think>` 标签、去 markdown 代码块、修复 AI 常见 JSON bug
2. `repairTruncatedJSON()`：`finish_reason=length` 时补全括号
3. 调试：`extractMiniMax` 把 cleaned JSON 写入 app Documents 目录

### URLSession 配置

```swift
// ephemeral session，防止模拟器 URLSession 永久挂起
let cfg = URLSessionConfiguration.ephemeral
cfg.timeoutIntervalForRequest  = 60   // 单次读写
cfg.timeoutIntervalForResource = 310  // 总超时
cfg.waitsForConnectivity = false
```

---

## 权限声明

| 权限 | 用途 |
|---|---|
| `NSLocationWhenInUseUsageDescription` | 地图显示当前位置 + 飞行动画起点 |
| `NSPhotoLibraryUsageDescription` | 读取照片位置信息显示人生轨迹光点 |

---

## 已知问题

1. **Trip 生成后不保存** — 正在调试：MiniMax cleaned JSON 结构需验证
2. **生成偶发 300s 卡住** — 模拟器 URLSession 问题，真机正常
3. **飞行结束后地图复位** — 应停留在目的地，待修复

---

## 相关文档

- `DEEPV.md` — 项目总纲（UI原则、技术规范、版本历史）
- `DESIGN.md` — Claude 设计系统参考
- `docs/superpowers/plans/2026-04-07-ios-app.md` — 原始任务清单
- `docs/superpowers/specs/2026-04-07-ai-travel-app-design.md` — 产品设计规格


## Summary

TravelAI 是面向中文用户的 AI 旅行规划 iOS 应用。用户在主界面输入目的地，AI 自动生成多天行程攻略，支持文化知识图谱、每日地图路线、AI 聊天修改行程、行程工具箱（清单/SOS/贴士）等功能。

当前处于**功能迭代阶段**：核心生成流程已通，主界面完成地图化改造，正在迭代 UX 细节。

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | SwiftUI (iOS 17+) |
| Persistence | SwiftData (`@Model`, cascade delete) |
| State Management | `@Observable` (Swift 5.9) |
| Networking | `async/await` + `URLSession` |
| AI Provider | MiniMax-M2.5（直连 API，无 Supabase 代理） |
| Maps | MapKit — `Map()` + `.hybrid(elevation: .realistic)` 3D 地球 |
| Location | `CoreLocation` (`CLLocationManager`) |
| Photos | `Photos` framework (`PHAsset` GPS 读取) |
| Min Deployment | iOS 17+ |
| Dependencies | 无（纯 Apple 框架） |

---

## Architecture

### 导航模型

```
ContentView
└── HomeView (全屏地图 + 输入栏)
      ├── sheet: NewTripView          ← bottom sheet (half-screen)
      ├── sheet: TripListSheet        ← 行程列表
      └── NavigationLink: TripDetailView
            └── (top tab bar)
                  ├── ItineraryView
                  ├── CultureView
                  ├── TripMapView
                  ├── ChatView
                  └── ToolsView
```

### HomeView 布局层次（ZStack）

```
GlobeView (MapKit 全屏底层)
  ├── 照片记忆光点层 (Canvas, PhotoMemoryService)
  ├── 飞行路线动画层 (FlightRouteAnimator)
  └── 飞机图标浮层
topBar (毛玻璃胶囊)
generatingFloatCard (生成进度，悬浮在地图上)
bottomInputBar (毛玻璃输入栏，随键盘上移)
```

### 数据流

```
用户输入目的地（HomeView 输入栏）
  → sendQuery() → prefilledQuery
  → NewTripView(prefilled:) bottom sheet 弹出
  → 确认日期 + 风格 → "AI 生成攻略"
  → NewTripViewModel.generate(context:)
  → AIService.generateTrip()  ←  MiniMax-M2.5 API
  → cleanJSON()（剥离 <think>，修复 AI JSON bug）
  → AIResponseParser.parse(json:)
  → ParsedTrip.insertInto(context:)
  → SwiftData 持久化
  → onPhaseChanged 回调 → HomeView 悬浮进度卡片更新
  → onComplete 回调 → FlightRouteAnimator.start() 触发飞行动画
```

### SwiftData 模型图

```
Trip
├── [TripDay] → [TripEvent]   (lat/lng GPS 坐标)
├── [ChecklistItem]           (dayIndex 可关联到具体天)
├── CultureData → [CultureNode]  (parentId 树形结构)
├── [Tip]
├── [SOSContact]
└── [Message]                 (AI 对话历史)
```

所有子模型均设置 `deleteRule: .cascade`。

---

## 功能模块状态

| 模块 | 文件 | 状态 | 说明 |
|---|---|---|---|
| 主地图界面 | `HomeView.swift` + `GlobeView.swift` | ✅ 完整 | MapKit 3D 地球、照片光点、飞行动画、键盘跟随 |
| 新建旅行 | `NewTripView.swift` + `NewTripViewModel.swift` | ✅ 完整 | half-screen sheet、目的地预填、进度回调 |
| 行程列表 | `TripListSheet`（内嵌 HomeView.swift） | ✅ 完整 | |
| 行程详情 | `TripDetailView.swift` | ✅ 完整 | 顶部 tab 导航 |
| 每日行程 | `ItineraryView.swift` | ✅ 完整 | 时间轴 + 清单 |
| 文化知识图谱 | `CultureView.swift` | ✅ 完整 | 树形节点图谱 |
| 行程地图 | `TripMapView.swift` + `TripMapViewModel.swift` | ✅ 完整 | Day 选择器 + Polyline + 导航 |
| AI 聊天 | `ChatView.swift` | ✅ 完整 | JSON patch 修改行程 |
| 工具箱 | `ToolsView.swift` | ✅ 完整 | 清单/SOS/贴士 |
| 照片记忆光点 | `PhotoMemoryService.swift` | ✅ 完整 | 相册GPS读取，Canvas 渲染热力点 |
| 飞行路线动画 | `FlightRouteAnimator.swift` | ✅ 完整 | 球面弧线插值，自动找最近机场 |

---

## 服务层

### AIService.swift
- 直连 MiniMax-M2.5 API（`api.minimaxi.com/v1/chat/completions`）
- `generateTrip()` — 生成完整行程 JSON，带**重试机制**（最多 2 次）
- `chat()` — 对话修改行程，返回 JSON patch 格式
- `cleanJSON()` — 处理 AI 输出问题：
  - 剥离 `<think>...</think>` 推理内容
  - 去除 markdown 代码块
  - 修复数字后多余引号（`6"` → `6`）
  - 修复数组元素重复花括号（`},{"{` → `},{"`）

### AIResponseParser.swift
- 将 AI 返回 JSON 解析为 `ParsedTrip` 纯结构体（线程安全）
- `ParsedTrip.insertInto(context:)` 写入 SwiftData

### PhotoMemoryService.swift
- 请求 `PHPhotoLibrary` 权限
- 枚举全部图片 `PHAsset`，提取有效 GPS 坐标
- 按 0.3° 格子聚合为 `[PhotoCluster]`（避免数万点卡顿）
- 热力映射：1-2 张=白点，3-9=淡橙，10-29=橙，30+=亮橙大光晕

### FlightRouteAnimator.swift
- `start(origin:destination:destinationName:itinerary:)` 异步驱动全流程
- 球面大圆弧插值（SLERP）计算飞行路径
- `MKLocalSearch` 自动搜索出发地最近机场
- 分阶段：地面→机场 → 飞行弧线 → 目的地落地 → 每日行程路线

### LocationManager.swift
- `@Observable`，单次定位（获取后 `stopUpdatingLocation`）
- 精度 1km，用于主地图中心 + 飞行动画起点

---

## 设计系统（AppTheme.swift）

参照 Claude 设计语言，核心参数：

| Token | Value |
|---|---|
| 强调色 | Terracotta `#c96442` |
| 背景 | 纸白 `#FAF9F7` |
| 深色文字 | `#1d1d1f` |
| 卡片圆角 | 16pt |
| 基础间距 | 20pt |
| 毛玻璃 | `.ultraThinMaterial` |

地图叠加层（HomeView）统一用白色文字 + `.ultraThinMaterial` 背景。

---

## 权限声明

| 权限 | 用途 |
|---|---|
| `NSLocationWhenInUseUsageDescription` | 在地球上显示当前位置 |
| `NSPhotoLibraryUsageDescription` | 读取照片位置信息显示人生轨迹光点 |

---

## 已知问题 / 待优化

1. **照片光点投影精度** — `GlobeView` 的 `projectCoordinate()` 使用线性近似，在高纬度或极远镜头下有偏差，3D 地球曲率未补偿
2. **飞行动画在模拟器** — 模拟器无真实照片，需真机测试光点；飞行动画可在模拟器验证
3. **AI JSON 偶发格式错误** — `cleanJSON()` 已处理已知 bug，但 MiniMax-M2.5 可能产生其他格式错误；重试机制兜底
4. **SwiftData schema 迁移** — `TravelAIApp.swift` 实现了自动清库（`wipeStore()`），仅适用开发阶段；上线前需实现正式迁移
5. **Chat JSON patch** — `AIService.chat()` 返回 patch 格式，`ChatView` 解析并应用到行程，需验证复杂修改场景

---

## 文件结构

```
TravelAI/
├── TravelAIApp.swift              # App 入口，SwiftData ModelContainer
├── Assets.xcassets/
├── Theme/
│   └── AppTheme.swift             # 设计系统（色板/字体/阴影/圆角）
├── Models/
│   ├── Trip.swift                 # Trip / TripDay / TripEvent
│   ├── ChecklistItem.swift
│   ├── CultureData.swift          # CultureData / CultureNode
│   ├── Message.swift
│   └── SOSContact.swift           # SOSContact / Tip
├── Services/
│   ├── AIService.swift            # MiniMax API + cleanJSON + retry
│   ├── AIResponseParser.swift     # JSON → ParsedTrip → SwiftData
│   ├── LocationManager.swift      # CLLocationManager (@Observable)
│   ├── PhotoMemoryService.swift   # 相册GPS读取 + 热力聚合
│   └── FlightRouteAnimator.swift  # 飞行路线动画（SLERP + MKLocalSearch）
└── Features/
    ├── Home/
    │   ├── HomeView.swift         # 主界面（地图+输入+进度浮层）
    │   └── GlobeView.swift        # MapKit 3D 地球（照片光点+飞行层）
    ├── NewTrip/
    │   ├── NewTripView.swift      # half-screen bottom sheet
    │   └── NewTripViewModel.swift # 生成流程 + 阶段回调
    ├── TripDetail/
    │   └── TripDetailView.swift
    ├── Itinerary/
    ├── Culture/
    ├── Map/
    │   ├── TripMapView.swift
    │   └── TripMapViewModel.swift
    ├── Chat/
    └── Tools/
```

---

## 相关文档

- `docs/superpowers/plans/2026-04-07-ios-app.md` — 原始实施任务清单
- `docs/superpowers/specs/2026-04-07-ai-travel-app-design.md` — 产品/设计规格
- `.llm-wiki/wiki/design-system.md` — 设计系统规范
