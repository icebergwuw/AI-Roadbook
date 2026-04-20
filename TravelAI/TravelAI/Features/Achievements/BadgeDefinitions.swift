import SwiftUI

// MARK: - BadgeGroup
enum BadgeGroup: String, CaseIterable, Identifiable {
    case china = "china"
    case usa   = "usa"
    case japan = "japan"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .china: return "中国"
        case .usa:   return "美国"
        case .japan: return "日本"
        }
    }

    var flagEmoji: String {
        switch self {
        case .china: return "🇨🇳"
        case .usa:   return "🇺🇸"
        case .japan: return "🇯🇵"
        }
    }
}

// MARK: - BadgeDefinition
/// Identifiable satisfied by `id: String`
struct BadgeDefinition: Identifiable {
    let id: String            // Matches ProvinceRegion.id (adcode for CN, adm1_code for US/JP)
    let group: BadgeGroup
    let name: String          // Full display name  e.g. "北京"
    let shortName: String     // Short label on badge e.g. "京"
    let primaryColor: Color
    let secondaryColor: Color
    let symbolChar: String    // Emoji or SF Symbol name
    let symbolIsEmoji: Bool
}

// MARK: - BadgeLibrary
enum BadgeLibrary {

    // MARK: China — adcode strings (Int stored as String by FootprintGeoJSONLoader)
    static let china: [BadgeDefinition] = [
        // ── 华北 ──
        BadgeDefinition(id: "110000", group: .china, name: "北京", shortName: "京",
                        primaryColor: Color(hex: "#C0392B"), secondaryColor: Color(hex: "#922B21"),
                        symbolChar: "🏯", symbolIsEmoji: true),
        BadgeDefinition(id: "120000", group: .china, name: "天津", shortName: "津",
                        primaryColor: Color(hex: "#D35400"), secondaryColor: Color(hex: "#A04000"),
                        symbolChar: "⚓", symbolIsEmoji: true),
        BadgeDefinition(id: "130000", group: .china, name: "河北", shortName: "冀",
                        primaryColor: Color(hex: "#7D6608"), secondaryColor: Color(hex: "#5D4E08"),
                        symbolChar: "🏔", symbolIsEmoji: true),
        BadgeDefinition(id: "140000", group: .china, name: "山西", shortName: "晋",
                        primaryColor: Color(hex: "#6C3483"), secondaryColor: Color(hex: "#512E5F"),
                        symbolChar: "🏛", symbolIsEmoji: true),
        BadgeDefinition(id: "150000", group: .china, name: "内蒙古", shortName: "蒙",
                        primaryColor: Color(hex: "#1A5276"), secondaryColor: Color(hex: "#154360"),
                        symbolChar: "🐎", symbolIsEmoji: true),

        // ── 东北 ──
        BadgeDefinition(id: "210000", group: .china, name: "辽宁", shortName: "辽",
                        primaryColor: Color(hex: "#0E6655"), secondaryColor: Color(hex: "#0B5345"),
                        symbolChar: "🌊", symbolIsEmoji: true),
        BadgeDefinition(id: "220000", group: .china, name: "吉林", shortName: "吉",
                        primaryColor: Color(hex: "#145A32"), secondaryColor: Color(hex: "#0B5345"),
                        symbolChar: "🌲", symbolIsEmoji: true),
        BadgeDefinition(id: "230000", group: .china, name: "黑龙江", shortName: "黑",
                        primaryColor: Color(hex: "#1B4F72"), secondaryColor: Color(hex: "#154360"),
                        symbolChar: "❄️", symbolIsEmoji: true),

        // ── 华东 ──
        BadgeDefinition(id: "310000", group: .china, name: "上海", shortName: "沪",
                        primaryColor: Color(hex: "#1F618D"), secondaryColor: Color(hex: "#154360"),
                        symbolChar: "🌆", symbolIsEmoji: true),
        BadgeDefinition(id: "320000", group: .china, name: "江苏", shortName: "苏",
                        primaryColor: Color(hex: "#117A65"), secondaryColor: Color(hex: "#0E6655"),
                        symbolChar: "🌸", symbolIsEmoji: true),
        BadgeDefinition(id: "330000", group: .china, name: "浙江", shortName: "浙",
                        primaryColor: Color(hex: "#1A5276"), secondaryColor: Color(hex: "#154360"),
                        symbolChar: "☂️", symbolIsEmoji: true),
        BadgeDefinition(id: "340000", group: .china, name: "安徽", shortName: "皖",
                        primaryColor: Color(hex: "#784212"), secondaryColor: Color(hex: "#6E2C00"),
                        symbolChar: "🏞", symbolIsEmoji: true),
        BadgeDefinition(id: "350000", group: .china, name: "福建", shortName: "闽",
                        primaryColor: Color(hex: "#1D8348"), secondaryColor: Color(hex: "#145A32"),
                        symbolChar: "🌺", symbolIsEmoji: true),
        BadgeDefinition(id: "360000", group: .china, name: "江西", shortName: "赣",
                        primaryColor: Color(hex: "#922B21"), secondaryColor: Color(hex: "#7B241C"),
                        symbolChar: "🌹", symbolIsEmoji: true),
        BadgeDefinition(id: "370000", group: .china, name: "山东", shortName: "鲁",
                        primaryColor: Color(hex: "#2874A6"), secondaryColor: Color(hex: "#21618C"),
                        symbolChar: "⛵", symbolIsEmoji: true),

        // ── 华中 ──
        BadgeDefinition(id: "410000", group: .china, name: "河南", shortName: "豫",
                        primaryColor: Color(hex: "#873600"), secondaryColor: Color(hex: "#6E2C00"),
                        symbolChar: "🐉", symbolIsEmoji: true),
        BadgeDefinition(id: "420000", group: .china, name: "湖北", shortName: "鄂",
                        primaryColor: Color(hex: "#B7950B"), secondaryColor: Color(hex: "#9A7D0A"),
                        symbolChar: "🌉", symbolIsEmoji: true),
        BadgeDefinition(id: "430000", group: .china, name: "湖南", shortName: "湘",
                        primaryColor: Color(hex: "#6D4C41"), secondaryColor: Color(hex: "#4E342E"),
                        symbolChar: "🌶", symbolIsEmoji: true),

        // ── 华南 ──
        BadgeDefinition(id: "440000", group: .china, name: "广东", shortName: "粤",
                        primaryColor: Color(hex: "#C0392B"), secondaryColor: Color(hex: "#A93226"),
                        symbolChar: "🌴", symbolIsEmoji: true),
        BadgeDefinition(id: "450000", group: .china, name: "广西", shortName: "桂",
                        primaryColor: Color(hex: "#196F3D"), secondaryColor: Color(hex: "#145A32"),
                        symbolChar: "🎋", symbolIsEmoji: true),
        BadgeDefinition(id: "460000", group: .china, name: "海南", shortName: "琼",
                        primaryColor: Color(hex: "#0097A7"), secondaryColor: Color(hex: "#00838F"),
                        symbolChar: "🏖", symbolIsEmoji: true),

        // ── 西南 ──
        BadgeDefinition(id: "500000", group: .china, name: "重庆", shortName: "渝",
                        primaryColor: Color(hex: "#C0392B"), secondaryColor: Color(hex: "#A93226"),
                        symbolChar: "🌁", symbolIsEmoji: true),
        BadgeDefinition(id: "510000", group: .china, name: "四川", shortName: "川",
                        primaryColor: Color(hex: "#B7950B"), secondaryColor: Color(hex: "#9A7D0A"),
                        symbolChar: "🐼", symbolIsEmoji: true),
        BadgeDefinition(id: "520000", group: .china, name: "贵州", shortName: "黔",
                        primaryColor: Color(hex: "#1D8348"), secondaryColor: Color(hex: "#145A32"),
                        symbolChar: "🌊", symbolIsEmoji: true),
        BadgeDefinition(id: "530000", group: .china, name: "云南", shortName: "滇",
                        primaryColor: Color(hex: "#7D3C98"), secondaryColor: Color(hex: "#6C3483"),
                        symbolChar: "🌈", symbolIsEmoji: true),
        BadgeDefinition(id: "540000", group: .china, name: "西藏", shortName: "藏",
                        primaryColor: Color(hex: "#C0392B"), secondaryColor: Color(hex: "#6C3483"),
                        symbolChar: "⛰", symbolIsEmoji: true),

        // ── 西北 ──
        BadgeDefinition(id: "610000", group: .china, name: "陕西", shortName: "陕",
                        primaryColor: Color(hex: "#784212"), secondaryColor: Color(hex: "#6E2C00"),
                        symbolChar: "🏺", symbolIsEmoji: true),
        BadgeDefinition(id: "620000", group: .china, name: "甘肃", shortName: "甘",
                        primaryColor: Color(hex: "#5D4037"), secondaryColor: Color(hex: "#4E342E"),
                        symbolChar: "🐪", symbolIsEmoji: true),
        BadgeDefinition(id: "630000", group: .china, name: "青海", shortName: "青",
                        primaryColor: Color(hex: "#1A5276"), secondaryColor: Color(hex: "#154360"),
                        symbolChar: "🦅", symbolIsEmoji: true),
        BadgeDefinition(id: "640000", group: .china, name: "宁夏", shortName: "宁",
                        primaryColor: Color(hex: "#2E4057"), secondaryColor: Color(hex: "#1B2A3B"),
                        symbolChar: "🌙", symbolIsEmoji: true),
        BadgeDefinition(id: "650000", group: .china, name: "新疆", shortName: "新",
                        primaryColor: Color(hex: "#1A5276"), secondaryColor: Color(hex: "#7D6608"),
                        symbolChar: "🍇", symbolIsEmoji: true),

        // ── 港澳台 ──
        BadgeDefinition(id: "710000", group: .china, name: "台湾", shortName: "台",
                        primaryColor: Color(hex: "#1F618D"), secondaryColor: Color(hex: "#117A65"),
                        symbolChar: "🗻", symbolIsEmoji: true),
        BadgeDefinition(id: "810000", group: .china, name: "香港", shortName: "港",
                        primaryColor: Color(hex: "#7B241C"), secondaryColor: Color(hex: "#922B21"),
                        symbolChar: "🌃", symbolIsEmoji: true),
        BadgeDefinition(id: "820000", group: .china, name: "澳门", shortName: "澳",
                        primaryColor: Color(hex: "#6D4C41"), secondaryColor: Color(hex: "#4E342E"),
                        symbolChar: "🎰", symbolIsEmoji: true),
    ]

    // MARK: USA — adm1_code strings (e.g. "USA-3521" for California)
    // These match the adm1_code field used by FootprintGeoJSONLoader as fallback ID
    static let usa: [BadgeDefinition] = [
        BadgeDefinition(id: "USA-3521", group: .usa, name: "加利福尼亚", shortName: "CA",
                        primaryColor: Color(hex: "#F39C12"), secondaryColor: Color(hex: "#D68910"),
                        symbolChar: "🌅", symbolIsEmoji: true),
        BadgeDefinition(id: "USA-3559", group: .usa, name: "纽约", shortName: "NY",
                        primaryColor: Color(hex: "#2471A3"), secondaryColor: Color(hex: "#1A5276"),
                        symbolChar: "🗽", symbolIsEmoji: true),
        BadgeDefinition(id: "USA-3536", group: .usa, name: "德克萨斯", shortName: "TX",
                        primaryColor: Color(hex: "#B03A2E"), secondaryColor: Color(hex: "#922B21"),
                        symbolChar: "🤠", symbolIsEmoji: true),
        BadgeDefinition(id: "USA-3542", group: .usa, name: "佛罗里达", shortName: "FL",
                        primaryColor: Color(hex: "#F39C12"), secondaryColor: Color(hex: "#E67E22"),
                        symbolChar: "🌴", symbolIsEmoji: true),
        BadgeDefinition(id: "USA-3517", group: .usa, name: "夏威夷", shortName: "HI",
                        primaryColor: Color(hex: "#0097A7"), secondaryColor: Color(hex: "#00838F"),
                        symbolChar: "🌺", symbolIsEmoji: true),
        BadgeDefinition(id: "USA-3563", group: .usa, name: "阿拉斯加", shortName: "AK",
                        primaryColor: Color(hex: "#1A5276"), secondaryColor: Color(hex: "#154360"),
                        symbolChar: "🐻‍❄️", symbolIsEmoji: true),
        BadgeDefinition(id: "USA-3519", group: .usa, name: "华盛顿州", shortName: "WA",
                        primaryColor: Color(hex: "#1D8348"), secondaryColor: Color(hex: "#145A32"),
                        symbolChar: "🌲", symbolIsEmoji: true),
        BadgeDefinition(id: "USA-3522", group: .usa, name: "科罗拉多", shortName: "CO",
                        primaryColor: Color(hex: "#6C3483"), secondaryColor: Color(hex: "#512E5F"),
                        symbolChar: "⛷️", symbolIsEmoji: true),
        BadgeDefinition(id: "USA-3546", group: .usa, name: "伊利诺伊", shortName: "IL",
                        primaryColor: Color(hex: "#2874A6"), secondaryColor: Color(hex: "#21618C"),
                        symbolChar: "🏙", symbolIsEmoji: true),
        BadgeDefinition(id: "USA-3523", group: .usa, name: "内华达", shortName: "NV",
                        primaryColor: Color(hex: "#C0392B"), secondaryColor: Color(hex: "#B7950B"),
                        symbolChar: "🎰", symbolIsEmoji: true),
    ]

    // MARK: Japan — adm1_code strings
    // Hokkaidō → JPN-1847, Kyōto → JPN-1850, Ōsaka → JPN-1852
    static let japan: [BadgeDefinition] = [
        BadgeDefinition(id: "JPN-1860", group: .japan, name: "东京", shortName: "東京",
                        primaryColor: Color(hex: "#C0392B"), secondaryColor: Color(hex: "#922B21"),
                        symbolChar: "🗼", symbolIsEmoji: true),
        BadgeDefinition(id: "JPN-1852", group: .japan, name: "大阪", shortName: "大阪",
                        primaryColor: Color(hex: "#F39C12"), secondaryColor: Color(hex: "#D68910"),
                        symbolChar: "🏯", symbolIsEmoji: true),
        BadgeDefinition(id: "JPN-1850", group: .japan, name: "京都", shortName: "京都",
                        primaryColor: Color(hex: "#922B21"), secondaryColor: Color(hex: "#7B241C"),
                        symbolChar: "⛩️", symbolIsEmoji: true),
        BadgeDefinition(id: "JPN-1847", group: .japan, name: "北海道", shortName: "北海",
                        primaryColor: Color(hex: "#1A5276"), secondaryColor: Color(hex: "#154360"),
                        symbolChar: "❄️", symbolIsEmoji: true),
        BadgeDefinition(id: "JPN-1829", group: .japan, name: "福冈", shortName: "福冈",
                        primaryColor: Color(hex: "#1D8348"), secondaryColor: Color(hex: "#145A32"),
                        symbolChar: "🌸", symbolIsEmoji: true),
        BadgeDefinition(id: "JPN-1857", group: .japan, name: "神奈川", shortName: "神奈",
                        primaryColor: Color(hex: "#2874A6"), secondaryColor: Color(hex: "#21618C"),
                        symbolChar: "🗻", symbolIsEmoji: true),
        BadgeDefinition(id: "JPN-1840", group: .japan, name: "爱知", shortName: "爱知",
                        primaryColor: Color(hex: "#117A65"), secondaryColor: Color(hex: "#0E6655"),
                        symbolChar: "🏭", symbolIsEmoji: true),
        BadgeDefinition(id: "JPN-3502", group: .japan, name: "冲绳", shortName: "冲绳",
                        primaryColor: Color(hex: "#0097A7"), secondaryColor: Color(hex: "#00838F"),
                        symbolChar: "🏝", symbolIsEmoji: true),
    ]

    // MARK: - Convenience accessors
    static let allBadges: [BadgeDefinition] = china + usa + japan

    static func badges(for group: BadgeGroup) -> [BadgeDefinition] {
        switch group {
        case .china: return china
        case .usa:   return usa
        case .japan: return japan
        }
    }
}
