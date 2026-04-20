# 徽章收集系统实施计划

> TravelAI · iOS 26 · Swift 6 · SwiftUI
> 参考「全球足迹」App 成就页（IMG_2391）

---

## 新增文件

```
TravelAI/TravelAI/Features/Achievements/
├── BadgeDefinitions.swift       # 数据：所有省份/州/都道府县徽章定义
├── BadgeView.swift              # 单个徽章椭圆卡片（Oval，70×90pt）
└── AchievementsView.swift       # 成就页主视图（纯黑背景，4列网格）
```

**修改文件：** `Features/Home/FootprintView.swift`（添加成就入口按钮）

---

## 徽章数据覆盖

- **中国 34省**：adcode 与 provinces-cn.geojson 对应（110000~820000）
- **美国 10州**：代表性州（CA, NY, TX, FL, HI, AK, WA, CO, IL, NV）
- **日本 8都道府县**：东京、大阪、京都、北海道、福冈、神奈川、爱知、冲绳

⚠️ 实施 Task 2 必须核查 GeoJSON id 格式与 visitedProvinceIDs 格式一致。

---

## 徽章设计

每个徽章由 SwiftUI 纯代码生成：
- **已解锁**：`primaryColor → secondaryColor` 渐变背景 + Emoji 符号 + 省份缩写 + 金色描边 + Shine 扫光动画
- **未解锁**：`#1A1A1A` 深灰背景 + 0.25 透明度内容 + 锁图标

---

## AchievementsView 页面结构

- 纯黑背景
- 顶部总览卡片：`X/N` 大数字 + 圆形进度环 + 金色进度条
- 分组 Section（中国/美国/日本）：Flag Emoji + 组名 + `X/N` 进度徽章
- 每组 LazyVGrid 4列，已解锁优先排序
- 每个格子：BadgeView（70×90）+ 省份名小字

---

## 集成到 FootprintView

在底部 VStack 添加「成就徽章」入口按钮：
- 金色 `medal.fill` 图标
- 已解锁数量角标（金色圆形）
- Sheet 弹出 AchievementsView

---

## 实施顺序

```
Task 1  新建 Features/Achievements/ 文件夹
        新建 BadgeDefinitions.swift
Task 2  核查 GeoJSON id 格式（adcode vs GID_1）
        更新 BadgeDefinitions 中美/日 id 格式
Task 3  新建 BadgeView.swift
Task 4  新建 AchievementsView.swift
Task 5  修改 FootprintView.swift：添加入口按钮 + sheet
Task 6  Xcode 编译 + 添加 Achievements/ 到 Target
Task 7  数据验证（行程地点 → ProvinceHighlightService → 徽章解锁）
```

---

## 关键注意：adcode 格式核查

```bash
# 检查 CN GeoJSON 的 id 格式
python3 -c "
import json
with open('TravelAI/TravelAI/Resources/provinces-cn.geojson') as f:
    d = json.load(f)
for feat in d['features'][:3]:
    print(feat['properties'])
"
```

同理检查 provinces-world.geojson 中 US/JP features 的属性字段。
