# DEEPV 项目纲领

> 本文件记录 TravelAI 项目的总体设计原则、技术方向和 UI 规范，供 AI 助手持续开发时参考。

---

## ⚠️ 最高优先级：AI 操作纲领

**在修改任何代码之前，必须先向用户说明意图并等待确认。**

具体规则：
1. **先问后改**：任何文件修改（包括看起来"显然正确"的小改动）都必须先描述改动内容，等用户说"可以"再动手
2. **不得擅自回滚**：不能以"修复"为名把用户认可的设计换掉（如 glassEffect）
3. **一次只改一件事**：不要把多个改动捆绑在一起，分步说明、分步确认
4. **调试不等于乱改**：遇到 bug 先分析根因、提出方案，不要反复尝试不同修改直到"碰巧对了"
5. **每次改动后必须提交 git**：每完成一个功能、修复或优化，立即 `git add` + `git commit`，不允许积累大量未提交改动

---

## 项目定位

TravelAI 是面向中文用户的 **AI 旅行规划 iOS 应用**。核心体验是：
1. 用户打开 App，看到一个沉浸式的 3D 卫星地图
2. 在底部常驻输入栏输入目的地
3. 飞机从当前位置起飞，飞向目的地机场/高铁站（视觉上掩盖 AI 生成等待时间）
4. AI 生成完整多天攻略并保存到「我的旅行」
5. 行程路线在地图上以动画逐日展示
6. 历史行程可从列表直接回放路线（无需重新生成）

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

**例外**：进度卡片、日志面板等需要高对比度可读性的信息展示区域，使用深色半透明背景。

### 2. 沉浸式地图体验

- 地图永远是全屏背景，UI 元素悬浮其上
- 所有操作入口通过 Liquid Glass 按钮/胶囊实现，不用传统 NavigationBar
- 避免大面积不透明遮罩地图

### 3. 常驻底部输入栏

输入栏是核心交互入口，出现在每一个页面的底部：

- `HomeView`：Liquid Glass 输入栏，飞机发送按钮
- `TripListSheet`：同款输入栏，生成新旅行前先 dismiss sheet 回到地图
- 统一使用 `TravelInputBar(ctrl: TripInputController.shared)`

### 4. 聊天气泡式交互（两步）

```
.idle   → 用户输入目的地
.date   → 日期选择器 + 出行方式（飞机/高铁/自驾）+ 游玩风格（内联，无独立步骤）
.confirm→ 触发生成，显示进度浮层
```

默认出行方式和游玩风格在 Settings 预设，无需每次确认。

### 5. 深色地图配色

主界面使用 `.hybrid(elevation: .realistic)` 卫星+地名混合地图。
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
  → HomeView.startGeneration(dest, date, days, style, transport)
  → FlightRouteAnimator.startPreview(origin, dest, mode)  ← 立即飞行动画（并行）
  → NewTripViewModel.generate(context:)                   ← 异步 AI 生成（并行）
  → AIService.generateTrip()           ← MiniMax-M2.5-highspeed (max_tokens=16000)
  → cleanJSON() + fixSpuriousQuotesInJSONStrings()
  → AIResponseParser.parse()
  → 内联写入 SwiftData + context.save()
  → FlightRouteAnimator.continueWithItinerary(coords)     ← 行程路线动画
```

### 历史行程回放

```
TripListSheet 点击行程卡片
  → ctrl.onViewTripOnMap?(trip)
  → HomeView.playTripOnMap(trip)
  → 从 SwiftData 直接读取存储坐标（不重新生成）
  → FlightRouteAnimator.continueWithItinerary(coords)
```

### 地理编码（FlightRouteAnimator）

优先级：
1. **内置枢纽坐标表**（28个高频机场/高铁站，key = arrivalQuery 字符串）
2. **AI geocode**（MiniMax，max_tokens=600，temperature=0）
3. **简化查询 fallback**（`X机场` → `X城市中心`）

到达阶段规则：
- 飞机/高铁：相机和标注始终跟 `arrivalHub`（机场/高铁站），而非城市中心
- hub 距城市 > 30km 时，额外加城市目的地标注
- 驾车：直接到目的地坐标

### JSON 修复管线（AIService.cleanJSON）

1. 去除 `<think>...</think>` 块（含未闭合截断）
2. 去除 markdown 代码块
3. 截取第一个 `{` 到最后一个 `}`
4. fix-a～fix-e：数字引号、日期引号、缺失闭合引号等常见 bug
5. **fix-f 字符级扫描**：`fixSpuriousQuotesInJSONStrings()` — 处理 AI 在字符串值内部插入多余双引号（如 `"Sky Tower", Auckland"` → `"Sky Tower, Auckland"`）

### API 配置

| Provider | Model | Key 存储 |
|---|---|---|
| MiniMax（默认）| MiniMax-M2.5-highspeed | `UserDefaults: travelai.apiKey` |
| Gemini（备用）| gemini-2.5-flash | `UserDefaults: travelai.geminiKey`（代码中为占位符）|
| Claude（备用）| claude-haiku-4-5 | 代码中为占位符 |

> ⚠️ Gemini/Claude key 在代码里已替换为占位符（git filter-repo 清除历史）。使用时在 Settings 页面填入，或通过 `UserDefaults` 写入。

### URLSession 配置

```swift
// ephemeral session，防止模拟器 URLSession 永久挂起
let cfg = URLSessionConfiguration.ephemeral
cfg.timeoutIntervalForRequest  = 60    // 单次读写超时
cfg.timeoutIntervalForResource = 310   // 总超时
cfg.waitsForConnectivity = false
```

---

## 行程列表交互规范

- 点击行程卡片 → 关闭 sheet，在主地图播放行程路线（直接读存储坐标）
- 左划 → 查看详情（`TripDetailView`）
- 右划 → 删除（带确认颜色）
- 无右侧 `>` 箭头（用 `Button` 而非 `NavigationLink`）

---

## 文件结构规范

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
    └── AppTheme.swift                # 设计 token
```

---

## 版本历史要点

| 日期 | 内容 |
|---|---|
| 2026-04-07 | 项目初始化，基础架构 |
| 2026-04-10 | Tab 补全，行程详情页完善 |
| 2026-04-16 | 照片记忆光点，飞行动画，进度卡片，3D 飞机 |
| 2026-04-17 | 全局 Liquid Glass，输入栏聊天气泡流程，URLSession 超时修复 |
| 2026-04-18 | 地理编码硬编码字典，进度卡片可读性修复，Trip 保存调试 |
| 2026-04-19 | AI geocode 替代 CLGeocoder，出行方式/风格预设，飞行落点修复，第二次生成修复，删除修复 |
| 2026-04-20 | 机场标注/相机漂移修复，JSON多余引号字符级修复，历史行程地图回放，GitHub推送（history rewrite去除硬编码key）|

---

## 开发环境

- **当前年份**：2026年
- **模拟器系统**：iOS 26.4.1 正式版（非 beta）
- **模拟器键盘输入**：需先点击输入框获得焦点，再按 `Cmd+Shift+K` 将键盘焦点切到设备，才能用 Mac 键盘输入

## 当前已知问题

无阻塞性问题。偶发：
- MiniMax 生成 JSON 概率性包含非法字符（fix-f 已覆盖大多数情况，极端情况仍可能失败，重试即可）

## DeepV Code Added Memories
- 在这个项目（TravelAI iOS App）中，用户要求：每次修改代码前必须先询问用户确认，不得擅自修改。这是最高优先级规则，无论任何情况都必须遵守。
- 现在是2026年。iOS 26.4.1 是正式版，不是beta。模拟器键盘焦点切换快捷键是 Cmd+Shift+K（I/O → Input → Send Keyboard Focus to Device）。
