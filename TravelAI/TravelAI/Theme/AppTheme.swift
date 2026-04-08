import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let background = Color(hex: "#1E1408")
    static let cardBackground = Color(hex: "#2C1F0E")
    static let gold = Color(hex: "#D4A017")
    static let goldSecondary = Color(hex: "#C8A84B")
    static let textPrimary = Color(hex: "#E8D5A0")
    static let textSecondary = Color(hex: "#8A7A5A")
    static let border = Color(hex: "#5A3E10")

    // MARK: - Layout
    static let cardRadius: CGFloat = 12
    static let padding: CGFloat = 16
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
