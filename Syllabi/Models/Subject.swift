import Foundation
import SwiftData
import AppKit

@Model
public final class Subject {
    public var id: UUID = UUID()
    public var title: String = ""
    public var code: String = ""
    public var term: String = ""
    public var icon: String = "book.closed.fill"
    public var colorHex: String = "#3652FD"
    public var createdAt: Date = Date()
    @Attribute(.externalStorage) public var customIconData: Data? = nil
    public var isHidden: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \SyllabusUnit.subject)
    public var units: [SyllabusUnit] = []

    public init(
        id: UUID = UUID(),
        title: String,
        code: String = "",
        term: String = "",
        icon: String = "book.closed.fill",
        colorHex: String = "#3652FD",
        createdAt: Date = Date(),
        customIconData: Data? = nil,
        isHidden: Bool = false
    ) {
        self.id = id
        self.title = title
        self.code = code
        self.term = term
        self.icon = icon
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.customIconData = customIconData
        self.isHidden = isHidden
    }

    public var customImage: NSImage? {
        guard let data = customIconData else { return nil }
        return NSImage(data: data)
    }

    public var sortedUnits: [SyllabusUnit] {
        units.sorted { $0.orderIndex < $1.orderIndex }
    }

    public var allTopics: [TopicItem] {
        units.flatMap { $0.allTopics }
    }

    public var totalTopicsCount: Int {
        allTopics.count
    }

    public var completedTopicsCount: Int {
        allTopics.filter { $0.isCompleted }.count
    }

    public var progress: Double {
        guard totalTopicsCount > 0 else { return 0.0 }
        return Double(completedTopicsCount) / Double(totalTopicsCount)
    }

    /// Resolves an SF Symbol icon name from whatever string is stored (emoji or symbol name)
    public var sfSymbolName: String {
        switch icon {
        case "📚", "book", "books": return "book.closed.fill"
        case "💻", "laptop", "cs", "computer": return "laptopcomputer"
        case "🔬", "microscope", "science": return "atom"
        case "📐", "math", "ruler", "geometry": return "ruler.fill"
        case "🧠", "brain", "ai", "neuro": return "brain.head.profile"
        case "🎨", "art", "design": return "paintbrush.fill"
        case "🧪", "chem", "chemistry": return "flask.fill"
        case "📊", "stats", "data", "chart": return "chart.bar.fill"
        case "🏛️", "history", "gov": return "building.columns.fill"
        case "🌍", "geo", "world": return "globe.americas.fill"
        case "⚡", "physics", "ee": return "bolt.fill"
        case "⚙️", "eng", "engineering": return "gearshape.fill"
        case "📝", "writing", "english": return "pencil.and.outline"
        case "🚀", "aero", "rocket": return "airplane"
        case "💡", "idea", "philosophy": return "lightbulb.fill"
        case "🎯", "target", "focus": return "target"
        case "🧬", "bio", "biology": return "waveform.path.ecg"
        case "📜", "law", "paper": return "doc.text.fill"
        default:
            if NSImage(systemSymbolName: icon, accessibilityDescription: nil) != nil {
                return icon
            }
            return "book.closed.fill"
        }
    }
}
