import SwiftUI

enum ChatTheme {
    static let accent = color("00806D")
    static let accentBackground = color("E7F7F2")
    static let primaryText = color("111827")
    static let secondaryText = color("667085")
    static let searchBackground = color("F2F3F5")
    static let separator = color("E5E7EB")
    static let mutedBadge = color("667085")

    static func color(_ hex: String) -> Color {
        let value = UInt32(hex, radix: 16) ?? 0
        return Color(red: Double((value >> 16) & 0xff) / 255,
                     green: Double((value >> 8) & 0xff) / 255,
                     blue: Double(value & 0xff) / 255)
    }
}
