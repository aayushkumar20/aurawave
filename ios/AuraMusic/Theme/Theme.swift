import SwiftUI

public struct AuraColors {
    public static let background = Color(hex: "#090D16")
    public static let backgroundSecondary = Color(hex: "#0F172A")
    public static let surface = Color(hex: "#131824")
    public static let surfaceLight = Color(hex: "#1E2536")
    public static let primary = Color(hex: "#6366F1")
    public static let cyan = Color(hex: "#06B6D4")
    public static let pink = Color(hex: "#EC4899")
    public static let emerald = Color(hex: "#10B981")
    public static let textPrimary = Color.white
    public static let textSecondary = Color(hex: "#94A3B8")
    public static let textMuted = Color(hex: "#64748B")
}

extension Color {
    public init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 99, 102, 241) // Fallback to indigo
        }

        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}
