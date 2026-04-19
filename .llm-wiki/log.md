# LLM Wiki Log

> Chronological record of wiki operations.

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
