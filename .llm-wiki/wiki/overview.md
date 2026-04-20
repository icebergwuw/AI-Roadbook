---
title: TravelAI Project Overview
tags: [ios, swiftui, ai, travel, swiftdata, mapkit, liquid-glass, ios26]
date: 2026-04-20
status: active-development
---

# TravelAI — Project Overview

## Summary

TravelAI 是面向中文用户的 AI 旅行规划 iOS 应用。用户在主界面输入目的地，飞机立即起飞飞向目的地，同时 AI 在后台生成多天行程攻略并保存。支持文化知识图谱、每日地图路线、AI 聊天修改行程、照片记忆光点等功能。

当前处于**稳定迭代阶段**：核心流程已全部打通，主要在做 UX 细节修复。

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | SwiftUI (iOS 26+) |
| UI 风格 | **Apple Liquid Glass**（`.glassEffect(.regular, in:)`）|
| Persistence | SwiftData (`@Model`, cascade delete) |
| State Management | `@Observable` (Swift 5.9) |
| Networking | `async/await` + 自定义 `URLSession`（ephemeral，防模拟器挂起）|
| AI Provider | MiniMax-M2.5-highspeed（默认）/ Gemini 2.5 Flash（备用）/ Claude Haiku（备用）|
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
.glassEffect(.regular, in: .circle)
.glassEffect(.regular, in: .capsule)
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
.buttonStyle(.glass)
```

**例外**：进度卡片、日志面板等高对比度信息区域，用深色半透明背景。

### 常驻底部输入栏

`TravelInputBar` 出现在所有页面底部，共享 `TripInputController.shared` 单例状态。

### 输入流程（聊天气泡式，两步）

```
.idle   → 用户输入目的地 → 点飞机发送
.date   → 日期选择 + 出行方式 + 游玩风格（内联）→ 点确认
.confirm→ 触发生成，显示进度浮层
```

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

### AI 生成数据流

```
TravelInputBar → TripInputController.onStartGeneration
  → HomeView.startGeneration(dest, date, days, style, transport)
  → FlightRouteAnimator.startPreview(origin, dest, mode)  ← 立即飞行动画（并行）
  → NewTripViewModel.generate(context:)                   ← 异步 AI 生成（并行）
      → AIService.generateTrip()        ← MiniMax-M2.5-highspeed (max_tokens=16000)
      → cleanJSON() + fixSpuriousQuotesInJSONStrings()
      → AIResponseParser.parse()
      → 内联写入 SwiftData + context.save()
  → FlightRouteAnimator.continueWithItinerary(coords)  ← 行程路线动画
```

### 历史行程回放流

```
TripListSheet 点击行程卡片
  → ctrl.onViewTripOnMap?(trip)
  → HomeView.playTripOnMap(trip)
  → 从 SwiftData 直接读取存储坐标（不重新生成）
  → FlightRouteAnimator.continueWithItinerary(coords)
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
| 常驻输入栏 | `TravelInputBar.swift` | ✅ | 聊天气泡两步流程，全局复用，键盘正常 |
| 全局输入状态 | `TripInputController.swift` | ✅ | `@Observable` 单例 |
| 行程列表 | `TripListSheet`（HomeView.swift 内）| ✅ | 含相同输入栏，左划详情/右划删除 |
| 新建旅行 VM | `NewTripViewModel.swift` | ✅ | 生成阶段机，SwiftData 写入 |
| 行程详情 | `TripDetailView.swift` | ✅ | 顶部 tab 导航 |
| 每日行程 | `ItineraryView.swift` | ✅ | 时间轴 + 清单 |
| 文化知识图谱 | `CultureView.swift` | ✅ | 树形节点 |
| 行程地图 | `TripMapView.swift` | ✅ | Day 选择器 + Polyline + MKDirections 真实导航路线 |
| AI 聊天 | `ChatView.swift` | ✅ | JSON patch 修改行程 |
| 工具箱 | `ToolsView.swift` | ✅ | 清单/SOS/贴士 |
| 照片记忆光点 | `PhotoMemoryService.swift` | ✅ | 相册GPS，MapKit Annotation |
| 飞行路线动画 | `FlightRouteAnimator.swift` | ✅ | 硬编码坐标字典 + AI geocode + SLERP |
| 历史行程回放 | `HomeView.playTripOnMap()` | ✅ | 直接读 SwiftData 坐标，无需重新生成 |
| 设置页 | `SettingsView.swift` | ✅ | 默认出行方式 + 游玩风格 预设 |

---

## 服务层关键点

### FlightRouteAnimator — 地理编码优先级

1. **内置枢纽坐标字典**（28个高频机场/高铁站）
2. **AI geocode**（MiniMax，max_tokens=600，temperature=0）
3. **简化查询 fallback**（`X机场` → `X城市中心`）

到达阶段规则：
- 飞机/高铁：相机和标注始终跟 `arrivalHub`（机场/高铁站）
- hub 距城市 > 30km 时，额外加城市目的地标注
- 驾车：直接到目的地坐标

### AIService — JSON 修复管线

1. 去除 `<think>...</think>` 块（含未闭合截断）
2. 去除 markdown 代码块
3. 截取第一个 `{` 到最后一个 `}`
4. fix-a～fix-e：数字引号、日期引号、缺失闭合引号等
5. **fix-f 字符级扫描** `fixSpuriousQuotesInJSONStrings()`：处理 AI 在字符串值内插入多余双引号

### URLSession 配置

```swift
let cfg = URLSessionConfiguration.ephemeral
cfg.timeoutIntervalForRequest  = 60    // 单次读写超时
cfg.timeoutIntervalForResource = 310   // 总超时
cfg.waitsForConnectivity = false
```

---

## 文件结构

```
TravelAI/
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift            # 主界面 + TripListSheet（内嵌）
│   │   ├── GlobeView.swift           # 地图+动画层
│   │   ├── TravelInputBar.swift      # 底部输入栏（全局复用）
│   │   └── TripInputController.swift # 全局输入状态（@Observable 单例）
│   ├── NewTrip/
│   │   └── NewTripViewModel.swift    # AI生成状态机
│   ├── Settings/
│   │   └── SettingsView.swift        # 默认出行方式 + 游玩风格
│   └── ...
├── Services/
│   ├── AIService.swift               # API 调用 + JSON 清洗 + geocode
│   ├── AIResponseParser.swift        # JSON → SwiftData
│   ├── FlightRouteAnimator.swift     # 飞行动画 + 枢纽坐标表
│   ├── PhotoMemoryService.swift      # 相册GPS光点
│   └── LocationManager.swift
└── Theme/
    └── AppTheme.swift
```

---

## 已知问题（截至 2026-04-20）

- MiniMax 生成 JSON 概率性包含非法字符（fix-f 已覆盖大多数情况，极端情况重试即可）
- 无其他阻塞性问题

---

## 相关文档

- `DEEPV.md` — 项目总纲（最高优先级参考）
- `docs/superpowers/plans/2026-04-07-ios-app.md` — 原始任务清单
- `docs/superpowers/specs/2026-04-07-ai-travel-app-design.md` — 产品设计规格
