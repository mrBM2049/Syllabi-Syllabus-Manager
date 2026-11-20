import Foundation
import SwiftData

@Model
public final class SyllabusUnit {
    public var id: UUID = UUID()
    public var title: String = ""
    public var orderIndex: Int = 0
    public var isExpanded: Bool = true

    public var subject: Subject?

    @Relationship(deleteRule: .cascade, inverse: \TopicItem.unit)
    public var topics: [TopicItem] = []

    public init(
        id: UUID = UUID(),
        title: String,
        orderIndex: Int = 0,
        isExpanded: Bool = true,
        subject: Subject? = nil
    ) {
        self.id = id
        self.title = title
        self.orderIndex = orderIndex
        self.isExpanded = isExpanded
        self.subject = subject
    }

    public var topLevelTopics: [TopicItem] {
        topics.filter { $0.parentTopic == nil }.sorted { $0.orderIndex < $1.orderIndex }
    }

    public var allTopics: [TopicItem] {
        var result: [TopicItem] = []
        for topic in topLevelTopics {
            result.append(topic)
            result.append(contentsOf: topic.sortedSubtopics)
        }
        return result
    }

    public var totalCount: Int {
        allTopics.count
    }

    public var completedCount: Int {
        allTopics.filter { $0.isCompleted }.count
    }

    public var progress: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(completedCount) / Double(totalCount)
    }
}
