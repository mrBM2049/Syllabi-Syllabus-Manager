import SwiftUI

public struct TagBadgeView: View {
    public let tag: String
    public var isSelected: Bool = false
    public var onSelect: (() -> Void)? = nil

    public init(tag: String, isSelected: Bool = false, onSelect: (() -> Void)? = nil) {
        self.tag = tag
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    private var badgeColor: (bg: Color, text: Color) {
        let lower = tag.lowercased()
        if lower.contains("exam") || lower.contains("urgent") || lower.contains("high") {
            return (Color(red: 0.92, green: 0.28, blue: 0.28), .white)
        } else if lower.contains("design") || lower.contains("art") || lower.contains("ui") {
            return (Color(red: 0.21, green: 0.44, blue: 0.98), .white)
        } else if lower.contains("brand") || lower.contains("core") || lower.contains("key") {
            return (Color(red: 0.18, green: 0.26, blue: 0.94), .white)
        } else if lower.contains("illustration") || lower.contains("theory") || lower.contains("math") {
            return (Color(red: 0.35, green: 0.30, blue: 0.95), .white)
        } else if lower.contains("lab") || lower.contains("code") || lower.contains("practical") {
            return (Color(red: 0.05, green: 0.65, blue: 0.55), .white)
        } else if lower.contains("review") || lower.contains("basic") {
            return (Color(red: 0.95, green: 0.55, blue: 0.15), .white)
        } else {
            return (Color.primary.opacity(0.08), Color.primary)
        }
    }

    public var body: some View {
        Group {
            if let onSelect = onSelect {
                Button(action: onSelect) {
                    badgeContent
                }
                .buttonStyle(.plain)
            } else {
                badgeContent
            }
        }
    }

    private var badgeContent: some View {
        let colors = badgeColor
        return Text(tag)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(isSelected ? .white : colors.text)
            .padding(.horizontal, 9)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill(isSelected ? Color(red: 0.15, green: 0.18, blue: 0.95) : colors.bg)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 1.5)
            )
    }
}
