import SwiftUI

enum SlackTheme {
    // Sidebar
    static let sidebarBg = Color(hex: "3f0e40")
    static let sidebarBorder = Color(hex: "522653")
    static let sidebarText = Color(hex: "c6b9c8")
    static let sidebarInputBg = Color(hex: "522653")
    static let selectedChannel = Color(hex: "1164a3")

    // Main area
    static let mainBg = Color(hex: "1a1d21")
    static let messageHoverBg = Color(hex: "222529")

    // Text
    static let primaryText = Color(hex: "d1d2d3")
    static let secondaryText = Color(hex: "9b9c9e")
    static let mutedText = Color(hex: "565758")
    static let linkText = Color(hex: "1d9bd1")
    static let mentionText = Color(hex: "1d9bd1")

    // UI elements
    static let divider = Color(hex: "3d3d3f")
    static let codeBg = Color(hex: "2c2d30")
    static let codeText = Color(hex: "e06c75")
    static let codeBlockText = Color(hex: "abb2bf")
    static let attachmentBg = Color(hex: "222529")

    // Thread button
    static let threadBtnText = Color(hex: "1d9bd1")

    // User color palette (fallback when user has no color)
    static let colorPalette: [String] = [
        "E07B54", "3EB891", "5BA4CF", "E96699",
        "78D64B", "F2952F", "9B59B6", "1ABC9C",
        "E74C3C", "2980B9", "27AE60", "D35400",
    ]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    init(slackColor: String) {
        self.init(hex: slackColor)
    }
}
