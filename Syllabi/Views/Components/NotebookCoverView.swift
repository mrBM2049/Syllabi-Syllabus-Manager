import SwiftUI

public enum NotebookBindingStyle {
    case spiral
    case bound
}

public struct NotebookCoverView: View {
    public let subject: Subject
    public var style: NotebookBindingStyle = .spiral
    public var onClick: () -> Void
    public var isActive: Bool = false
    public var onMarkActive: (() -> Void)? = nil

    @State private var isHovering = false

    public init(
        subject: Subject,
        style: NotebookBindingStyle = .spiral,
        onClick: @escaping () -> Void,
        isActive: Bool = false,
        onMarkActive: (() -> Void)? = nil
    ) {
        self.subject = subject
        self.style = style
        self.onClick = onClick
        self.isActive = isActive
        self.onMarkActive = onMarkActive
    }

    private var coverColor: Color {
        Color(hex: subject.colorHex)
    }

    private var coverIsDark: Bool {
        let value = Int(subject.colorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return (0.299 * red) + (0.587 * green) + (0.114 * blue) < 0.52
    }

    private var codeTextColor: Color {
        isActive ? Color.black : (coverIsDark ? coverColor : Color.black)
    }

    private var codeBackgroundColor: Color {
        isActive ? SyllabiTheme.mint : Color.white.opacity(0.95)
    }

    private var coverForeground: Color {
        coverIsDark ? Color.white : Color.black
    }

    private var coverMutedForeground: Color {
        coverIsDark ? Color.white.opacity(0.84) : Color.black.opacity(0.72)
    }

    private var coverProgressTrack: Color {
        coverIsDark ? Color.black.opacity(0.24) : Color.black.opacity(0.14)
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onClick) {
                ZStack(alignment: .leading) {
                // Layer 1: Right-edge Paper Pages Peeking Out (Physical Book Depth)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.98, green: 0.97, blue: 0.94))
                    .frame(width: 195, height: 250)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.6)
                    )
                    .shadow(
                        color: Color.black.opacity(isHovering ? 0.22 : 0.12),
                        radius: isHovering ? 18 : 10,
                        x: 4,
                        y: isHovering ? 10 : 6
                    )
                    .offset(x: 10, y: 0)

                // Layer 2: Main Notebook Front Cover
                ZStack(alignment: .topLeading) {
                    // Cover Surface
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    coverColor.opacity(0.92),
                                    coverColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 195, height: 250)

                    // Liquid Glass Sheen Overlay
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.28), location: 0),
                                    .init(color: .white.opacity(0.04), location: 0.4),
                                    .init(color: .black.opacity(0.12), location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 195, height: 250)

                    // Subtle cover edge stroke
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
                        .frame(width: 195, height: 250)

                    // Front Cover Content
                    VStack(alignment: .leading, spacing: 0) {
                        // Top Sticker Label / Course Code Pill
                        HStack(alignment: .top) {
                            if !subject.code.isEmpty {
                                if let onMarkActive {
                                    Button(action: onMarkActive) {
                                        Text(isHovering && !isActive ? "Make active" : subject.code)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(codeTextColor)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3.5)
                                            .background(codeBackgroundColor, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .help(isActive ? "Current project" : "Make this course active")
                                } else {
                                    Text(subject.code)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(codeTextColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3.5)
                                        .background(codeBackgroundColor, in: Capsule())
                                }
                            } else {
                                if let onMarkActive, isActive || isHovering {
                                    Button(action: onMarkActive) {
                                        Text(isActive ? "Active" : "Make active")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.black)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 4)
                                            .background(isActive ? SyllabiTheme.mint : Color.white.opacity(0.95), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .help(isActive ? "Current project" : "Make this course active")
                                } else {
                                    Spacer()
                                }
                            }

                            Spacer()

                            // Course Icon (SF Symbol or Custom .ico Image)
                            ZStack {
                                Circle()
                                    .fill(coverForeground.opacity(0.16))
                                    .frame(width: 32, height: 32)

                                SubjectIconView(subject: subject, size: 18, foregroundColor: coverForeground)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 16)
                        .padding(.leading, style == .spiral ? 14 : 6)

                        // Notebook Title & Term
                        VStack(alignment: .leading, spacing: 5) {
                            Text(subject.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(coverForeground)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .shadow(color: Color.black.opacity(0.15), radius: 1, y: 1)

                            if !subject.term.isEmpty {
                                Text(subject.term)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(coverMutedForeground)
                            }
                        }
                        .padding(.top, 14)
                        .padding(.horizontal, 16)
                        .padding(.leading, style == .spiral ? 14 : 6)

                        Spacer()

                        // Bottom Progress & Stats Block
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(Int(round(subject.progress * 100)))%")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(coverForeground)

                                Spacer()

                                Text("\(subject.completedTopicsCount)/\(subject.totalTopicsCount)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(coverMutedForeground)
                            }

                            // Sleek Mini Progress Bar on Cover
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(coverProgressTrack)
                                        .frame(height: 5)

                                    Capsule()
                                        .fill(coverForeground)
                                        .frame(width: max(0, min(geo.size.width * CGFloat(subject.progress), geo.size.width)), height: 5)
                                }
                            }
                            .frame(height: 5)

                            Text("\(subject.units.count) units")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(coverMutedForeground)
                                .padding(.top, 1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .padding(.leading, style == .spiral ? 14 : 6)
                    }
                    .frame(width: 195, height: 250)
                }

                // Layer 3: Left Binding (Spiral Wire Coil or Bound Spine Strip)
                if style == .spiral {
                    // Realistic Metallic Spiral Wire Rings (matching Image 1)
                    SpiralWireBinding(height: 250)
                        .offset(x: 2)
                } else {
                    // Stitched Leather/Cloth Book Spine
                    BookSpineStrip(height: 250, color: coverColor)
                }
            }
                .frame(width: 215, height: 260)
                .scaleEffect(isHovering ? 1.03 : 1.0)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovering)
            }
            .buttonStyle(.plain)

        }
        .onHover { isHovering = $0 }
    }
}

// MARK: - Spiral Wire Coil Component (Matches "Handy Bound" in Image 1)

struct SpiralWireBinding: View {
    var height: CGFloat
    private let coilCount = 14

    var body: some View {
        VStack(spacing: (height - 30 - CGFloat(coilCount * 8)) / CGFloat(coilCount - 1)) {
            ForEach(0..<coilCount, id: \.self) { _ in
                ZStack {
                    // Coil hole in paper
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 6, height: 6)

                    // Metallic Wire Ring Loop
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.95),
                                    Color(white: 0.65),
                                    Color(white: 0.85),
                                    Color(white: 0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 18, height: 7)
                        .shadow(color: Color.black.opacity(0.25), radius: 1, x: 1, y: 1)
                        .offset(x: -3)
                }
            }
        }
        .padding(.vertical, 15)
        .frame(width: 20, height: height)
    }
}

// MARK: - Stitched Spine Strip Component

struct BookSpineStrip: View {
    var height: CGFloat
    var color: Color

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.35),
                            Color.black.opacity(0.1),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 14, height: height)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 14,
                        bottomLeadingRadius: 14,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

            // Vertical Crease / Stitch line
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(width: 1, height: height)
        }
    }
}
