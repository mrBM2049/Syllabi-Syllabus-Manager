import SwiftUI
import SwiftData

public enum CourseSortOption: String, CaseIterable, Identifiable {
    case nameAsc = "Name (A–Z)"
    case nameDesc = "Name (Z–A)"
    case completionDesc = "Completion (Highest)"
    case completionAsc = "Completion (Lowest)"
    case newest = "Date Created (Newest)"
    case oldest = "Date Created (Oldest)"

    public var id: String { rawValue }
}

public enum CourseFocusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case hidden = "Hidden"

    public var id: String { rawValue }
}

public struct CoursesView: View {
    @Environment(\.modelContext) private var modelContext
    public var subjects: [Subject]
    public var onSelectSubject: (Subject) -> Void
    public var onImportClicked: () -> Void
    public var onNewCourseClicked: () -> Void

    @State private var searchText = ""
    @State private var sortOption: CourseSortOption = .completionDesc
    @State private var focusFilter: CourseFocusFilter = .all
    @State private var bindingStyle: NotebookBindingStyle = .spiral
    @State private var selectedFilterCategory = "All"
    @AppStorage("syllabi.activeProjectID") private var activeProjectIDString = ""

    public init(
        subjects: [Subject],
        onSelectSubject: @escaping (Subject) -> Void,
        onImportClicked: @escaping () -> Void,
        onNewCourseClicked: @escaping () -> Void
    ) {
        self.subjects = subjects
        self.onSelectSubject = onSelectSubject
        self.onImportClicked = onImportClicked
        self.onNewCourseClicked = onNewCourseClicked
    }

    private var activeCount: Int {
        subjects.filter { !$0.isHidden }.count
    }

    private var hiddenCount: Int {
        subjects.filter { $0.isHidden }.count
    }

    private var categories: [String] {
        var set = Set<String>()
        for s in subjects {
            if !s.code.isEmpty { set.insert(s.code) }
            if !s.term.isEmpty { set.insert(s.term) }
        }
        return ["All"] + Array(set).sorted()
    }

    private var sortedAndFilteredSubjects: [Subject] {
        var list = subjects

        // Focus filter
        switch focusFilter {
        case .all:
            break
        case .active:
            list = list.filter { !$0.isHidden }
        case .hidden:
            list = list.filter { $0.isHidden }
        }

        // Search filter
        if !searchText.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.code.localizedCaseInsensitiveContains(searchText) ||
                $0.term.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Category filter
        if selectedFilterCategory != "All" {
            list = list.filter {
                $0.code == selectedFilterCategory || $0.term == selectedFilterCategory
            }
        }

        // Sorting
        switch sortOption {
        case .nameAsc:
            return list.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .nameDesc:
            return list.sorted { $0.title.localizedCompare($1.title) == .orderedDescending }
        case .completionDesc:
            return list.sorted { $0.progress > $1.progress }
        case .completionAsc:
            return list.sorted { $0.progress < $1.progress }
        case .newest:
            return list.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return list.sorted { $0.createdAt < $1.createdAt }
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Top Header (Title + Style Toggle)
                headerSection

                // Responsive Filter & Sort Toolbar
                toolbarSection

                Divider()
                    .padding(.vertical, 2)

                // Notebook Shelf Grid
                if sortedAndFilteredSubjects.isEmpty {
                    emptyShelfView
                } else {
                    notebookShelfGrid
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
                Text("Course Notebooks")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)

                CurvedAccentMark()
                    .frame(width: 100, height: 7)
            }

            Spacer()

            // Binding Style Toggle (Spiral vs Bound)
            HStack(spacing: 2) {
                Button(action: { bindingStyle = .spiral }) {
                    Image(systemName: "circle.grid.2x1.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(bindingStyle == .spiral ? Color.white : Color.secondary)
                        .frame(width: 28, height: 26)
                        .background(
                            Capsule()
                                .fill(bindingStyle == .spiral ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("Spiral ring notebooks")

                Button(action: { bindingStyle = .bound }) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(bindingStyle == .bound ? Color.white : Color.secondary)
                        .frame(width: 28, height: 26)
                        .background(
                            Capsule()
                                .fill(bindingStyle == .bound ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("Stitched bound notebooks")
            }
            .padding(3)
            .liquidGlass(cornerRadius: 16)
        }
    }

    // MARK: - Toolbar & Sorting (Responsive)

    private var toolbarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                // Wide Window
                HStack(spacing: 12) {
                    focusFilterChips
                    searchField
                    sortMenu
                    Spacer(minLength: 12)
                    if categories.count > 1 {
                        categoryChips
                    }
                }

                // Narrow Window
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        focusFilterChips
                        Spacer()
                        sortMenu
                    }
                    HStack(spacing: 10) {
                        searchField
                        if categories.count > 1 {
                            categoryChips
                        }
                    }
                }
            }
        }
    }

    private var focusFilterChips: some View {
        HStack(spacing: 4) {
            Button(action: { focusFilter = .all }) {
                Text("All (\(subjects.count))")
                    .font(.system(size: 11, weight: focusFilter == .all ? .semibold : .medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
            }
            .buttonStyle(.liquidGlass(prominent: focusFilter == .all, cornerRadius: 10))

            Button(action: { focusFilter = .active }) {
                Text("Active (\(activeCount))")
                    .font(.system(size: 11, weight: focusFilter == .active ? .semibold : .medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
            }
            .buttonStyle(.liquidGlass(prominent: focusFilter == .active, cornerRadius: 10))

            if hiddenCount > 0 {
                Button(action: { focusFilter = .hidden }) {
                    HStack(spacing: 3) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 9.5))
                        Text("Hidden (\(hiddenCount))")
                    }
                    .font(.system(size: 11, weight: focusFilter == .hidden ? .semibold : .medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                }
                .buttonStyle(.liquidGlass(prominent: focusFilter == .hidden, cornerRadius: 10))
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Search notebooks...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(minWidth: 120, maxWidth: 170)
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
        .padding(.vertical, 5)
        .liquidGlass(cornerRadius: 12)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var sortMenu: some View {
        Menu {
            ForEach(CourseSortOption.allCases) { option in
                Button(action: { sortOption = option }) {
                    HStack {
                        Text(option.rawValue)
                        if sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 10.5))
                Text(sortOption.rawValue)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .frame(width: 150, height: 30, alignment: .leading)
            .padding(.horizontal, 10)
            .background(SyllabiTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(SyllabiTheme.ink.opacity(0.14), lineWidth: 0.8))
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories, id: \.self) { cat in
                    Button(action: { selectedFilterCategory = cat }) {
                        Text(cat)
                            .font(.system(size: 11, weight: selectedFilterCategory == cat ? .semibold : .medium))
                            .foregroundStyle(selectedFilterCategory == cat ? Color.white : Color.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4.5)
                            .background(
                                Capsule()
                                    .fill(selectedFilterCategory == cat ? Color.accentColor : Color.primary.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Notebook Shelf Grid

    private var notebookShelfGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 24)],
            spacing: 28
        ) {
            ForEach(sortedAndFilteredSubjects) { subject in
                VStack(spacing: 10) {
                    ZStack(alignment: .topTrailing) {
                        NotebookCoverView(
                            subject: subject,
                            style: bindingStyle,
                            onClick: { onSelectSubject(subject) },
                            isActive: activeProjectIDString == subject.id.uuidString,
                            onMarkActive: { activeProjectIDString = subject.id.uuidString }
                        )
                        .opacity(subject.isHidden ? 0.75 : 1.0)

                        if subject.isHidden {
                            HStack(spacing: 3) {
                                Image(systemName: "eye.slash.fill")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Hidden")
                                    .font(.system(size: 9.5, weight: .bold))
                            }
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.orange.opacity(0.9)))
                            .padding(8)
                        }
                    }

                    // Below Cover: Clean Title & Code
                    VStack(spacing: 2) {
                        Text(subject.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if !subject.code.isEmpty || !subject.term.isEmpty {
                            Text([subject.code, subject.term].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: 190)
                }
                .contextMenu {
                    Button {
                        activeProjectIDString = subject.id.uuidString
                    } label: {
                        Label("Make Current Project", systemImage: "target")
                    }
                    Button("Copy Syllabus Markdown") { SyllabusShareHelper.copyMarkdown(subject) }

                    Divider()

                    Button(action: {
                        subject.isHidden.toggle()
                        try? modelContext.save()
                    }) {
                        Label(subject.isHidden ? "Unhide Notebook (Exit Focus Mode)" : "Hide Notebook (Focus Mode)", systemImage: subject.isHidden ? "eye" : "eye.slash")
                    }

                    Button(action: {
                        for s in subjects {
                            s.isHidden = (s.id != subject.id)
                        }
                        try? modelContext.save()
                    }) {
                        Label("Focus Only on This Subject", systemImage: "target")
                    }

                    if hiddenCount > 0 {
                        Button(action: {
                            for s in subjects { s.isHidden = false }
                            try? modelContext.save()
                        }) {
                            Label("Unhide All Notebooks", systemImage: "eye")
                        }
                    }

                    Divider()
                    Button("Open Notebook") { onSelectSubject(subject) }
                    Button("Export as .md...") { SyllabusShareHelper.saveSubjectToFile(subject) }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Empty Shelf

    private var emptyShelfView: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.secondary.opacity(0.4))

            Text(subjects.isEmpty ? "No notebooks in your library" : "No notebooks match your filters")
                .font(.system(size: 16, weight: .bold))

            if subjects.isEmpty {
                Button(action: onImportClicked) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import .md")
                    }
                }
                .buttonStyle(.liquidGlass(prominent: true))
            } else {
                Button("Reset filters") {
                    searchText = ""
                    focusFilter = .all
                    selectedFilterCategory = "All"
                }
                .buttonStyle(.liquidGlass)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .liquidGlass(cornerRadius: 18)
    }
}
