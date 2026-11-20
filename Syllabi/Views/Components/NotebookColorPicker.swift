import SwiftUI
import AppKit

// MARK: - Native Color Panel Delegate for Apple Color Wheel

final class ColorPanelDelegate: NSObject {
    static let shared = ColorPanelDelegate()
    var onColorChanged: ((Color) -> Void)?

    @objc func colorDidChange(_ sender: NSColorPanel) {
        let color = Color(nsColor: sender.color)
        onColorChanged?(color)
    }
}

public struct NotebookColorPicker: View {
    @Binding public var selectedHex: String

    private let defaultColors = [
        "#3652FD", "#0284C7", "#10B981", "#8B5CF6", "#F59E0B", "#EF4444", "#EC4899", "#14B8A6"
    ]

    @State private var hexInput: String = ""
    @State private var isCustomHexValid: Bool = true

    public init(selectedHex: Binding<String>) {
        self._selectedHex = selectedHex
        self._hexInput = State(initialValue: selectedHex.wrappedValue)
    }

    private var currentColor: Color {
        Color(hex: selectedHex)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Preset Color Circles + Rainbow Color Wheel
            HStack(spacing: 6) {
                ForEach(defaultColors, id: \.self) { hex in
                    Button(action: {
                        selectedHex = hex
                        hexInput = hex.replacingOccurrences(of: "#", with: "")
                    }) {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedHex.uppercased() == hex.uppercased() ? 2.2 : 0)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                    .help("Preset color: \(hex)")
                }

                // Authentic Rainbow Color Wheel
                Button(action: openSystemColorWheel) {
                    ZStack {
                        Circle()
                            .fill(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red
                                    ]),
                                    center: .center
                                )
                            )
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 5, height: 5)
                    }
                }
                .buttonStyle(.plain)
                .help("Color Wheel: Open macOS Color Panel to pick any custom color")
            }

            // Hex Code Input Field + Current Color Preview Dot
            HStack(spacing: 8) {
                Text("Hex:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.secondary)

                HStack(spacing: 2) {
                    Text("#")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.secondary)

                    TextField("3652FD", text: $hexInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(width: 65)
                        .onChange(of: hexInput) { _, newValue in
                            applyHex(newValue)
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isCustomHexValid ? Color.secondary.opacity(0.25) : Color.red.opacity(0.6), lineWidth: 0.8)
                )

                Circle()
                    .fill(currentColor)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)

                Spacer()
            }
        }
        .onAppear {
            hexInput = selectedHex.replacingOccurrences(of: "#", with: "")
        }
    }

    private func openSystemColorWheel() {
        let panel = NSColorPanel.shared
        panel.color = NSColor(Color(hex: selectedHex))
        panel.isContinuous = true
        panel.setTarget(ColorPanelDelegate.shared)
        panel.setAction(#selector(ColorPanelDelegate.colorDidChange(_:)))
        ColorPanelDelegate.shared.onColorChanged = { newColor in
            if let hex = newColor.toHex() {
                selectedHex = hex
                hexInput = hex.replacingOccurrences(of: "#", with: "")
            }
        }
        panel.orderFront(nil)
    }

    private func applyHex(_ input: String) {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if clean.count == 6, clean.range(of: "^[0-9a-fA-F]{6}$", options: .regularExpression) != nil {
            isCustomHexValid = true
            selectedHex = "#\(clean.uppercased())"
        } else if clean.count == 3, clean.range(of: "^[0-9a-fA-F]{3}$", options: .regularExpression) != nil {
            isCustomHexValid = true
            let r = String(repeating: clean[clean.startIndex], count: 2)
            let g = String(repeating: clean[clean.index(clean.startIndex, offsetBy: 1)], count: 2)
            let b = String(repeating: clean[clean.index(clean.startIndex, offsetBy: 2)], count: 2)
            selectedHex = "#\(r)\(g)\(b)".uppercased()
        } else {
            isCustomHexValid = false
        }
    }
}

// MARK: - Color to Hex Helper

public extension Color {
    func toHex() -> String? {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return nil }
        let r = Int(round(rgbColor.redComponent * 255))
        let g = Int(round(rgbColor.greenComponent * 255))
        let b = Int(round(rgbColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
