import SwiftUI
import SwiftData
import UniformTypeIdentifiers

public enum SidebarSelection: Hashable {
    case dashboard
    case courses
    case lessons
    case calendar
    case subject(UUID)
}

public struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding public var selection: SidebarSelection
    public var subjects: [Subject]
    public var onImportClicked: () -> Void
    public var onNewCourseClicked: () -> Void
    public var onDropFile: ((URL) -> Void)? = nil
    public var onExportSubject: ((Subject) -> Void)? = nil

    @State private var subjectToEdit: Subject? = nil
    @State private var subjectToDelete: Subject? = nil
    @State private var isShowingDeleteAlert = false
    @State private var isTargetedForDrop = false
    @State private var showHiddenCourses = false
    @AppStorage("syllabi.activeProjectID") private var activeProjectIDString = ""

    public init(
        selection: Binding<SidebarSelection>,
        subjects: [Subject],
        onImportClicked: @escaping () -> Void,
        onNewCourseClicked: @escaping () -> Void,
        onDropFile: ((URL) -> Void)? = nil,
        onExportSubject: ((Subject) -> Void)? = nil
    ) {
        self._selection = selection
        self.subjects = subjects
        self.onImportClicked = onImportClicked
        self.onNewCourseClicked = onNewCourseClicked
        self.onDropFile = onDropFile
        self.onExportSubject = onExportSubject
    }

    private var displayedSubjects: [Subject] {
        if showHiddenCourses {
            return subjects
        }
        return subjects.filter { !$0.isHidden }
    }

    private var hiddenCount: Int {
        subjects.filter { $0.isHidden }.count
    }

    public var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                // Primary navigation stays available in the sidebar as a familiar macOS menu.
                Section {
                    sidebarNavigationLink(.dashboard, title: "Overview", icon: "square.grid.2x2.fill")
                    sidebarNavigationLink(.courses, title: "Courses", icon: "books.vertical.fill", count: subjects.count)
                    sidebarNavigationLink(.lessons, title: "My Lessons", icon: "checklist", count: subjects.filter { !$0.isHidden }.reduce(0) { $0 + ($1.totalTopicsCount - $1.completedTopicsCount) })
                    sidebarNavigationLink(.calendar, title: "Calendar", icon: "calendar")
                }

                Section(header: Text("CURRENT PROJECT")) {
                    Menu {
                        Button {
                            setActiveProject(nil)
                        } label: {
                            Label("No active project", systemImage: activeProject == nil ? "checkmark" : "circle")
                        }
                        Divider()
                        ForEach(subjects) { subject in
                            Button {
                                setActiveProject(subject)
                            } label: {
                                HStack {
                                    Text(subject.title)
                                    if activeProject?.id == subject.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "target")
                                .foregroundStyle(Color.accentColor)
                            Text(activeProject?.title ?? "Choose a project")
                                .font(.system(size: 12.5, weight: .medium))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                        .padding(.horizontal, 10)
                        .background(SyllabiTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(SyllabiTheme.ink.opacity(0.14), lineWidth: 0.8))
                    }
                    .menuStyle(.borderlessButton)
                }

                // Course notebooks with focus/hide support.
                Section(header: notebooksHeader) {
                    if subjects.isEmpty {
                        Text("No courses enrolled")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.secondary.opacity(0.7))
                            .padding(.vertical, 4)
                    } else if displayedSubjects.isEmpty {
                        VStack(spacing: 6) {
                            Text("All courses hidden in Focus Mode")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                            Button("Show hidden courses") {
                                showHiddenCourses = true
                            }
                            .font(.system(size: 11, weight: .medium))
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                        }
                        .padding(.vertical, 6)
                    } else {
                        ForEach(displayedSubjects) { subject in
                            NavigationLink(value: SidebarSelection.subject(subject.id)) {
                                subjectRow(for: subject)
                            }
                            .tag(SidebarSelection.subject(subject.id))
                            .contextMenu {
                                Button(action: {
                                    subject.isHidden.toggle()
                                    try? modelContext.save()
                                }) {
                                    Label(subject.isHidden ? "Unhide Course" : "Hide Course (Focus Mode)", systemImage: subject.isHidden ? "eye" : "eye.slash")
                                }

                                Button(action: {
                                    // Focus strictly on this subject by hiding others
                                    for s in subjects {
                                        s.isHidden = (s.id != subject.id)
                                    }
                                    showHiddenCourses = false
                                    try? modelContext.save()
                                }) {
                                    Label("Focus Only on This Subject", systemImage: "target")
                                }

                                if hiddenCount > 0 {
                                    Button(action: {
                                        for s in subjects { s.isHidden = false }
                                        try? modelContext.save()
                                    }) {
                                        Label("Unhide All Courses", systemImage: "eye")
                                    }
                                }

                                Divider()
                                Button("Edit Course Info...") { subjectToEdit = subject }
                                Button("Update Syllabus...") {
                                    SyllabusShareHelper.pickUpdatedSyllabus(for: subject) { _ in
                                        try? modelContext.save()
                                    }
                                }
                                Button("Share...") {
                                    SyllabusShareHelper.shareSubject(subject)
                                }
                                Button("Export as .md...") { onExportSubject?(subject) }
                                Divider()
                                Button(role: .destructive) {
                                    subjectToDelete = subject
                                    isShowingDeleteAlert = true
                                } label: {
                                    Label("Delete Course", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 220, idealWidth: 250, maxWidth: 320)
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
            handleDrop(providers: providers)
        }
        .onChange(of: selection) { _, _ in
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .sheet(item: $subjectToEdit) { subject in
            EditSubjectSheet(subject: subject)
        }
        .confirmationDialog(
            "Delete \"\(subjectToDelete?.title ?? "Course")\"?",
            isPresented: $isShowingDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let sub = subjectToDelete {
                    deleteSubject(sub)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this course and all its units and topics.")
        }
    }

    @ViewBuilder
    private func sidebarNavigationLink(_ destination: SidebarSelection, title: String, icon: String, count: Int? = nil) -> some View {
        let isSelected = selection == destination
        let inactiveIcon = icon.replacingOccurrences(of: ".fill", with: "")
        NavigationLink(value: destination) {
            Label {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    if let count, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundStyle(destination == .lessons ? Color.white : Color.secondary)
                            .padding(.horizontal, destination == .lessons ? 6 : 0)
                            .padding(.vertical, destination == .lessons ? 1.5 : 0)
                            .background {
                                if destination == .lessons {
                                    Capsule().fill(Color.accentColor)
                                }
                            }
                    }
                }
                .padding(.vertical, 8)
            } icon: {
                Image(systemName: isSelected ? icon : inactiveIcon)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
            }
        }
        .tag(destination)
    }

    // MARK: - Section Header (Focus / Hide Toggle)

    private var notebooksHeader: some View {
        HStack {
            Text("NOTEBOOKS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.secondary)
                .tracking(0.6)

            Spacer()

            if hiddenCount > 0 {
                Button(action: { showHiddenCourses.toggle() }) {
                    HStack(spacing: 3) {
                        Image(systemName: showHiddenCourses ? "eye" : "eye.slash")
                            .font(.system(size: 8.5))
                        Text(showHiddenCourses ? "Hide" : "\(hiddenCount) hidden")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
                    .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .help(showHiddenCourses ? "Hide inactive courses from sidebar" : "Show \(hiddenCount) hidden courses")
            }
        }
    }

    // MARK: - Row View (Custom Icon & Hidden State Support)

    private func subjectRow(for subject: Subject) -> some View {
        let subjectColor = Color(hex: subject.colorHex)
        return HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(subjectColor.opacity(0.14))
                    .frame(width: 22, height: 22)

                SubjectIconView(subject: subject, size: 14, foregroundColor: subjectColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(subject.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)

                if !subject.code.isEmpty || !subject.term.isEmpty {
                    Text([subject.code, subject.term].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if activeProject?.id == subject.id {
                Image(systemName: "target")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .help("Current project")
            }

            if subject.isHidden {
                Image(systemName: "eye.slash")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.secondary.opacity(0.8))
            } else {
                ProgressRingView(
                    progress: subject.progress,
                    lineWidth: 2.2,
                    color: subjectColor,
                    showPercentage: false
                )
                .frame(width: 14, height: 14)
            }
        }
        .padding(.vertical, 8)
        .opacity(subject.isHidden ? 0.65 : 1.0)
    }

    private var activeProject: Subject? {
        guard let id = UUID(uuidString: activeProjectIDString) else { return nil }
        return subjects.first(where: { $0.id == id })
    }

    private func setActiveProject(_ subject: Subject?) {
        activeProjectIDString = subject?.id.uuidString ?? ""
        if let subject {
            selection = .subject(subject.id)
        }
    }

    private func deleteSubject(_ subject: Subject) {
        if selection == .subject(subject.id) {
            selection = .dashboard
        }
        modelContext.delete(subject)
        try? modelContext.save()
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
