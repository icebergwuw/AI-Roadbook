# AI 旅游攻略 iOS App — 设计文档

**日期：** 2026-04-07
**状态：** 已确认，待实施

---

## 1. 产品定位

面向中文用户的 AI 驱动旅游攻略 iOS App。用户输入任意目的地和出行日期，AI 自动生成该目的地的完整个人攻略（行程 + 深度文化知识 + 实用信息），并支持通过对话持续修改和定制。

**核心价值：**
- 任意目的地，AI 一键生成深度攻略
- 每个目的地有专属文化知识图谱（神话体系、历史谱系等）
- 个人行程管理 + 地图线路 + 实用工具一体化

---

## 2. 技术架构

### 方案：渐进式架构（本地优先 + 云就绪）

```
┌─────────────────────────────────┐
│        iOS App (SwiftUI)        │
│  UI Layer │ Domain │ Data Layer │
│  Views    │ VMs    │ SwiftData  │
└──────────────────┬──────────────┘
                   │ HTTPS
┌──────────────────▼──────────────┐
│     Supabase Edge Functions     │
│  AI 代理（隐藏 API Key）         │
│  未来：用户系统 / 订阅           │
└──────────────────┬──────────────┘
                   │ API
        ┌──────────┼──────────┐
        ▼          ▼          ▼
    OpenAI      Claude     DeepSeek
   (GPT-4o)  (Anthropic)  (国内模型)
```

**技术栈：**
- **iOS App：** Swift + SwiftUI + SwiftData
- **本地存储：** SwiftData（离线优先，iCloud 自动备份）
- **后端：** Supabase Edge Functions（Deno/TypeScript）
- **AI：** 可配置多服务商，App 内选择，Key 存服务端

**分层架构（iOS）：**
- `UI Layer`：SwiftUI Views、NavigationStack、动画
- `Domain Layer`：ViewModels（@Observable）、Models、Use Cases
- `Data Layer`：SwiftDataRepository、AIService、iCloudSync

---

## 3. 导航结构

### 底部主导航 + 顶部子 Tab

**底部 TabBar（全局）：**

```
[ 首页 ]  [ 行程 ]  [ + 新建 ]  [ 探索 ]  [ 设置 ]
```

- **首页：** 所有目的地卡片列表，点击进入目的地详情
- **行程：** 当前最近一次旅行的快速入口
- **+ 新建：** 创建新目的地（触发 AI 生成流程）
- **探索：** 热门目的地推荐（后期）
- **设置：** AI 服务商配置、API Key、偏好

**目的地详情页（顶部 Tab）：**

```
[ 行程 ]  [ 文化 ]  [ 地图 ]  [ 会话 ]  [ 工具 ]
```

- **行程：** 日历导航 + 每日时间线 + 待办 Checklist
- **文化：** 目的地专属知识图谱（神话/历史/谱系树）
- **地图：** 每日行程地点连线路线（MapKit）
- **会话：** AI 对话，修改行程/追问文化问题
- **工具：** 贴士 + SOS 紧急联系（后期扩展记账/天气/行李）

---

## 4. UI 视觉风格

### 深棕暗金色系（忠实参考图）

**色彩规范：**

| 用途 | 色值 |
|------|------|
| 主背景 | `#1E1408` |
| 卡片背景 | `#2C1F0E` |
| 主强调色（金） | `#D4A017` |
| 次强调色 | `#C8A84B` |
| 正文文字 | `#E8D5A0` |
| 次级文字 | `#8A7A5A` |
| 边框/分割线 | `#5A3E10` |

**字体：** SF Pro（系统字体），目的地标题使用大字重 + 字间距

**视觉特征：**
- 深棕色为基底，金色为强调，营造古典文明氛围
- 圆角卡片（`cornerRadius: 12`），低对比度分割线
- 行程时间线：左侧竖线 + 圆点节点
- 知识图谱：树状连线图，节点使用目的地专属图标/emoji

---

## 5. AI 攻略生成流程

### 用户操作
1. 点击「+ 新建」
2. 输入目的地名称
3. 选择出行日期区间
4. 可选：旅行风格（文化深度 / 休闲 / 探险）、同行人数
5. 点击「AI 生成攻略」

### 生成流程
```
App → Supabase Edge Function → AI 模型
                ↓
        返回结构化 JSON
                ↓
        存入 SwiftData（本地）
                ↓
        渲染各 Tab 内容
```

### AI 生成的 JSON 结构

```json
{
  "destination": "Egypt",
  "dateRange": { "start": "2026-03-26", "end": "2026-04-05" },
  "itinerary": [
    {
      "day": 1,
      "date": "2026-03-26",
      "title": "Cairo → Aswan",
      "events": [
        {
          "time": "04:50",
          "title": "抵达开罗机场",
          "description": "落地后换钱/买SIM卡",
          "location": { "name": "开罗国际机场", "lat": 30.1219, "lng": 31.4056 },
          "type": "transport"
        }
      ]
    }
  ],
  "checklist": [
    { "id": "uuid", "title": "定包车两天", "completed": false, "dayIndex": 1 }
  ],
  "culture": {
    "type": "mythology_tree",
    "title": "古埃及众神谱系",
    "nodes": [...],
    "dynasties": [...]
  },
  "tips": [...],
  "sos": [
    { "title": "中国驻埃及大使馆", "phone": "+20-2-27361219", "subtitle": "领事保护热线" }
  ]
}
```

### 对话修改
- 会话 Tab 维护独立的对话历史（存 SwiftData）
- 用户可通过对话修改行程、追问文化知识
- AI 返回的行程修改以 diff patch 形式应用到本地数据

---

## 6. 地图线路模块

**技术：** MapKit（原生，无需第三方 SDK）

**功能：**
- 顶部日期选择器切换「当日路线」
- 地图上按顺序显示当日所有地点（标注编号）
- 地点之间绘制折线连接（Polyline）
- 点击标注弹出地点卡片（名称、时间、简介）
- 支持「导航到此地点」（跳转 Apple Maps）

**数据来源：** AI 生成时每个 event 携带 `location.lat/lng`，若 AI 未返回坐标则通过 MapKit 本地 geocoding 补全。

---

## 7. 数据模型（SwiftData）

```swift
@Model class Trip {
    var id: UUID
    var destination: String
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var days: [TripDay]
    var checklist: [ChecklistItem]
    var culture: CultureData
    var tips: [Tip]
    var sosContacts: [SOSContact]
    var conversations: [Message]
}

@Model class TripDay {
    var date: Date
    var title: String
    var events: [TripEvent]
}

@Model class TripEvent {
    var time: String
    var title: String
    var description: String
    var locationName: String
    var latitude: Double?
    var longitude: Double?
    var type: EventType  // transport / attraction / food / accommodation
}
```

---

## 8. MVP 范围

### 包含（先做）
- [ ] 目的地创建 + AI 生成攻略（完整 JSON）
- [ ] 行程 Tab：日历导航 + 每日时间线
- [ ] 待办 Checklist（行程内）
- [ ] 文化 Tab：知识图谱（树状交互图）
- [ ] 地图 Tab：每日路线连线（MapKit）
- [ ] 会话 Tab：AI 对话 + 行程修改
- [ ] 工具 Tab：贴士 + SOS 紧急联系
- [ ] Supabase Edge Function AI 代理

### 后期扩展（上架前）
- [ ] 记账模块
- [ ] 天气模块
- [ ] 行李清单
- [ ] 用户账号 + 云同步
- [ ] 订阅付费（StoreKit 2）
- [ ] 多语言支持

---

## 9. 错误处理

- **AI 生成失败：** 提示重试，保留用户输入
- **网络离线：** 已生成的攻略完全可离线使用
- **坐标补全失败：** 地图模块隐藏该地点标注，不影响其他功能
- **AI 对话修改冲突：** 修改前本地快照，支持撤销

---

## 10. 测试策略

- **Unit Tests：** ViewModels、AI JSON 解析、数据模型
- **UI Tests：** 核心用户流程（创建目的地 → 查看行程 → 地图）
- **Mock AI：** 本地 JSON fixture 用于开发调试，无需真实 API 调用
