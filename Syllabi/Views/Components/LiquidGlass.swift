import SwiftUI

// MARK: - Apple Liquid Glass Styling

public struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var isInteractive: Bool = false
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    public init(cornerRadius: CGFloat = 16, isInteractive: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
    }

    public func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(colorScheme == .dark ? (isHovered ? 0.35 : 0.22) : (isHovered ? 0.55 : 0.4)), location: 0),
                                .init(color: .white.opacity(0.08), location: 0.5),
                                .init(color: .black.opacity(0.08), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.2 : 0.8
                    )
            }
            .shadow(
                color: Color.black.opacity(isHovered ? 0.12 : 0.05),
                radius: isHovered ? 14 : 8,
                x: 0,
                y: isHovered ? 6 : 3
            )
            .scaleEffect(isInteractive && isHovered ? 1.015 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHovered)
            .onHover { hovering in
                if isInteractive {
                    isHovered = hovering
                }
            }
    }
}

public struct LiquidGlassPillModifier: ViewModifier {
    var isSelected: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    public init(isSelected: Bool = false) {
        self.isSelected = isSelected
    }

    public func body(content: Content) -> some View {
        content
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(Color.primary) : AnyShapeStyle(.ultraThinMaterial))
            }
            .overlay {
                Capsule()
                    .stroke(
                        isSelected ?
                            Color.clear :
                            Color.white.opacity(colorScheme == .dark ? 0.25 : 0.45),
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: Color.black.opacity(isSelected ? 0.15 : 0.04),
                radius: 4,
                x: 0,
                y: 2
            )
    }
}

// MARK: - Native Apple Liquid Glass Button Style

public struct LiquidGlassButtonStyle: ButtonStyle {
    public var isProminent: Bool = false
    public var isDestructive: Bool = false
    public var cornerRadius: CGFloat = 12
    public var tint: Color? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    public init(
        isProminent: Bool = false,
        isDestructive: Bool = false,
        cornerRadius: CGFloat = 12,
        tint: Color? = nil
    ) {
        self.isProminent = isProminent
        self.isDestructive = isDestructive
        self.cornerRadius = cornerRadius
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        let baseTint = tint ?? (isDestructive ? Color.red : Color.accentColor)

        configuration.label
            .font(.system(size: 12, weight: isProminent ? .semibold : .medium))
            .foregroundStyle(
                isProminent ? Color.white :
                isDestructive ? Color.red :
                Color.primary
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6.5)
            .background {
                if isProminent {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    baseTint.opacity(configuration.isPressed ? 0.8 : 0.95),
                                    baseTint.opacity(configuration.isPressed ? 0.9 : 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else if isDestructive {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(baseTint.opacity(configuration.isPressed ? 0.22 : (isHovered ? 0.16 : 0.09)))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(configuration.isPressed ? 0.85 : 1.0)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(
                                    color: isProminent ?
                                        Color.white.opacity(isHovered ? 0.45 : 0.3) :
                                        (colorScheme == .dark ?
                                            Color.white.opacity(isHovered ? 0.35 : 0.2) :
                                            Color.white.opacity(isHovered ? 0.6 : 0.4)),
                                    location: 0
                                ),
                                .init(color: Color.white.opacity(0.05), location: 0.5),
                                .init(
                                    color: isProminent ?
                                        Color.black.opacity(0.2) :
                                        Color.black.opacity(0.08),
                                    location: 1
                                )
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.1 : 0.8
                    )
            }
            .shadow(
                color: isProminent ?
                    baseTint.opacity(isHovered ? 0.35 : 0.2) :
                    Color.black.opacity(isHovered ? 0.1 : 0.04),
                radius: isHovered ? 8 : 4,
                x: 0,
                y: isHovered ? 3 : 1.5
            )
            .scaleEffect(configuration.isPressed ? 0.97 : (isHovered ? 1.02 : 1.0))
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

public extension View {
    func liquidGlass(cornerRadius: CGFloat = 16, isInteractive: Bool = false) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius, isInteractive: isInteractive))
    }

    func liquidGlassPill(isSelected: Bool = false) -> some View {
        self.modifier(LiquidGlassPillModifier(isSelected: isSelected))
    }
}

public extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle()
    }

    static func liquidGlass(prominent: Bool = false, destructive: Bool = false, cornerRadius: CGFloat = 12, tint: Color? = nil) -> LiquidGlassButtonStyle {
        LiquidGlassButtonStyle(isProminent: prominent, isDestructive: destructive, cornerRadius: cornerRadius, tint: tint)
    }
}
