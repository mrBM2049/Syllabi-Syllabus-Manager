import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct EditSubjectSheet: View {
    @Bindable public var subject: Subject
    @Environment(\.dismiss) private var dismiss

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
        VStack(spacing: 18) {
            Text("Edit Course Notebook")
                .font(.system(size: 16, weight: .bold))

            VStack(alignment: .leading, spacing: 14) {
                // Course Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Course Title")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                    TextField("Course title (e.g. Distributed Systems)", text: $subject.title)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                // Code & Term Side by Side
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Course Code")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                        TextField("e.g. CS301", text: $subject.code)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5, design: .monospaced))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Term / Semester")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                        TextField("e.g. Fall 2024", text: $subject.term)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5))
                    }
                }

                Divider()
                    .padding(.vertical, 2)

                // Cover Icon & Upload Button
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Cover Icon")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondary)

                        Spacer()

                        Button(action: uploadCustomIcon) {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 11))
                                Text("Custom Icon")
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                        }
                        .buttonStyle(.liquidGlass)
                        .fixedSize(horizontal: true, vertical: false)
                        .help("Choose any image; Vision removes its background and creates a transparent icon")
                    }

                    if let customImg = subject.customImage {
                        HStack(spacing: 10) {
                            Image(nsImage: customImg)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Using custom icon")
                                    .font(.system(size: 11.5, weight: .semibold))
                                Text("Applied to notebook cover and sidebar")
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
                            .help("Remove custom icon")
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                        ForEach(availableIcons, id: \.self) { iconName in
                            Button(action: {
                                subject.customIconData = nil
                                subject.icon = iconName
                            }) {
                                Image(systemName: iconName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(subject.customIconData == nil && subject.icon == iconName ? Color.white : Color.primary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(subject.customIconData == nil && subject.icon == iconName ? subjectColor : Color.primary.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(subject.customIconData == nil && subject.icon == iconName ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Icon: \(iconName)")
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 2)

                // Color Swatches + Color Wheel + Custom Hex Input
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cover Color & Hex")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)

                    NotebookColorPicker(selectedHex: $subject.colorHex)
                }
            }
            .padding(.horizontal, 6)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.liquidGlass(prominent: true))
                    .controlSize(.regular)
            }
        }
        .padding(22)
        .frame(width: 480)
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
