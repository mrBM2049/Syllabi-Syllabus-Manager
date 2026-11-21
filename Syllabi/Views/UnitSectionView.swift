import SwiftUI
import SwiftData

public struct UnitSectionView: View {
    @Bindable public var unit: SyllabusUnit
    public var accentColor: Color = .accentColor
    public var searchText: String = ""
    public var statusFilter: StatusFilter = .all
    public var selectedTag: String? = nil
    public var onDelete: (() -> Void)? = nil

    @State private var isHoveringHeader = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var isAddingTopic = false
    @State private var newTopicTitle = ""
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNewTopicFocused: Bool

    public enum StatusFilter {
        case all
        case remaining
        case completed
    }

    public init(
        unit: SyllabusUnit,
        accentColor: Color = .accentColor,
        searchText: String = "",
        statusFilter: StatusFilter = .all,
        selectedTag: String? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.unit = unit
        self.accentColor = accentColor
        self.searchText = searchText
        self.statusFilter = statusFilter
        self.selectedTag = selectedTag
        self.onDelete = onDelete
    }

    private var filteredTopics: [TopicItem] {
        unit.topLevelTopics.filter { topic in
            if !searchText.isEmpty {
                let matchesTopic = topic.title.localizedCaseInsensitiveContains(searchText) ||
                    topic.notes.localizedCaseInsensitiveContains(searchText) ||
                    topic.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
                let matchesSub = topic.subtopics.contains { sub in
                    sub.title.localizedCaseInsensitiveContains(searchText) ||
                    sub.notes.localizedCaseInsensitiveContains(searchText) ||
                    sub.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
                }
                if !matchesTopic && !matchesSub {
                    return false
                }
            }

            if let tag = selectedTag {
                let topicHasTag = topic.tags.contains(tag)
                let subHasTag = topic.subtopics.contains { $0.tags.contains(tag) }
                if !topicHasTag && !subHasTag {
                    return false
                }
            }

            switch statusFilter {
            case .all:
                return true
            case .remaining:
                return !topic.isCompleted || topic.subtopics.contains { !$0.isCompleted }
            case .completed:
                return topic.isCompleted
            }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Notion-Style Toggle Header
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        unit.isExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.secondary)
                        .rotationEffect(.degrees(unit.isExpanded ? 90 : 0))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)

                if isEditingTitle {
                    TextField("Unit title", text: $editedTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14.5, weight: .bold))
                        .focused($isTitleFocused)
                        .onSubmit { saveTitle() }
                        .onExitCommand { isEditingTitle = false }
                } else {
                    Text(SyllabusTextFormatter.display(unit.title))
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.primary)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { startEditing() }
                }

                Spacer()

                // Progress stats & track
                HStack(spacing: 8) {
                    Text("\(unit.completedCount)/\(unit.totalCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.secondary)

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                            .frame(width: 50, height: 6)

                        Capsule()
                            .fill(accentColor)
                            .frame(width: 50 * CGFloat(unit.progress), height: 6)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: unit.progress)
                    }
                }

                // Actions Menu
                Menu {
                    Button(action: startEditing) {
                        Label("Rename unit", systemImage: "pencil")
                    }
                    Button(action: { isAddingTopic = true }) {
                        Label("Add topic", systemImage: "plus")
                    }
                    Divider()
                    Button(role: .destructive, action: { onDelete?() }) {
                        Label("Delete unit", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                        .opacity(isHoveringHeader ? 1.0 : 0.0)
                        .frame(width: 18, height: 18)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHoveringHeader ? Color.primary.opacity(0.03) : Color.clear)
            )
            .onHover { isHoveringHeader = $0 }

            // Expanded Unit Content
            if unit.isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    if filteredTopics.isEmpty && !unit.topics.isEmpty {
                        Text("No topics match filter")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.secondary.opacity(0.8))
                            .padding(.leading, 24)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(filteredTopics) { topic in
                            TopicRowView(
                                topic: topic,
                                accentColor: accentColor,
                                onAddSubtopic: { addNewSubtopic(to: topic) },
                                onDelete: {
                                    withAnimation { deleteTopic(topic) }
                                }
                            )
                        }
                    }

                    // Add topic row
                    if isAddingTopic {
                        HStack(spacing: 8) {
                            Circle()
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1.2)
                                .frame(width: 14, height: 14)

                            TextField("Topic title (e.g. Asymptotic Analysis [Core] [Exam])", text: $newTopicTitle)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12.5))
                                .focused($isNewTopicFocused)
                                .onSubmit { confirmAddTopic() }
                                .onExitCommand {
                                    isAddingTopic = false
                                    newTopicTitle = ""
                                }

                            Button("Add") { confirmAddTopic() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                            Button("Cancel") {
                                isAddingTopic = false
                                newTopicTitle = ""
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                        }
                        .padding(.leading, 6)
                        .padding(.vertical, 4)
                        .onAppear { isNewTopicFocused = true }
                    } else {
                        Button(action: { isAddingTopic = true }) {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("New topic")
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .foregroundStyle(Color.secondary.opacity(0.8))
                            .padding(.leading, 6)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 12)
            }
        }
    }

    private func startEditing() {
        editedTitle = unit.title
        isEditingTitle = true
        isTitleFocused = true
    }

    private func saveTitle() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            unit.title = trimmed
        }
        isEditingTitle = false
    }

    private func confirmAddTopic() {
        let trimmed = newTopicTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            isAddingTopic = false
            return
        }

        let (cleanTitle, tags) = SyllabusMarkdownParser.extractTrailingTags(from: trimmed)
        let newTopic = TopicItem(
            title: cleanTitle,
            tags: tags,
            orderIndex: unit.topics.count,
            unit: unit
        )
        unit.topics.append(newTopic)
        newTopicTitle = ""
        isAddingTopic = false
    }

    private func addNewSubtopic(to topic: TopicItem) {
        let newSub = TopicItem(
            title: "New Subtopic",
            orderIndex: topic.subtopics.count,
            parentTopic: topic
        )
        topic.subtopics.append(newSub)
    }

    private func deleteTopic(_ topic: TopicItem) {
        if let idx = unit.topics.firstIndex(where: { $0.id == topic.id }) {
            unit.topics.remove(at: idx)
        }
    }
}
