# 精细足迹打点渲染实施计划

> TravelAI · iOS 26 · Swift 6 · SwiftUI · MapKit
> 参考「全球足迹」App 足迹点模式（IMG_2390）

## 核心设计决策

SwiftUI `Map{}` + `Annotation` 渲染上限约 300 个，数万点必须用 `UIViewRepresentable` + `MKOverlayRenderer` + Core Graphics 批量绘制。

足迹页面（FootprintView）使用独立的 `TrackMapView`，主页（GlobeView）继续使用 SwiftUI Map{}，两者互不干扰。

---

## 新增文件

| # | 路径 | 职责 |
|---|---|---|
| 1 | `Services/TrackRenderService.swift` | 空间索引 + 视口裁剪 + LOD 抽稀 + 热力图聚合 |
| 2 | `Features/Home/TrackDotsOverlay.swift` | MKOverlay 数据容器 |
| 3 | `Features/Home/TrackDotsRenderer.swift` | Core Graphics 批量渲染（足迹点 + 热力图） |
| 4 | `Features/Home/TrackMapView.swift` | UIViewRepresentable 包装 MKMapView |
| 5 | `Features/Home/TrackStatsPanel.swift` | 顶部信息面板 |
| 6 | `Features/Home/TrackModeToggle.swift` | 底部模式切换胶囊 |

**修改文件：** `Features/Home/FootprintView.swift`、`Features/Home/HomeView.swift`

---

## LOD 策略

| zoomScale 范围 | 对应视角 | 步长系数 |
|---|---|---|
| > 0.05 | 街区（<1km） | 1 |
| 0.01~0.05 | 城市 | 2 |
| 0.002~0.01 | 省级 | 5 |
| 0.0005~0.002 | 国家级 | 15 |
| < 0.0005 | 全球 | 50 |

目标：每帧渲染不超过 8,000 个点。

---

## 颜色规范

| 元素 | 颜色 |
|---|---|
| 足迹小红点 | `#FF3B30` (iOS Red) |
| 热力图低密度 | `rgba(51, 20, 255, 0.3)` 深蓝 |
| 热力图高密度 | `rgba(179, 77, 255, 0.95)` 亮紫白 |
| Footprints tab | `#FF3B30` |
| Heatmap tab | `#7B2FBE` |
| 统计大数字 | 白色 + #FF3B30 光晕 |

---

## 实施顺序

```
Task 1  确认 TrackImport/TrackPoint 模型已建（依赖 track-import-plan）
Task 2  Services/TrackRenderService.swift
Task 3  Features/Home/TrackDotsOverlay.swift
Task 4  Features/Home/TrackDotsRenderer.swift
Task 5  Features/Home/TrackMapView.swift
Task 6  Features/Home/TrackStatsPanel.swift
Task 7  Features/Home/TrackModeToggle.swift
Task 8  Features/Home/FootprintView.swift 修改
Task 9  Features/Home/HomeView.swift 最小修改
Task 10 TravelAIApp.swift Schema 确认
Task 11 集成测试 + 性能验证（目标 ≥55fps）
```

---

## 详细代码见规划智能体输出

完整实现代码（TrackRenderService、TrackDotsOverlay、TrackDotsRenderer、TrackMapView、TrackStatsPanel、TrackModeToggle、FootprintView 完整修改版）已在规划阶段生成，实施时参考智能体输出。
