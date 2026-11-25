import SwiftUI
import SwiftData

public struct TopicRowView: View {
    @Bindable public var topic: TopicItem
    public var accentColor: Color = .accentColor
    public var onAddSubtopic: (() -> Void)? = nil
    public var onDelete: (() -> Void)? = nil

    @State private var isHovering = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var isNotesExpanded = false
    @FocusState private var isTitleFocused: Bool

    public init(
        topic: TopicItem,
        accentColor: Color = .accentColor,
        onAddSubtopic: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.topic = topic
        self.accentColor = accentColor
        self.onAddSubtopic = onAddSubtopic
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main Topic Line
            HStack(alignment: .center, spacing: 10) {
                // Tactile Rounded Checkbox (Expanded 28x28 Hitbox)
                Button(action: {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                        topic.toggleCompletion()
                        try? topic.modelContext?.save()
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                topic.isCompleted ? accentColor : (isHovering ? Color.secondary.opacity(0.6) : Color.secondary.opacity(0.35)),
                                lineWidth: 1.5
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(topic.isCompleted ? accentColor : Color.clear)
                            )
                            .frame(width: 18, height: 18)

                        if topic.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(topic.isCompleted ? "Mark topic uncompleted" : "Mark topic completed")

                // Topic Title
                if isEditingTitle {
                    TextField("Topic title", text: $editedTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13.5, weight: .regular))
                        .focused($isTitleFocused)
                        .onSubmit { saveTitle() }
                        .onExitCommand { isEditingTitle = false }
                        .onChange(of: isTitleFocused) { _, focused in
                            if !focused && isEditingTitle { saveTitle() }
                        }
                } else {
                    Text(SyllabusTextFormatter.display(topic.title))
                        .font(.system(size: 13.5, weight: topic.isCompleted ? .regular : .semibold))
                        .foregroundStyle(topic.isCompleted ? Color.secondary.opacity(0.65) : Color.primary)
                        .strikethrough(topic.isCompleted, color: Color.secondary.opacity(0.4))
                        .lineLimit(2)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { startEditing() }
                }

                // Tag Badges
                if !topic.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(topic.tags, id: \.self) { tag in
                            TagBadgeView(tag: tag)
                        }
                    }
                }

                Spacer(minLength: 8)

                // Note Indicator / Toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isNotesExpanded.toggle()
                    }
                }) {
                    Image(systemName: topic.notes.isEmpty ? "note.text" : "text.quote")
                        .font(.system(size: 12))
                        .foregroundStyle(
                            topic.notes.isEmpty ?
                            (isHovering ? Color.secondary.opacity(0.7) : Color.secondary.opacity(0.25)) :
                            accentColor
                        )
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(topic.notes.isEmpty ? "Add study note" : "Toggle study note")

                // Hover Action Bar
                if isHovering {
                    HStack(spacing: 4) {
                        if topic.parentTopic == nil {
                            Button(action: { onAddSubtopic?() }) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.secondary)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .help("Add subtopic")
                        }

                        Button(action: { onDelete?() }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .help("Delete topic")
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.035) : Color.clear)
            )
            .onHover { isHovering = $0 }

            // Study Notes Callout
            if isNotesExpanded || (!topic.notes.isEmpty && !topic.isCompleted) {
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(accentColor)
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("STUDY NOTE")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.secondary)
                            .tracking(0.5)

                        TextEditor(text: $topic.notes)
                            .font(.system(size: 12))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 40, maxHeight: 110)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 0.6)
                )
                .padding(.leading, 28)
                .padding(.vertical, 2)
            }

            // Subtopics Tree
            if !topic.sortedSubtopics.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(topic.sortedSubtopics) { subtopic in
                        SubtopicRowView(
                            subtopic: subtopic,
                            accentColor: accentColor,
                            onDelete: {
                                withAnimation {
                                    deleteSubtopic(subtopic)
                                }
                            }
                        )
                    }
                }
                .padding(.leading, 26)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 1.2)
                        .padding(.leading, 8)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private func startEditing() {
        editedTitle = topic.title
        isEditingTitle = true
        isTitleFocused = true
    }

    private func saveTitle() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            topic.title = trimmed
        }
        isEditingTitle = false
    }

    private func deleteSubtopic(_ subtopic: TopicItem) {
        if let idx = topic.subtopics.firstIndex(where: { $0.id == subtopic.id }) {
            topic.subtopics.remove(at: idx)
            topic.updateCompletionFromSubtopics()
        }
    }
}

// MARK: - Subtopic Row Component

public struct SubtopicRowView: View {
    @Bindable public var subtopic: TopicItem
    public var accentColor: Color = .accentColor
    public var onDelete: (() -> Void)? = nil

    @State private var isHovering = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var isNotesExpanded = false
    @FocusState private var isTitleFocused: Bool

    public init(
        subtopic: TopicItem,
        accentColor: Color = .accentColor,
        onDelete: (() -> Void)? = nil
    ) {
        self.subtopic = subtopic
        self.accentColor = accentColor
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 8) {
                // Checkbox (Expanded Hitbox)
                Button(action: {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                        subtopic.toggleCompletion()
                        try? subtopic.modelContext?.save()
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(
                                subtopic.isCompleted ? accentColor : (isHovering ? Color.secondary.opacity(0.6) : Color.secondary.opacity(0.35)),
                                lineWidth: 1.3
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(subtopic.isCompleted ? accentColor : Color.clear)
                            )
                            .frame(width: 15, height: 15)

                        if subtopic.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(subtopic.isCompleted ? "Mark subtopic uncompleted" : "Mark subtopic completed")

                // Title
                if isEditingTitle {
                    TextField("Subtopic title", text: $editedTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, weight: .regular))
                        .focused($isTitleFocused)
                        .onSubmit { saveTitle() }
                        .onExitCommand { isEditingTitle = false }
                        .onChange(of: isTitleFocused) { _, focused in
                            if !focused && isEditingTitle { saveTitle() }
                        }
                } else {
                    Text(SyllabusTextFormatter.display(subtopic.title))
                        .font(.system(size: 12.5, weight: subtopic.isCompleted ? .regular : .medium))
                        .foregroundStyle(subtopic.isCompleted ? Color.secondary.opacity(0.65) : Color.primary)
                        .strikethrough(subtopic.isCompleted, color: Color.secondary.opacity(0.4))
                        .lineLimit(2)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { startEditing() }
                }

                if !subtopic.tags.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(subtopic.tags, id: \.self) { tag in
                            TagBadgeView(tag: tag)
                        }
                    }
                }

                Spacer(minLength: 6)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isNotesExpanded.toggle()
                    }
                }) {
                    Image(systemName: subtopic.notes.isEmpty ? "note.text" : "text.quote")
                        .font(.system(size: 11))
                        .foregroundStyle(
                            subtopic.notes.isEmpty ?
                            (isHovering ? Color.secondary.opacity(0.6) : Color.secondary.opacity(0.25)) :
                            accentColor
                        )
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)

                if isHovering {
                    Button(action: { onDelete?() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Delete subtopic")
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.03) : Color.clear)
            )
            .onHover { isHovering = $0 }

            // Subtopic Note
            if isNotesExpanded || (!subtopic.notes.isEmpty && !subtopic.isCompleted) {
                HStack(alignment: .top, spacing: 6) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(accentColor.opacity(0.7))
                        .frame(width: 2.5)

                    TextEditor(text: $subtopic.notes)
                        .font(.system(size: 11.5))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 32, maxHeight: 80)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
                )
                .padding(.leading, 24)
            }
        }
    }

    private func startEditing() {
        editedTitle = subtopic.title
        isEditingTitle = true
        isTitleFocused = true
    }

    private func saveTitle() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            subtopic.title = trimmed
        }
        isEditingTitle = false
    }
}
