---
type: concept
date: 2026-04-15
tags: [design, ui, theme, colors, typography, apptheme, claude]
---

# TravelAI 设计系统

> 基于 `npx getdesign@latest add claude` 生成的 Claude (Anthropic) 设计语言，适配 iOS SwiftUI。
> 完整原始模板：`docs/DESIGN-claude.md`

## 设计语言定位

**风格关键词：** 温暖羊皮纸、文学沙龙感、编辑排版、安静的智识感
**对标品牌：** Claude (Anthropic) — Warm terracotta accent, clean editorial layout
**核心原则：** 暖色调贯穿始终，无任何冷灰蓝，serif 标题赋予权威感

---

## 颜色系统

### 基础色板（Claude 官方）

| 角色 | 名称 | 色值 | 用途 |
|------|------|------|------|
| 主背景 | Parchment | `#f5f4ed` | 页面底色，羊皮纸感 |
| 卡片 | Ivory | `#faf9f5` | 卡片、容器 |
| 纯白 | Pure White | `#ffffff` | 强调卡片、按钮 |
| 暖沙 | Warm Sand | `#e8e6dc` | 次级按钮背景、区块 |
| 深暗 | Near Black | `#141413` | 暗色背景、主文字（偏橄榄黑） |
| 暗面 | Dark Surface | `#30302e` | 暗色卡片、边框 |

### 文字色

| 角色 | 色值 | 用途 |
|------|------|------|
| 主文字 | `#141413` | 标题、正文 |
| 次级文字 | `#5e5d59` Olive Gray | 副标题、描述 |
| 三级文字 | `#87867f` Stone Gray | 元数据、占位 |
| 暗底文字 | `#b0aea5` Warm Silver | 深色背景上的文字 |
| 深色强调 | `#3d3d3a` Dark Warm | 深色链接、次级强调 |

### ⭐ 强调色（最重要）

| 角色 | 名称 | 色值 | 用途 |
|------|------|------|------|
| **主品牌色** | **Terracotta Brand** | **`#c96442`** | **CTA 按钮、品牌高亮、主强调** |
| 次品牌色 | Coral Accent | `#d97757` | 文字链接、次级强调 |
| 错误色 | Error Crimson | `#b53333` | 错误状态 |
| 焦点色 | Focus Blue | `#3898ec` | 输入框 focus ring（唯一冷色） |

> ⚠️ **关键规则：** 强调色用 Terracotta `#c96442`，**不用金色**。金色在亮色背景上显脏（"屎黄"问题的根源）。

### 边框色

| 角色 | 色值 | 用途 |
|------|------|------|
| 标准边框（亮） | `#f0eee6` Border Cream | 卡片轮廓，几乎不可见 |
| 强调边框（亮） | `#e8e6dc` Border Warm | 分割线、区块边框 |
| 暗色边框 | `#30302e` Border Dark | 暗色背景上的边框 |
| Ring 亮 | `#d1cfc5` Ring Warm | 按钮 hover/focus ring |

### 多主题扩展（后续）

未来不同旅行目的地可以有专属主题色，替换 Terracotta 强调色：

```
Egypt   → 沙漠金 #C8860A（保留暖调，偏金）
Japan   → 樱桃红 #C94060
Greece  → 爱琴海蓝 #1E6A8C
Thailand→ 翡翠绿 #1A7A50
默认     → Terracotta #c96442
```

每套主题**只替换强调色**，背景/文字/边框保持 Parchment 系统不变。

---

## 字体系统 ⭐

> **这是最重要的部分。** Claude 设计语言的灵魂在字体。

### 字体家族

| 用途 | Claude 官方字体 | iOS SwiftUI 替代方案 |
|------|----------------|---------------------|
| 标题/展示 | Anthropic Serif | **New York**（系统 Serif）或 Georgia |
| 正文/UI | Anthropic Sans | **SF Pro**（系统 Sans，默认） |
| 代码 | Anthropic Mono | **SF Mono** |

**SwiftUI 实现：**
```swift
// Serif 标题（Claude 风格）
.font(.custom("NewYork", size: 32).weight(.medium))
// 或使用系统 serif
.font(.system(size: 32, weight: .medium, design: .serif))

// Sans 正文（默认）
.font(.system(size: 16, weight: .regular, design: .default))

// Mono 代码
.font(.system(size: 15, weight: .regular, design: .monospaced))
```

### 字阶规范

| 角色 | 大小 | 字重 | 行高 | 字体 | 备注 |
|------|------|------|------|------|------|
| Display/Hero | 64pt | 500 (medium) | 1.10 | Serif | 最大标题，书名感 |
| Section Heading | 52pt | 500 | 1.20 | Serif | 章节锚点 |
| Sub-heading | 32pt | 500 | 1.10 | Serif | 卡片标题 |
| Sub-heading Small | 25pt | 500 | 1.20 | Serif | 小节标题 |
| Feature Title | 20pt | 500 | 1.20 | Serif | 功能标题 |
| Body Serif | 17pt | 400 | 1.60 | Serif | 编辑排版段落 |
| Body Large | 20pt | 400 | 1.60 | Sans | 导语段落 |
| Body / Nav | 17pt | 400–500 | 1.60 | Sans | 导航、UI |
| Body Standard | 16pt | 400–500 | 1.60 | Sans | 标准正文 |
| Caption | 14pt | 400 | 1.43 | Sans | 元数据 |
| Label | 12pt | 400–500 | 1.60 | Sans | 徽章、小标签 |
| Overline | 10pt | 400 | 1.60 | Sans | 大写上方标注 |

### 字体原则

1. **Serif 管权威，Sans 管功能** — Serif 用于所有标题，Sans 用于按钮/标签/导航
2. **Serif 只用 weight 500** — 不用 bold(700)，保持统一"声音"
3. **正文行高 1.60** — 比普通 App 宽松，接近书籍阅读体验
4. **标题行高 1.10–1.30** — 紧凑但不拥挤
5. **小文字加字间距** — 12pt 以下用 `tracking: 0.12–0.5pt`

---

## 阴影系统

Claude 用 **ring shadow** 代替传统 drop shadow：

| 层级 | 处理方式 | 用途 |
|------|---------|------|
| Level 0 Flat | 无阴影无边框 | 背景、内联文字 |
| Level 1 Contained | `1px solid #f0eee6` | 标准卡片 |
| Level 2 Ring | `0px 0px 0px 1px` ring | 交互卡片、按钮 hover |
| Level 3 Whisper | `rgba(0,0,0,0.05) 0px 4px 24px` | 悬浮卡片 |

**核心理念：** "ring shadow 是伪装成阴影的边框，或者伪装成边框的阴影" — 创造深度感而不显厚重。

---

## 圆角规范

| 名称 | 大小 | 用途 |
|------|------|------|
| Sharp | 4px | 极小内联元素 |
| Subtle | 6–8px | 小按钮、标签 |
| Comfortable | 8–8.5px | 标准按钮、卡片 |
| Generous | 12px | 主按钮、输入框 |
| Feature | 16px | 功能容器、视频 |
| Very Rounded | 24px | Tag、高亮容器 |
| Maximum | 32px | Hero 容器、大卡片 |

---

## Do's & Don'ts

### ✅ Do
- 用 Parchment `#f5f4ed` 作为主背景
- Serif weight 500 做所有标题
- 只在主 CTA 用 Terracotta `#c96442`
- 所有中性色保持暖色调（带黄棕底色）
- 正文行高 1.60
- ring shadow 代替 drop shadow

### ❌ Don't
- 不用冷蓝灰（任何地方）
- Serif 不超过 weight 500
- 不引入 Terracotta 以外的饱和色
- 按钮/卡片圆角不小于 6px
- 不用纯白 `#ffffff` 做页面背景
- 不降低正文行高至 1.40 以下

---

## 当前 AppTheme 对比

| 项目 | Claude 官方 | 当前代码 | 需要修改？ |
|------|------------|---------|---------|
| 主背景 | `#f5f4ed` | `#F5F0E8` | 轻微，可接受 |
| 强调色 | **`#c96442`** | **`#B8860B`** | **⚠️ 必须改** |
| 主文字 | `#141413` | `#2A1F0E` | 轻微，可接受 |
| 边框 | `#f0eee6` | `#DDD5C5` | 建议统一 |
| **字体** | **Serif 标题** | **全部 SF Pro** | **⚠️ 必须改** |
| 阴影 | ring + whisper | 已实现 | ✅ 对齐 |

---

## 相关文件

- [[overview]] — 项目总览
- 原始模板：`docs/DESIGN-claude.md`
- 原始设计文档：`docs/superpowers/specs/2026-04-07-ai-travel-app-design.md`
- 实现文件：`TravelAI/TravelAI/Theme/AppTheme.swift`
