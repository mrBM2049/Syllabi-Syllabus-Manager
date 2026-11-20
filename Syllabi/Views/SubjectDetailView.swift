import SwiftUI
import SwiftData

public struct SubjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable public var subject: Subject
    public var onExportMarkdown: (() -> Void)? = nil
    public var onDeleteSubject: (() -> Void)? = nil

    @State private var searchText = ""
    @State private var statusFilter: UnitSectionView.StatusFilter = .all
    @State private var selectedTag: String? = nil
    @State private var isShowingIconPicker = false
    @State private var isAddingUnit = false
    @State private var newUnitTitle = ""
    @State private var isShowingDeleteConfirmation = false
    @State private var updateToastMessage: String? = nil

    @FocusState private var isSearchFocused: Bool
    @FocusState private var isNewUnitFocused: Bool

    public init(
        subject: Subject,
        onExportMarkdown: (() -> Void)? = nil,
        onDeleteSubject: (() -> Void)? = nil
    ) {
        self.subject = subject
        self.onExportMarkdown = onExportMarkdown
        self.onDeleteSubject = onDeleteSubject
    }

    private var allTags: [String] {
        var tagsSet = Set<String>()
        for unit in subject.units {
            for topic in unit.allTopics {
                for tag in topic.tags {
                    tagsSet.insert(tag)
                }
            }
        }
        return Array(tagsSet).sorted()
    }

    private var subjectColor: Color {
        Color(hex: subject.colorHex)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header (Icon Button, Title, Metadata)
                headerSection

                // Focus Mode Notice Banner
                if subject.isHidden {
                    focusModeBanner
                }

                // Modern Progress Bar (Hatched track)
                ModernProgressBar(
                    title: "Curriculum completion (\(subject.completedTopicsCount) of \(subject.totalTopicsCount) topics)",
                    progress: subject.progress,
                    height: 14,
                    accentColor: subjectColor
                )

                // In-Page Workspace Action & Filter Bar (100% visible at all window sizes)
                workspaceActionBar

                Divider()
                    .padding(.vertical, 2)

                // Units Section
                unitsSection

                // Add Unit Section
                addUnitSection
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            if let msg = updateToastMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text(msg)
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
        .confirmationDialog(
            "Delete \"\(subject.title)\"?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Course", role: .destructive) {
                deleteCourse()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this course notebook, including all its units and topics.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 18) {
            // Vector or Custom .ico Icon in Modern Frame
            Button(action: { isShowingIconPicker.toggle() }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(subjectColor.opacity(0.12))
                        .frame(width: 60, height: 60)

                    SubjectIconView(subject: subject, size: 28, foregroundColor: subjectColor)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(subjectColor.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isShowingIconPicker, arrowEdge: .bottom) {
                SubjectIconPickerView(subject: subject)
            }
            .help("Choose course icon & color")

            VStack(alignment: .leading, spacing: 8) {
                // Title
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Course title", text: $subject.title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.primary)

                    CurvedAccentMark()
                        .frame(width: 80, height: 6)
                }

                HStack(spacing: 8) {
                    // Code Pill
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.system(size: 9))
                        TextField("Code", text: $subject.code)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .frame(minWidth: 40, maxWidth: 90)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(subjectColor.opacity(0.1)))
                    .foregroundStyle(subjectColor)

                    // Term Pill
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        TextField("Term", text: $subject.term)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .frame(minWidth: 60, maxWidth: 120)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
                    .foregroundStyle(Color.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Focus Mode Notice Banner

    private var focusModeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.orange)

            Text("Focus Mode Active: This course is hidden from your sidebar notebooks shelf.")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button("Unhide Course") {
                toggleHideCourse()
            }
            .font(.system(size: 11, weight: .semibold))
            .buttonStyle(.plain)
            .foregroundStyle(Color.orange)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - In-Page Workspace Action & Filter Bar (Zero Toolbar Overflow)

    private var workspaceActionBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                // Wide window: Status pills on left, search and action icons on right
                HStack(spacing: 10) {
                    statusFilterPills

                    Spacer(minLength: 12)

                    searchField

                    actionIconsRow
                }

                // Narrow window: Fluid 2-line layout
                VStack(alignment: .leading, spacing: 8) {
                    statusFilterPills

                    HStack(spacing: 8) {
                        searchField
                        Spacer(minLength: 8)
                        actionIconsRow
                    }
                }
            }

            // Tag Badges
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

                        if selectedTag != nil {
                            clearTagButton
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var statusFilterPills: some View {
        HStack(spacing: 8) {
            statusButton(title: "All (\(subject.totalTopicsCount))", filter: .all)
            statusButton(title: "Remaining (\(subject.totalTopicsCount - subject.completedTopicsCount))", filter: .remaining)
            statusButton(title: "Completed (\(subject.completedTopicsCount))", filter: .completed)
        }
    }

    private var searchField: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
            TextField("Search topics...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(minWidth: 100, maxWidth: 160)
                .focused($isSearchFocused)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .liquidGlass(cornerRadius: 10)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var actionIconsRow: some View {
        HStack(spacing: 6) {
            // 1. Expand / Collapse all units
            Button(action: toggleAllUnits) {
                Image(systemName: allUnitsExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.plain)
            .liquidGlass(cornerRadius: 10)
            .help(allUnitsExpanded ? "Collapse all units" : "Expand all units")

            // 2. Update Syllabus (.md)
            Button(action: handleUpdateSyllabus) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.plain)
            .liquidGlass(cornerRadius: 10)
            .keyboardShortcut("u", modifiers: .command)
            .help("Update Syllabus from .md (Cmd+U)")

            // 3. Share Syllabus (AirDrop, Messages, Mail)
            Button(action: { SyllabusShareHelper.shareSubject(subject) }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.plain)
            .liquidGlass(cornerRadius: 10)
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .help("Share Syllabus (AirDrop, Messages, Mail) - Cmd+Shift+S")

            // 4. Save Syllabus to disk (.md)
            Button(action: { SyllabusShareHelper.saveSubjectToFile(subject) }) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.plain)
            .liquidGlass(cornerRadius: 10)
            .keyboardShortcut("s", modifiers: .command)
            .help("Save Syllabus to disk (.md) - Cmd+S")

            // 5. Hide / Focus Course Toggle
            Button(action: toggleHideCourse) {
                Image(systemName: subject.isHidden ? "eye" : "eye.slash")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(subject.isHidden ? Color.orange : Color.primary)
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.plain)
            .liquidGlass(cornerRadius: 10)
            .help(subject.isHidden ? "Unhide Course (Exit Focus Mode)" : "Hide Course (Focus Mode)")

            // 6. Delete Course
            Button(role: .destructive, action: { isShowingDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.red)
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.plain)
            .liquidGlass(cornerRadius: 10)
            .help("Delete Course")
        }
    }

    private var clearTagButton: some View {
        Button(action: { selectedTag = nil }) {
            HStack(spacing: 3) {
                Text("Clear tag filter")
                Image(systemName: "xmark")
                    .font(.system(size: 9))
            }
            .font(.system(size: 11))
            .foregroundStyle(Color.secondary)
        }
        .buttonStyle(.plain)
    }

    private func statusButton(title: String, filter: UnitSectionView.StatusFilter) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                statusFilter = filter
            }
        }) {
            Text(title)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.liquidGlass(prominent: statusFilter == filter, cornerRadius: 12))
        .help("Filter: \(title)")
    }

    // MARK: - Units Section

    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if subject.units.isEmpty {
                VStack(spacing: 8) {
                    Text("No units in this curriculum yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary)
                    Text("Click \"Add unit\" below or use Update Syllabus to import units.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ForEach(subject.sortedUnits) { unit in
                    UnitSectionView(
                        unit: unit,
                        accentColor: subjectColor,
                        searchText: searchText,
                        statusFilter: statusFilter,
                        selectedTag: selectedTag,
                        onDelete: {
                            withAnimation { deleteUnit(unit) }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Add Unit Section

    private var addUnitSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isAddingUnit {
                HStack(spacing: 8) {
                    TextField("Unit title (e.g. Unit 3: Dynamic Programming)", text: $newUnitTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .focused($isNewUnitFocused)
                        .onSubmit { confirmAddUnit() }
                        .onExitCommand {
                            isAddingUnit = false
                            newUnitTitle = ""
                        }

                    Button("Create unit") { confirmAddUnit() }
                        .buttonStyle(.liquidGlass(prominent: true))
                        .controlSize(.small)

                    Button("Cancel") {
                        isAddingUnit = false
                        newUnitTitle = ""
                    }
                    .buttonStyle(.liquidGlass)
                }
                .onAppear { isNewUnitFocused = true }
            } else {
                Button(action: { isAddingUnit = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 13))
                        Text("Add unit")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(subjectColor)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Actions

    private func toggleHideCourse() {
        withAnimation(.easeInOut(duration: 0.2)) {
            subject.isHidden.toggle()
            try? modelContext.save()
        }
    }

    private func handleUpdateSyllabus() {
        SyllabusShareHelper.pickUpdatedSyllabus(for: subject) { success in
            if success {
                try? modelContext.save()
                withAnimation {
                    updateToastMessage = "Syllabus updated successfully"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation {
                        updateToastMessage = nil
                    }
                }
            }
        }
    }

    private func deleteCourse() {
        modelContext.delete(subject)
        try? modelContext.save()
        onDeleteSubject?()
    }

    private var allUnitsExpanded: Bool {
        subject.units.allSatisfy { $0.isExpanded }
    }

    private func toggleAllUnits() {
        let targetState = !allUnitsExpanded
        withAnimation(.easeInOut(duration: 0.2)) {
            for unit in subject.units {
                unit.isExpanded = targetState
            }
        }
    }

    private func confirmAddUnit() {
        let trimmed = newUnitTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            isAddingUnit = false
            return
        }
        let newUnit = SyllabusUnit(
            title: trimmed,
            orderIndex: subject.units.count,
            subject: subject
        )
        subject.units.append(newUnit)
        newUnitTitle = ""
        isAddingUnit = false
    }

    private func deleteUnit(_ unit: SyllabusUnit) {
        if let idx = subject.units.firstIndex(where: { $0.id == unit.id }) {
            subject.units.remove(at: idx)
        }
    }
}
