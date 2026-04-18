# DEEPV 项目纲领

> 本文件记录 TravelAI 项目的总体设计原则、技术方向和 UI 规范，供 AI 助手持续开发时参考。

---

## 项目定位

TravelAI 是面向中文用户的 **AI 旅行规划 iOS 应用**。核心体验是：
1. 用户打开 App，看到一个沉浸式的 3D 卫星地图
2. 在底部常驻输入栏输入目的地
3. 飞机从当前位置起飞，飞向目的地（视觉上掩盖 AI 生成等待时间）
4. AI 生成完整多天攻略并保存到「我的旅行」
5. 行程路线在地图上以动画逐日展示

---

## UI 设计原则

### 1. Apple iOS 26 Liquid Glass 优先

**所有 UI 元素必须优先使用 Apple 原生的 Liquid Glass 效果**，不要用自定义毛玻璃替代。

```swift
// ✅ 正确：使用 Apple Liquid Glass
.glassEffect(.regular, in: .capsule)
.glassEffect(.regular, in: .circle)
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
.buttonStyle(.glass)

// ❌ 错误：用 ultraThinMaterial 替代
.background(.ultraThinMaterial)
```

Liquid Glass 是 iOS 26 的核心视觉语言，能让 UI 元素自然融入背景（地图、照片、内容），避免突兀的不透明卡片破坏沉浸感。

**例外**：进度卡片、日志面板等需要**高对比度可读性**的信息展示区域，使用深色半透明背景（`Color(.sRGB, r:0.1, g:0.1, b:0.12, opacity:0.92)` + `.ultraThinMaterial` 叠加）。

### 2. 沉浸式地图体验

- 地图永远是全屏背景，UI 元素悬浮其上
- 所有操作入口通过 Liquid Glass 按钮/胶囊实现，不用传统 NavigationBar
- 输入框、按钮使用 Liquid Glass，让地图隐约透过来
- 避免大面积不透明白色/灰色遮罩地图

### 3. 常驻底部输入栏

输入栏是核心交互入口，需要出现在**每一个页面的底部**：

- `HomeView`：Liquid Glass 输入栏，飞机发送按钮
- `TripListSheet`：同款输入栏，生成新旅行前先 dismiss sheet 回到地图
- 其他需要输入目的地的页面：统一使用 `TravelInputBar(ctrl: TripInputController.shared)`

### 4. 聊天气泡式交互

新建旅行的流程不用 Sheet 弹窗，而是气泡对话：
```
用户输入目的地 → AI问"几天？" → 用户选 → AI问"什么风格？" → 用户选 → 开始生成
```

### 5. 深色地图配色

主界面使用 `.hybrid(elevation: .realistic)` 卫星+地名混合地图（夜间效果）。
文字统一用白色，配合 Liquid Glass 背景保证可读性。

---

## 技术规范

### 状态管理

| 场景 | 方式 |
|---|---|
| 全局输入状态 | `TripInputController.shared`（`@Observable` 单例）|
| ViewModel | `@Observable` class，`@State` 持有在 View 里 |
| 持久化 | SwiftData `@Model`，`ModelContext` 通过 `@Environment` 传入 |
| 导航 | `NavigationStack` + `sheet` |

### AI 生成流程

```
TravelInputBar → TripInputController.onStartGeneration
  → HomeView.startGeneration(dest, date, days, style)
  → FlightRouteAnimator.startPreview()    ← 立即启动飞行动画
  → NewTripViewModel.generate(context:)   ← 异步 AI 生成
  → AIService.generateTrip()             ← MiniMax-M2.5-highspeed
  → AIResponseParser.parse()
  → 直接内联写入 SwiftData（不经 ParsedTrip.insertInto）
  → context.save()
  → FlightRouteAnimator.continueWithItinerary()  ← 飞行+行程动画
```

### 地理编码

`FlightRouteAnimator` 内置硬编码坐标字典（100+ 常用目的地），**完全绕过 CLGeocoder** 对中文地名的误判（如"冰岛"→内蒙古）。
对字典未覆盖的地名，用 `CLGeocoder(en_US locale)` + 中国大陆坐标过滤兜底。

### API 配置

| Provider | Model | Key 存储 |
|---|---|---|
| MiniMax（默认）| MiniMax-M2.5-highspeed | `UserDefaults: travelai.apiKey` |
| Gemini（备用）| gemini-2.5-flash | `UserDefaults: travelai.geminiKey` |
| Claude（备用）| claude-haiku-4-5 | 硬编码 |

`TravelAIApp.init()` 强制设置 provider=minimax，预填 MiniMax key。

---

## 文件结构规范

```
TravelAI/
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift           # 主界面
│   │   ├── GlobeView.swift          # 地图+动画层
│   │   ├── TravelInputBar.swift     # 底部输入栏（全局复用）
│   │   └── TripInputController.swift # 全局输入状态（@Observable 单例）
│   ├── NewTrip/
│   │   ├── NewTripView.swift        # ExploreView 用的独立入口（保留）
│   │   └── NewTripViewModel.swift   # AI生成状态机
│   └── ...
├── Services/
│   ├── AIService.swift              # API 调用 + JSON 清洗
│   ├── AIResponseParser.swift       # JSON → SwiftData（结构体桥接）
│   ├── FlightRouteAnimator.swift    # 飞行动画 + 硬编码坐标字典
│   ├── PhotoMemoryService.swift     # 相册GPS光点
│   └── LocationManager.swift
└── Theme/
    └── AppTheme.swift               # 设计 token
```

---

## 版本历史要点

- **2026-04-07** — 项目初始化，基础架构
- **2026-04-10** — Tab 补全，行程详情页完善
- **2026-04-16** — 照片记忆光点，飞行动画，进度卡片，3D 飞机
- **2026-04-17** — 全局 Liquid Glass，输入栏聊天气泡流程，URLSession 超时修复
- **2026-04-18** — 地理编码硬编码字典（修复境外目的地误判），进度卡片可读性修复，Trip 保存调试

---

## 待解决问题

1. **Trip 生成后不保存** — MiniMax 返回 JSON 可能被 `cleanJSON` 清洗后结构不完整，Parser 抛异常。需要在 AILogger 里看到 `cleaned JSON` 内容后定向修复。
2. **生成卡住 300s** — 模拟器偶发 URLSession 不响应超时，正式设备正常。
3. **飞行动画结束后地图复位** — 生成完成后地图应停留在目的地附近，而非回到用户位置。
