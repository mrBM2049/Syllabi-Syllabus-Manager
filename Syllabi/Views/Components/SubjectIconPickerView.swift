import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct SubjectIconPickerView: View {
    @Bindable public var subject: Subject

    private let availableIcons = [
        "book.closed.fill", "laptopcomputer", "atom", "ruler.fill",
        "brain.head.profile", "paintbrush.fill", "flask.fill", "chart.bar.fill",
        "cpu.fill", "terminal.fill", "building.columns.fill", "globe.americas.fill",
        "waveform.path.ecg", "gearshape.fill", "lightbulb.fill", "sparkles"
    ]

    public init(subject: Subject) {
        self.subject = subject
    }

    private var subjectColor: Color {
        Color(hex: subject.colorHex)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with upload button
            HStack(alignment: .center) {
                Text("Course Icon")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.secondary)

                Spacer()

                Button(action: uploadCustomIcon) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 11))
                        Text("Custom Icon")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.liquidGlass)
                .help("Choose any image; Vision removes its background and creates a transparent icon")
            }

            // Custom icon preview banner if active
            if let customImg = subject.customImage {
                HStack(spacing: 10) {
                    Image(nsImage: customImg)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom Icon Active")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Color.primary)
                        Text("Applied to notebook cover")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    Button("Remove") {
                        subject.customIconData = nil
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.red)
                    .buttonStyle(.plain)
                    .help("Remove custom icon and restore default symbol")
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Icon size")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("\(Int(subject.customIconScale * 100))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                }
                Slider(value: $subject.customIconScale, in: 0.75...1.2, step: 0.05)
                    .disabled(subject.customImage == nil)
                Text("Keeps a safe margin around the icon")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.secondary)
            }

            // SF Symbol Grid (4x4, well-spaced)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(availableIcons, id: \.self) { symbol in
                    Button(action: {
                        subject.customIconData = nil
                        subject.icon = symbol
                    }) {
                        Image(systemName: symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(subject.customIconData == nil && subject.icon == symbol ? Color.white : subjectColor)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(subject.customIconData == nil && subject.icon == symbol ? subjectColor : subjectColor.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(subject.customIconData == nil && subject.icon == symbol ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Icon: \(symbol)")
                }
            }

            Divider()

            Text("Theme Color")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.secondary)

            // Custom Color Picker (Preset circles + Rainbow Color Wheel + Hex code)
            NotebookColorPicker(selectedHex: $subject.colorHex)
        }
        .padding(16)
        .frame(width: 310)
    }

    private func uploadCustomIcon() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [
            UTType.ico,
            UTType.png,
            UTType.jpeg,
            UTType.icns,
            UTType.image
        ]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.message = "Choose any image for this course notebook"

        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                Task {
                    do {
                        subject.customIconData = try await IconProcessingService.transparentIconData(from: url)
                    } catch {
                        print("Error processing custom icon: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
