import SwiftUI
import SwiftData

public struct LessonsView: View {
    public var subjects: [Subject]
    public var onSelectSubject: (Subject) -> Void

    @State private var searchText = ""
    @State private var statusFilter: StatusFilter = .all
    @State private var selectedCourseID: UUID? = nil
    @State private var selectedTag: String? = nil

    public enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "All Topics"
        case remaining = "To Study"
        case completed = "Completed"

        public var id: String { rawValue }
    }

    public init(subjects: [Subject], onSelectSubject: @escaping (Subject) -> Void) {
        self.subjects = subjects
        self.onSelectSubject = onSelectSubject
    }

    public struct TopicEntry: Identifiable {
        public var id: UUID { topic.id }
        public let subject: Subject
        public let unit: SyllabusUnit
        public let topic: TopicItem
    }

    private var allTopics: [TopicEntry] {
        var list: [TopicEntry] = []
        for s in subjects {
            for u in s.sortedUnits {
                for t in u.topLevelTopics {
                    list.append(TopicEntry(subject: s, unit: u, topic: t))
                    for sub in t.sortedSubtopics {
                        list.append(TopicEntry(subject: s, unit: u, topic: sub))
                    }
                }
            }
        }
        return list
    }

    private var allTags: [String] {
        var set = Set<String>()
        for entry in allTopics {
            for tag in entry.topic.tags {
                set.insert(tag)
            }
        }
        return Array(set).sorted()
    }

    private var filteredTopics: [TopicEntry] {
        allTopics.filter { entry in
            // Course filter
            if let courseID = selectedCourseID, entry.subject.id != courseID {
                return false
            }

            // Status filter
            switch statusFilter {
            case .all:
                break
            case .remaining:
                if entry.topic.isCompleted { return false }
            case .completed:
                if !entry.topic.isCompleted { return false }
            }

            // Tag filter
            if let tag = selectedTag, !entry.topic.tags.contains(tag) {
                return false
            }

            // Search
            if !searchText.isEmpty {
                let matchesTitle = entry.topic.title.localizedCaseInsensitiveContains(searchText)
                let matchesNotes = entry.topic.notes.localizedCaseInsensitiveContains(searchText)
                let matchesCourse = entry.subject.title.localizedCaseInsensitiveContains(searchText) || entry.subject.code.localizedCaseInsensitiveContains(searchText)
                let matchesUnit = entry.unit.title.localizedCaseInsensitiveContains(searchText)
                if !matchesTitle && !matchesNotes && !matchesCourse && !matchesUnit {
                    return false
                }
            }

            return true
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header (Title + Overall Topic Stats)
                headerSection

                // Responsive Filter Controls (No Vertical Squishing)
                filterToolbarSection

                Divider()
                    .padding(.vertical, 2)

                // Lessons Table / List
                if filteredTopics.isEmpty {
                    emptyTopicsView
                } else {
                    lessonsList
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("My Lessons")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)

                CurvedAccentMark()
                    .frame(width: 80, height: 7)
            }

            Spacer()

            // Stats Badges
            let completed = allTopics.filter { $0.topic.isCompleted }.count
            let total = allTopics.count

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Text("\(completed) of \(total) completed")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .liquidGlass(cornerRadius: 14)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - Filter Toolbar (Responsive, Never Breaks Vertically)

    private var filterToolbarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                // Wide layout: single line
                HStack(spacing: 12) {
                    statusPillsHStack
                    courseMenu
                    Spacer(minLength: 12)
                    searchField
                }

                // Narrow layout: wrap gracefully into two rows
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        statusPillsHStack
                        courseMenu
                    }
                    searchField
                }
            }

            // Tags Row
            if !allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("Tags:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)

                        ForEach(allTags, id: \.self) { tag in
                            TagBadgeView(
                                tag: tag,
                                isSelected: selectedTag == tag,
                                onSelect: {
                                    if selectedTag == tag {
                                        selectedTag = nil
                                    } else {
                                        selectedTag = tag
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var statusPillsHStack: some View {
        HStack(spacing: 8) {
            ForEach(StatusFilter.allCases) { filter in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        statusFilter = filter
                    }
                }) {
                    Text(filter.rawValue)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.liquidGlass(prominent: statusFilter == filter, cornerRadius: 12))
                .help("Filter topics: \(filter.rawValue)")
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var courseMenu: some View {
        Menu {
            Button("All Courses") {
                selectedCourseID = nil
            }
            Divider()
            ForEach(subjects) { sub in
                Button(action: { selectedCourseID = sub.id }) {
                    HStack {
                        Text(sub.title)
                        if selectedCourseID == sub.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 10))
                Text(selectedCourseTitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .frame(width: 158, height: 30, alignment: .leading)
            .padding(.horizontal, 10)
            .background(SyllabiTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(SyllabiTheme.ink.opacity(0.14), lineWidth: 0.8))
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Search topics...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(minWidth: 120, maxWidth: 200)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5.5)
        .liquidGlass(cornerRadius: 12)
    }

    private var selectedCourseTitle: String {
        if let id = selectedCourseID, let sub = subjects.first(where: { $0.id == id }) {
            return sub.code.isEmpty ? sub.title : sub.code
        }
        return "All Courses"
    }

    // MARK: - Lessons List (Full-Width Responsive Layout)

    private var lessonsList: some View {
        VStack(spacing: 8) {
            ForEach(filteredTopics) { entry in
                LessonFullRow(
                    entry: entry,
                    onOpenCourse: { onSelectSubject(entry.subject) }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyTopicsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundStyle(Color.secondary.opacity(0.4))

            Text("No lessons match the selected filters")
                .font(.system(size: 15, weight: .bold))

            Button("Clear Filters") {
                statusFilter = .all
                selectedCourseID = nil
                selectedTag = nil
                searchText = ""
            }
            .buttonStyle(.liquidGlass)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .liquidGlass(cornerRadius: 16)
    }
}

// MARK: - Lesson Full Row Component

struct LessonFullRow: View {
    let entry: LessonsView.TopicEntry
    let onOpenCourse: () -> Void

    @Bindable var topic: TopicItem
    @State private var isHovering = false
    @State private var isNotesExpanded = false

    init(entry: LessonsView.TopicEntry, onOpenCourse: @escaping () -> Void) {
        self.entry = entry
        self.onOpenCourse = onOpenCourse
        self._topic = Bindable(entry.topic)
    }

    private var courseColor: Color {
        Color(hex: entry.subject.colorHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                // Checkbox (Expanded Hitbox & Save)
                Button(action: {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                        topic.toggleCompletion()
                        try? topic.modelContext?.save()
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                topic.isCompleted ? courseColor : (isHovering ? Color.secondary.opacity(0.6) : Color.secondary.opacity(0.35)),
                                lineWidth: 1.5
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(topic.isCompleted ? courseColor : Color.clear)
                            )
                            .frame(width: 19, height: 19)

                        if topic.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(topic.isCompleted ? "Mark topic uncompleted" : "Mark topic completed")

                // Topic Title
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .font(.system(size: 13, weight: topic.isCompleted ? .regular : .semibold))
                        .foregroundStyle(topic.isCompleted ? Color.secondary.opacity(0.65) : Color.primary)
                        .strikethrough(topic.isCompleted, color: Color.secondary.opacity(0.4))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !topic.notes.isEmpty && !isNotesExpanded {
                        Text(topic.notes)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 12)

                // Course Code Badge
                Button(action: onOpenCourse) {
                    HStack(spacing: 4) {
                        SubjectIconView(subject: entry.subject, size: 12, foregroundColor: courseColor)
                        Text(entry.subject.code.isEmpty ? entry.subject.title : entry.subject.code)
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(courseColor.opacity(0.12)))
                    .foregroundStyle(courseColor)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .help("Open \(entry.subject.title)")

                // Unit Name
                Text(entry.unit.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 150, alignment: .trailing)

                // Tags
                if !topic.tags.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(topic.tags, id: \.self) { tag in
                            TagBadgeView(tag: tag)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                // Study Note Toggle
                if !topic.notes.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isNotesExpanded.toggle()
                        }
                    }) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 11))
                            .foregroundStyle(courseColor)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle study notes")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.035) : Color(nsColor: .controlBackgroundColor).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isHovering ? courseColor.opacity(0.25) : Color.secondary.opacity(0.08), lineWidth: 0.6)
            )
            .onHover { isHovering = $0 }

            // Expanded Study Note Drawer
            if isNotesExpanded && !topic.notes.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(courseColor)
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("STUDY NOTE")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.secondary)
                            .tracking(0.5)

                        Text(topic.notes)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.primary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .padding(.leading, 31)
                .padding(.bottom, 2)
            }
        }
    }
}
