import SwiftUI

// MARK: - Design Philosophy
// Claude (Anthropic) 设计语言 — getdesign claude
// • Parchment canvas #f5f4ed — 羊皮纸底，不是纯白不是冷灰
// • Terracotta accent #c96442 — 赤陶橙，唯一品牌色，温暖不科技感
// • New York serif 标题 — weight 500，书名感权威
// • SF Pro 功能文字 — 导航/标签/按钮
// • Ring shadow 系统 — 0px 0px 0px 1px，不用 drop shadow
// • 所有中性色带暖黄底色 — 无任何冷蓝灰

enum AppTheme {

    // MARK: - Surface
    static let pageBG       = Color(hex: "#f5f4ed")   // Parchment — 主页面底色
    static let cardBG       = Color(hex: "#faf9f5")   // Ivory — 卡片
    static let cardBGAlt    = Color(hex: "#ffffff")   // Pure White — 强调卡片
    static let sectionBG    = Color(hex: "#ede8de")   // Warm Sand 区块背景
    static let navBG        = Color(hex: "#f0ede5")   // 导航栏底色

    // MARK: - Text（全部暖调，无冷灰）
    static let textPrimary      = Color(hex: "#141413")   // Near Black（微橄榄暖黑）
    static let textSecondary    = Color(hex: "#5e5d59")   // Olive Gray
    static let textTertiary     = Color(hex: "#87867f")   // Stone Gray
    static let textOnDark       = Color(hex: "#f5f4ed")   // 暗背景文字（Parchment 色）
    static let textOnAccent     = Color(hex: "#faf9f5")   // 强调色按钮上的文字

    // MARK: - Brand Accent（Terracotta 系）
    static let accent           = Color(hex: "#c96442")   // Terracotta Brand — 主 CTA、高亮
    static let accentLight      = Color(hex: "#d97757")   // Coral — 次级强调、文字链接
    static let accentBG         = Color(hex: "#fdf0eb")   // Terracotta 淡背景
    static let accentBGDeep     = Color(hex: "#f8e0d5")   // 深一点的 accent 背景

    // MARK: - 向后兼容 gold 别名（逐步迁移）
    static var gold: Color { accent }
    static var goldLight: Color { accentLight }
    static var goldBG: Color { accentBG }
    static var goldBGDeep: Color { accentBGDeep }

    // MARK: - Border（极轻暖调）
    static let border           = Color(hex: "#e8e6dc")   // Border Warm — 主边框
    static let borderSubtle     = Color(hex: "#f0eee6")   // Border Cream — 极轻分割
    static let borderStrong     = Color(hex: "#d1cfc5")   // Ring Warm — 强调边框/ring

    // MARK: - Dark Surface（暗色区块，用于 section 对比）
    static let darkSurface      = Color(hex: "#30302e")   // Dark Surface
    static let darkBG           = Color(hex: "#141413")   // Near Black

    // MARK: - Semantic
    static let red              = Color(hex: "#b53333")   // Error Crimson
    static let redBG            = Color(hex: "#fdf0ee")
    static let teal             = Color(hex: "#0E8A6E")
    static let tealBG           = Color(hex: "#e8f7f3")
    static let blue             = Color(hex: "#3898ec")   // Focus Blue（唯一冷色，仅用于 focus ring）
    static let blueBG           = Color(hex: "#eff4ff")

    // MARK: - Gradients
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#d97757"), Color(hex: "#b05030")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
    // 向后兼容
    static var goldGradient: LinearGradient { accentGradient }

    static var pageBGGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#f5f4ed"), Color(hex: "#ede9df")],
            startPoint: .top, endPoint: .bottom
        )
    }
    static var backgroundGradient: LinearGradient { pageBGGradient }

    // MARK: - Shadows（ring + whisper 系统）
    /// 标准卡片阴影 — 极软，模拟纸张叠放
    static func cardShadow(opacity: Double = 1.0) -> Shadow {
        Shadow(color: Color(hex: "#141413").opacity(0.05 * opacity), radius: 12, x: 0, y: 3)
    }
    static func cardShadowStrong() -> Shadow {
        Shadow(color: Color(hex: "#141413").opacity(0.09), radius: 20, x: 0, y: 6)
    }
    /// Terracotta glow — 用于 accent 按钮
    static func accentGlow(opacity: Double = 1.0) -> Shadow {
        Shadow(color: Color(hex: "#c96442").opacity(0.28 * opacity), radius: 10, x: 0, y: 0)
    }
    static func goldGlow(opacity: Double = 1.0) -> Shadow { accentGlow(opacity: opacity) }

    /// Whisper lift — 卡片悬浮感
    static func softLift() -> Shadow {
        Shadow(color: Color(hex: "#141413").opacity(0.06), radius: 16, x: 0, y: 4)
    }

    // MARK: - Layout
    static let cardRadius: CGFloat      = 12
    static let cardRadiusSmall: CGFloat = 8
    static let cardRadiusLarge: CGFloat = 18
    static let padding: CGFloat         = 16
    static let paddingSmall: CGFloat    = 10
    static let paddingLarge: CGFloat    = 24

    // MARK: - Spacing scale
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Animation
    static let animSnappy = Animation.spring(response: 0.28, dampingFraction: 0.72)
    static let animSmooth = Animation.easeInOut(duration: 0.22)
    static let animBounce = Animation.spring(response: 0.4,  dampingFraction: 0.6)
}

// MARK: - Typography（Claude 字体系统）
// Serif（New York）用于标题/展示，赋予权威感
// Sans（SF Pro）用于 UI/功能文字
// Mono（SF Mono）用于代码/时间

enum AppFont {
    // Serif 标题（New York，weight .medium = 500）
    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .medium, design: .serif)
    }
    static func heading(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .medium, design: .serif)
    }
    static func headingSmall(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .medium, design: .serif)
    }

    // Sans 功能文字（SF Pro）
    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func label(_ size: CGFloat = 12, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight)
    }
    static func caption(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // Mono 时间/数字
    static func mono(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}

// MARK: - Font Size Scale
enum AppFontSize {
    static let display:   CGFloat = 34
    static let h1:        CGFloat = 26
    static let h2:        CGFloat = 20
    static let h3:        CGFloat = 17
    static let body:      CGFloat = 16
    static let bodySmall: CGFloat = 14
    static let caption:   CGFloat = 12
    static let micro:     CGFloat = 10
}

// MARK: - Per-page accent（每页专属色，均在 Parchment 底上清晰可读）
enum PageAccent {
    static let itinerary    = Color(hex: "#c96442")   // Terracotta — 行程页与品牌色一致
    static let culture      = Color(hex: "#2a7a8c")   // 深石板青
    static let map          = Color(hex: "#2a7a4a")   // 深探险绿
    static let chat         = Color(hex: "#3b5fc0")   // 深靛蓝
    static let tools        = Color(hex: "#8b4513")   // 深赤陶棕

    static let itineraryBG  = Color(hex: "#fdf0eb")
    static let cultureBG    = Color(hex: "#e0f2f5")
    static let mapBG        = Color(hex: "#e0f5e8")
    static let chatBG       = Color(hex: "#eef2ff")
    static let toolsBG      = Color(hex: "#f5ede8")
}

// MARK: - Destination accent（首页卡片：亮色系，左侧彩条 + 图标色）
struct DestinationAccent {
    let color: Color       // 主强调色（用于左侧竖条、图标、标签）
    let bgColor: Color     // 极淡背景（用于卡片底色）
    let emoji: String
    let label: String      // 地区标签
}

func destinationAccent(for destination: String) -> DestinationAccent {
    let key = destination.lowercased()
    if key.contains("egypt") || key.contains("埃及") || key.contains("morocco") || key.contains("摩洛哥") || key.contains("dubai") || key.contains("迪拜") {
        return DestinationAccent(color: Color(hex: "#b87320"), bgColor: Color(hex: "#fdf5e8"), emoji: key.contains("egypt") || key.contains("埃及") ? "🏺" : key.contains("dubai") ? "🏙️" : "🪔", label: "中东 · 北非")
    }
    if key.contains("japan") || key.contains("日本") || key.contains("tokyo") || key.contains("东京") || key.contains("kyoto") || key.contains("京都") {
        return DestinationAccent(color: Color(hex: "#c0405a"), bgColor: Color(hex: "#fdf0f2"), emoji: "⛩️", label: "东亚")
    }
    if key.contains("china") || key.contains("中国") || key.contains("beijing") || key.contains("北京") || key.contains("shanghai") || key.contains("上海") {
        return DestinationAccent(color: Color(hex: "#c03030"), bgColor: Color(hex: "#fdf0f0"), emoji: "🐉", label: "中国")
    }
    if key.contains("greece") || key.contains("希腊") || key.contains("santorini") || key.contains("croatia") || key.contains("portugal") || key.contains("葡萄牙") {
        return DestinationAccent(color: Color(hex: "#1a6090"), bgColor: Color(hex: "#eaf4fb"), emoji: key.contains("greece") || key.contains("希腊") || key.contains("santorini") ? "🏛️" : "⛵", label: "地中海")
    }
    if key.contains("france") || key.contains("法国") || key.contains("paris") || key.contains("巴黎") || key.contains("italy") || key.contains("意大利") || key.contains("spain") || key.contains("西班牙") {
        return DestinationAccent(color: Color(hex: "#6040a0"), bgColor: Color(hex: "#f2eefb"), emoji: key.contains("france") || key.contains("paris") || key.contains("法国") ? "🗼" : key.contains("italy") || key.contains("意大利") ? "🍕" : "💃", label: "欧洲")
    }
    if key.contains("thailand") || key.contains("泰国") || key.contains("bali") || key.contains("巴厘") || key.contains("vietnam") || key.contains("越南") || key.contains("maldives") || key.contains("马尔代夫") {
        return DestinationAccent(color: Color(hex: "#187850"), bgColor: Color(hex: "#e8f8f0"), emoji: key.contains("thailand") || key.contains("泰国") ? "🐘" : key.contains("bali") ? "🌺" : "🌴", label: "东南亚")
    }
    if key.contains("iceland") || key.contains("冰岛") || key.contains("norway") || key.contains("挪威") || key.contains("sweden") || key.contains("瑞典") {
        return DestinationAccent(color: Color(hex: "#1a6878"), bgColor: Color(hex: "#e8f4f8"), emoji: key.contains("iceland") || key.contains("冰岛") ? "🌋" : "🌌", label: "北欧")
    }
    if key.contains("india") || key.contains("印度") || key.contains("nepal") || key.contains("尼泊尔") {
        return DestinationAccent(color: Color(hex: "#b85820"), bgColor: Color(hex: "#fdf2ea"), emoji: "🕌", label: "南亚")
    }
    if key.contains("usa") || key.contains("america") || key.contains("美国") || key.contains("new york") || key.contains("纽约") {
        return DestinationAccent(color: Color(hex: "#1a3a78"), bgColor: Color(hex: "#eaeffb"), emoji: "🗽", label: "北美")
    }
    if key.contains("peru") || key.contains("秘鲁") || key.contains("mexico") || key.contains("墨西哥") {
        return DestinationAccent(color: Color(hex: "#7a3010"), bgColor: Color(hex: "#faeee8"), emoji: key.contains("peru") || key.contains("秘鲁") ? "🦙" : "🌮", label: "拉丁美洲")
    }
    if key.contains("australia") || key.contains("澳大利亚") || key.contains("new zealand") || key.contains("新西兰") {
        return DestinationAccent(color: Color(hex: "#3a6820"), bgColor: Color(hex: "#eef5e8"), emoji: key.contains("australia") || key.contains("澳大利亚") ? "🦘" : "🥝", label: "大洋洲")
    }
    if key.contains("hanoi") || key.contains("河内") || key.contains("ho chi minh") || key.contains("胡志明") {
        return DestinationAccent(color: Color(hex: "#187850"), bgColor: Color(hex: "#e8f8f0"), emoji: "🌿", label: "东南亚")
    }
    return DestinationAccent(color: AppTheme.accent, bgColor: AppTheme.accentBG, emoji: "✈️", label: "旅行")
}

// MARK: - Shadow helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func appShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    func ringBorder(_ color: Color, opacity: Double = 0.5, width: CGFloat = 1,
                    radius: CGFloat = AppTheme.cardRadius) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(color.opacity(opacity), lineWidth: width)
        )
    }
}

// MARK: - Color hex init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Card modifier
struct AppCardStyle: ViewModifier {
    var elevated: Bool = false
    var accent: Color? = nil
    func body(content: Content) -> some View {
        content
            .background(elevated ? AppTheme.cardBGAlt : AppTheme.cardBG)
            .cornerRadius(AppTheme.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .stroke(accent?.opacity(0.18) ?? AppTheme.borderSubtle, lineWidth: 1)
            )
            .appShadow(AppTheme.softLift())
    }
}

extension View {
    func appCard(elevated: Bool = false, accent: Color? = nil) -> some View {
        modifier(AppCardStyle(elevated: elevated, accent: accent))
    }
}

// MARK: - Primary button style（Terracotta）
struct AccentButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .opacity(enabled ? 1.0 : 0.4)
            .animation(AppTheme.animSnappy, value: configuration.isPressed)
    }
}
// 向后兼容
typealias GoldButtonStyle = AccentButtonStyle

// MARK: - Corner radius helper
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Event color（全局统一，消除跨页面不一致）
func eventColor(for type: String) -> Color {
    switch type {
    case "transport":     return Color(hex: "#3b5fc0")   // 深靛蓝
    case "food":          return Color(hex: "#c96442")   // Terracotta
    case "accommodation": return Color(hex: "#7a42a8")   // 深紫
    default:              return Color(hex: "#2a7a4a")   // 探险绿（景点）
    }
}

func eventEmoji(for type: String) -> String {
    switch type {
    case "transport":     return "✈️"
    case "food":          return "🍽️"
    case "accommodation": return "🏨"
    default:              return "🏛️"
    }
}
