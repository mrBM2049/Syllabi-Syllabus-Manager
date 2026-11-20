import SwiftUI

public struct ModernProgressBar: View {
    public var title: String
    public var progress: Double
    public var height: CGFloat = 16
    public var accentColor: Color = Color(red: 0.22, green: 0.32, blue: 0.99) // Vibrant Cobalt

    public init(
        title: String,
        progress: Double,
        height: CGFloat = 16,
        accentColor: Color = Color(red: 0.22, green: 0.32, blue: 0.99)
    ) {
        self.title = title
        self.progress = progress
        self.height = height
        self.accentColor = accentColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(Int(round(progress * 100)))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Hatched / striped pattern background for remaining progress
                    HatchedTrack(height: height)

                    // Solid active progress bar
                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)), height: height)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: progress)
                }
            }
            .frame(height: height)
        }
    }
}

// Hatched / diagonal stripes background track (as seen in the reference image)
struct HatchedTrack: View {
    var height: CGFloat

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.primary.opacity(0.04))

            Canvas { context, size in
                let strokeWidth: CGFloat = 1.8
                let spacing: CGFloat = 7
                let path = Path { p in
                    var x: CGFloat = -size.height
                    while x < size.width + size.height {
                        p.move(to: CGPoint(x: x, y: size.height))
                        p.addLine(to: CGPoint(x: x + size.height, y: 0))
                        x += spacing
                    }
                }
                context.stroke(path, with: .color(Color.primary.opacity(0.12)), lineWidth: strokeWidth)
            }
            .clipShape(Capsule())
        }
    }
}
