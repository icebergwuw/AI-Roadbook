# LLM Wiki Index

> Auto-maintained by DeepV Code. Do not edit manually.

## Sources
- `docs/superpowers/specs/2026-04-07-ai-travel-app-design.md` — 项目原始设计文档
- `docs/superpowers/plans/2026-04-07-ios-app.md` — 实施任务清单
- `DEEPV.md` — 项目总纲（UI原则 / 技术规范 / 版本历史）

## Entities
- [[overview]] — TravelAI 项目总览（架构、功能状态、文件结构）

## Concepts
- [[design-system]] — TravelAI 设计系统（Claude 风格，含色板、字体、阴影、圆角规范）

## Key Principles
- **Liquid Glass 优先**：所有 UI 使用 iOS 26 `.glassEffect(.regular, in:)`，让元素融入地图背景
- **常驻输入栏**：`TravelInputBar` 出现在所有页面，共享 `TripInputController.shared`
- **飞行先于生成**：点发送后立即启动飞行动画，AI 在后台生成，用动画掩盖等待时间

## Synthesis
<!-- Cross-cutting analysis pages will be listed here -->
