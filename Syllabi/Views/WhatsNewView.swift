import SwiftUI

public struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    public let version: String
    public let releaseName: String
    public let releaseNotes: String

    public init(version: String = "", releaseName: String = "A calmer way to study", releaseNotes: String = "") {
        self.version = version.isEmpty ? ((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0") : version
        self.releaseName = releaseName
        self.releaseNotes = releaseNotes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("What’s New", systemImage: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Syllabi \(version)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(releaseName)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(SyllabiTheme.secondaryText)
                    }

                    if releaseNotes.isEmpty {
                        feature(title: "A cleaner workspace", icon: "rectangle.3.group", color: SyllabiTheme.lavender) {
                            Text("A consistent top navigation bar keeps Overview, Courses, Lessons, Calendar, and your active notebook within reach.")
                        }
                        feature(title: "More readable colors", icon: "paintpalette", color: SyllabiTheme.mint) {
                            Text("Accessible semantic colors now adapt across light and dark mode without changing the meaning of progress states.")
                        }
                        feature(title: "One-click updates", icon: "arrow.down.circle", color: SyllabiTheme.peach) {
                            Text("When a GitHub release is available, Syllabi can download the latest DMG and open it for installation.")
                        }
                    } else {
                        Text(releaseNotes)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
                .padding(28)
                .frame(maxWidth: 720, alignment: .leading)
            }
        }
        .frame(minWidth: 520, minHeight: 420)
        .background(SyllabiTheme.canvas)
    }

    @ViewBuilder
    private func feature<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SyllabiTheme.ink)
                .frame(width: 42, height: 42)
                .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                content().foregroundStyle(SyllabiTheme.secondaryText)
            }
        }
    }
}
