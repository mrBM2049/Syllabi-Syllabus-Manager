import Foundation
import SwiftData

@Model
public final class TopicItem {
    public var id: UUID = UUID()
    public var title: String = ""
    public var isCompleted: Bool = false
    public var completedAt: Date?
    public var notes: String = ""
    public var tags: [String] = []
    public var orderIndex: Int = 0

    public var unit: SyllabusUnit?
    public var parentTopic: TopicItem?

    @Relationship(deleteRule: .cascade, inverse: \TopicItem.parentTopic)
    public var subtopics: [TopicItem] = []

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        notes: String = "",
        tags: [String] = [],
        orderIndex: Int = 0,
        unit: SyllabusUnit? = nil,
        parentTopic: TopicItem? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.notes = notes
        self.tags = tags
        self.orderIndex = orderIndex
        self.unit = unit
        self.parentTopic = parentTopic
    }

    public var sortedSubtopics: [TopicItem] {
        subtopics.sorted { $0.orderIndex < $1.orderIndex }
    }

    public func toggleCompletion() {
        setCompletion(!isCompleted)
    }

    public func setCompletion(_ completed: Bool) {
        self.isCompleted = completed
        self.completedAt = completed ? (self.completedAt ?? Date()) : nil

        // If this topic has subtopics, cascade the completion state down to all subtopics
        if !subtopics.isEmpty {
            for sub in subtopics {
                sub.isCompleted = completed
                sub.completedAt = completed ? (sub.completedAt ?? Date()) : nil
            }
        }

        // If this is a subtopic, check if parent topic should be updated
        if let parent = parentTopic {
            parent.updateCompletionFromSubtopics()
        }

        try? modelContext?.save()
    }

    public func updateCompletionFromSubtopics() {
        guard !subtopics.isEmpty else { return }
        let allDone = subtopics.allSatisfy { $0.isCompleted }
        if allDone != isCompleted {
            self.isCompleted = allDone
            self.completedAt = allDone ? (self.completedAt ?? Date()) : nil
            try? modelContext?.save()
        }
    }
}
