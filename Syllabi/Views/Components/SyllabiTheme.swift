import SwiftUI
import AppKit

public enum SyllabiTheme {
    public static let ink = Color(light: "#201B4A", dark: "#F5F3FF")
    public static let secondaryText = Color(light: "#6D6984", dark: "#B7B2CC")
    public static let canvas = Color(light: "#F7F7FA", dark: "#161521")
    public static let surface = Color(light: "#FFFFFF", dark: "#211F2D")
    public static let lavender = Color(light: "#C7B8FF", dark: "#6558A8")
    public static let mint = Color(light: "#B8E4D2", dark: "#397A64")
    public static let peach = Color(light: "#FFD98A", dark: "#9D7130")
    public static let accent = Color(light: "#3C2D8F", dark: "#9D91FF")
}

private extension Color {
    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(hex: hex)
        })
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let value = Int(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255, blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}
