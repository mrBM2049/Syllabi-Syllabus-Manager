import SwiftUI
import SwiftData

public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    public var subjects: [Subject]
    public var onSelectSubject: (Subject) -> Void
    public var onOpenAllCourses: () -> Void
    public var onOpenLessons: () -> Void
    public var onImportClicked: () -> Void
    public var onDropFile: ((URL) -> Void)? = nil

    @State private var isTargetedForDrop = false
    @State private var showCopiedToast = false
    @AppStorage("syllabi.activeProjectID") private var activeProjectIDString = ""

    public init(
        subjects: [Subject],
        onSelectSubject: @escaping (Subject) -> Void,
        onOpenAllCourses: @escaping () -> Void,
        onOpenLessons: @escaping () -> Void,
        onImportClicked: @escaping () -> Void,
        onDropFile: ((URL) -> Void)? = nil
    ) {
        self.subjects = subjects
        self.onSelectSubject = onSelectSubject
        self.onOpenAllCourses = onOpenAllCourses
        self.onOpenLessons = onOpenLessons
        self.onImportClicked = onImportClicked
        self.onDropFile = onDropFile
    }

    private var activeSubjects: [Subject] {
        let active = subjects.filter { !$0.isHidden }
        return active.isEmpty ? subjects : active
    }

    private var hiddenCount: Int {
        subjects.filter { $0.isHidden }.count
    }

    private var totalTopics: Int {
        activeSubjects.reduce(0) { $0 + $1.totalTopicsCount }
    }

    private var completedTopics: Int {
        activeSubjects.reduce(0) { $0 + $1.completedTopicsCount }
    }

    private var overallProgress: Double {
        guard totalTopics > 0 else { return 0.0 }
        return Double(completedTopics) / Double(totalTopics)
    }

    private var focusSubject: Subject? {
        activeSubjects.first(where: { $0.progress < 1.0 }) ?? activeSubjects.first
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header (Clean Title with Underline — no redundant top buttons)
                topHeaderSection

                if subjects.isEmpty {
                    emptyStateDropZone
                } else {
                    // Fully Responsive Adaptive Layout
                    responsiveContentLayout
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            if showCopiedToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("AI Formatter Prompt copied to clipboard")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThickMaterial, in: Capsule())
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Header (No duplicate buttons)

    private var topHeaderSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Curriculum Overview")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.primary)

            CurvedAccentMark()
                .frame(width: 90, height: 7)
        }
    }

    // MARK: - Responsive Content Layout

    @ViewBuilder
    private var responsiveContentLayout: some View {
        ViewThatFits(in: .horizontal) {
            // Wide Window: 2-column layout (Notebooks on left, Learning process rail on right)
            HStack(alignment: .top, spacing: 28) {
                activeNotebooksColumn
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 22) {
                    learningProcessPanel
                    if let focus = focusSubject {
                        featuredFocusCard(for: focus)
                    }
                }
                .frame(width: 290)
            }

            // Narrow Window: Fluid vertical stacking
            VStack(alignment: .leading, spacing: 24) {
                activeNotebooksColumn

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        learningProcessPanel
                            .frame(maxWidth: .infinity)
                        if let focus = focusSubject {
                            featuredFocusCard(for: focus)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        learningProcessPanel
                        if let focus = focusSubject {
                            featuredFocusCard(for: focus)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Active Notebooks Column

    private var activeNotebooksColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Shelf Header
            HStack {
                Text("Active Notebooks")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onOpenAllCourses) {
                    HStack(spacing: 4) {
                        Text("View all notebooks")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            // Focus Mode Banner (if courses are hidden)
            if hiddenCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.orange)
                    Text("Focus Mode: Showing \(activeSubjects.count) active (\(hiddenCount) hidden)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Unhide All") {
                        withAnimation {
                            for s in subjects { s.isHidden = false }
                            try? modelContext.save()
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.orange)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 0.8)
                )
            }

            // Notebook Covers Shelf
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(activeSubjects) { subject in
                        NotebookCoverView(
                            subject: subject,
                            style: .spiral,
                            onClick: { onSelectSubject(subject) },
                            isActive: activeProjectIDString == subject.id.uuidString,
                            onMarkActive: { activeProjectIDString = subject.id.uuidString }
                        )
                        .contextMenu {
                            Button {
                                activeProjectIDString = subject.id.uuidString
                            } label: {
                                Label("Make Current Project", systemImage: "target")
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.leading, 2)
            }

            // Lessons Quick Access Card
            lessonsShortcutBanner
        }
    }

    // MARK: - Lessons Banner

    private var lessonsShortcutBanner: some View {
        Button(action: onOpenLessons) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: "checklist")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Study Checklist & Lessons")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("\(completedTopics) of \(totalTopics) topics completed across all notebooks")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Open Lessons")
                        .font(.system(size: 11.5, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color.accentColor)
            }
            .padding(14)
            .liquidGlass(cornerRadius: 14, isInteractive: true)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Learning Process Panel

    private var learningProcessPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Learning process")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onOpenAllCourses) {
                    Text("See all")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 14) {
                ForEach(activeSubjects.prefix(4)) { subject in
                    ModernProgressBar(
                        title: subject.title,
                        progress: subject.progress,
                        height: 12,
                        accentColor: Color(hex: subject.colorHex)
                    )
                }
            }
            .padding(14)
            .liquidGlass(cornerRadius: 14)
        }
    }

    // MARK: - Focus Card

    private func featuredFocusCard(for subject: Subject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(subject.code.isEmpty ? "Active" : subject.code)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color(red: 0.18, green: 0.28, blue: 0.95))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(Color.white))

                Spacer()

                SubjectIconView(subject: subject, size: 18, foregroundColor: .white.opacity(0.95))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(subject.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("\(subject.completedTopicsCount) of \(subject.totalTopicsCount) topics completed · \(subject.units.count) units")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer(minLength: 4)

            Button(action: { onSelectSubject(subject) }) {
                Text("Continue study")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Color(red: 0.18, green: 0.28, blue: 0.95))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8.5)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(height: 220)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.32, blue: 0.99),
                            Color(red: 0.15, green: 0.22, blue: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color(red: 0.22, green: 0.32, blue: 0.99).opacity(0.22), radius: 10, x: 0, y: 5)
    }

    // MARK: - Empty State

    private var emptyStateDropZone: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 4) {
                Text("No notebooks in your library")
                    .font(.system(size: 17, weight: .bold))
                Text("Drop any syllabus .md file here to import.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.secondary)
            }

            HStack(spacing: 12) {
                Button(action: onImportClicked) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import .md")
                    }
                }
                .buttonStyle(.liquidGlass(prominent: true))

                Button(action: copyAIPrompt) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        Text("Copy AI prompt")
                    }
                }
                .buttonStyle(.liquidGlass)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .liquidGlass(cornerRadius: 18)
    }

    // MARK: - Actions

    private func copyAIPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(PromptTemplate.aiFormatterPrompt, forType: .string)
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { showCopiedToast = false }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url = url {
                DispatchQueue.main.async {
                    onDropFile?(url)
                }
            }
        }
        return true
    }
}
