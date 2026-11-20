import SwiftUI

public struct CurvedAccentMark: View {
    public var color: Color = Color(red: 0.22, green: 0.32, blue: 0.99)
    public var strokeWidth: CGFloat = 3.5

    public init(
        color: Color = Color(red: 0.22, green: 0.32, blue: 0.99),
        strokeWidth: CGFloat = 3.5
    ) {
        self.color = color
        self.strokeWidth = strokeWidth
    }

    public var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 2, y: size.height * 0.3))
            path.addCurve(
                to: CGPoint(x: size.width - 2, y: size.height * 0.7),
                control1: CGPoint(x: size.width * 0.35, y: size.height * 0.95),
                control2: CGPoint(x: size.width * 0.7, y: size.height * 0.05)
            )
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
            )
        }
    }
}
