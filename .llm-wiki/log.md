# LLM Wiki Log

> Chronological record of wiki operations.

## [2026-04-20] session-end | 今日工作存档

今日完成工作（13 个 commits，全部在 2026-04-20）：

### 新功能
- `feat: real navigation routes in TripMapView via MKDirections` — TripMapView 改用 MKDirections 生成真实导航路线（polyline），替代直线连接

### 核心修复
- `fix: airport markers, camera drift, JSON spurious quotes, trip replay` — 机场标注漂移修复、JSON fix-f 字符级扫描、历史行程地图回放（直接读 SwiftData 坐标）
- `fix: wrong destination / duplicate markers / input locked` — 目的地坐标错误、重复标注、输入框锁死三合一修复
- `fix: geocode reliability - tested with live API` — AI geocode 可靠性提升
- `fix: second trip disappears + swipe delete + task cancellation` — 第二次生成消失、左划删除崩溃、任务取消逻辑修复
- `fix: input bar touch blocked by map, trip replay without animation` — 输入栏被地图层遮挡点击无效、历史回放去掉冗余飞行动画
- `fix: TextField keyboard not appearing` — 移除 ZStack 对 glassEffect 的包裹，恢复 TextField 响应链
- `fix: restore Mac keyboard input in simulator` — glassEffect 直接加在 TextField 上会破坏 UITextField responder chain；改为 Capsule 背景 + `allowsHitTesting(false)`，键盘焦点恢复正常
- `fix: simplify date step UI, map tap to dismiss, improve generation reliability` — 日期步骤 UI 简化，点击地图收起输入栏，生成可靠性提升

### 文档
- `research: competitor analysis 2026-04-20` — 联网竞品分析，写入 wiki
- `docs: update DEEPV.md and wiki` — 纲领文档与 wiki 同步

### 当前状态
- **无阻塞性 bug**，核心流程全部打通
- 所有功能模块 ✅（主地图、输入栏、飞行动画、AI生成、行程保存、历史回放、TripDetail 全部子页）
- 下次可继续方向：性能优化、UI 打磨、更多目的地坐标入库、上线准备

---

## [2026-04-20] research | 竞品分析报告
- 新建 `wiki/competitor-analysis.md`：联网实时调研，覆盖：
  - 市场规模（Gen AI 旅行 $12.7亿/2026，CAGR 18.64%）
  - 主要竞品深度分析（Wanderlog MAU 1000万、Mindtrip $2000万融资、Layla、TripIt）
  - 大平台动态（Airbnb AI-native、TripAdvisor OpenAI、Google Gemini 沉浸导航）
  - 地图 SDK 矩阵（Google Maps 3D SDK 2025年I/O、Mapbox 3D Lanes 2026年1月、MapKit iOS 26）
  - TravelAI 差异化优势与核心差距分析
  - 策略建议：保持 MapKit + OSRM 路线 API
- 更新 `index.md`

## [2026-04-18] update | Liquid Glass 写入纲领，架构更新
- 新建 `DEEPV.md`：项目总纲，含 Liquid Glass UI 原则、技术规范、版本历史、待解决问题
- 更新 `wiki/overview.md`：
  - Tech Stack 加入 iOS 26 + Liquid Glass
  - 架构图更新（TravelInputBar 全局复用、TripInputController 单例、聊天气泡流程）
  - FlightRouteAnimator 硬编码坐标字典说明
  - 功能状态表更新
- 更新 `.llm-wiki/index.md`

## [2026-04-16] update | 项目总览大幅更新
- 更新 `wiki/overview.md`：反映当前真实实现状态
- 主要变更：
  - Tech Stack 更新（MapKit 已集成，AI 直连 MiniMax-M2.5，无 Supabase 代理）
  - HomeView 改为全屏 MapKit 3D 地球，去除 TabView 结构
  - NewTripView 改为 half-screen bottom sheet
  - 新增 PhotoMemoryService（相册GPS光点）
  - 新增 FlightRouteAnimator（飞行路线动画）
  - 所有功能模块标记为 ✅ 完整
  - 更新已知问题列表（旧 bugs 已修复，更新新的注意事项）
  - 更新文件结构图
- 更新 `index.md`：添加 [[overview]] 入口，移除失效 docs/DESIGN-claude.md 引用

## [2026-04-15] learn | 设计系统写入 Wiki
- 运行 `npx getdesign@latest add claude` 获取 Claude 官方设计语言
- 创建 `wiki/design-system.md`：色板、字体规范、阴影、圆角、Do/Don't
- 关键发现：强调色应为 Terracotta `#c96442`（非金色），Serif 字体是灵魂
- 原始模板存至 `docs/DESIGN-claude.md`
- 更新 index.md

## [2026-04-10] init | Wiki Initialized
- Created wiki directory structure
- Ready for source ingestion
