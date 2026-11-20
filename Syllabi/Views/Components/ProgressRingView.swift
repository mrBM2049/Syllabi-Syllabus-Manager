import SwiftUI

public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 59, 130, 246)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

public struct ProgressRingView: View {
    public var progress: Double
    public var lineWidth: CGFloat = 3.0
    public var color: Color = .accentColor
    public var showPercentage: Bool = false
    public var fontSize: CGFloat = 11

    public init(
        progress: Double,
        lineWidth: CGFloat = 3.0,
        color: Color = .accentColor,
        showPercentage: Bool = false,
        fontSize: CGFloat = 11
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.color = color
        self.showPercentage = showPercentage
        self.fontSize = fontSize
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.14), lineWidth: lineWidth)

            Circle()
                .trim(from: 0.0, to: CGFloat(min(max(progress, 0.0), 1.0)))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            if showPercentage {
                Text("\(Int(round(progress * 100)))%")
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
    }
}
