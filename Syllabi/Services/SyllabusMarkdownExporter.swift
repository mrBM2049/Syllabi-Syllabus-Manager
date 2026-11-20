import Foundation

public struct SyllabusMarkdownExporter {

    public init() {}

    public static func export(subject: Subject) -> String {
        var output = ""

        // Frontmatter
        output += "---\n"
        output += "subject: \"\(subject.title)\"\n"
        if !subject.code.isEmpty {
            output += "code: \"\(subject.code)\"\n"
        }
        if !subject.term.isEmpty {
            output += "term: \"\(subject.term)\"\n"
        }
        output += "icon: \"\(subject.icon)\"\n"
        output += "color: \"\(subject.colorHex)\"\n"
        output += "---\n\n"

        // Units
        for unit in subject.sortedUnits {
            output += "## \(unit.title)\n"
            for topic in unit.topLevelTopics {
                output += formatTopic(topic: topic, indentLevel: 0)
            }
            output += "\n"
        }

        return output.trimmingCharacters(in: .newlines) + "\n"
    }

    public static func export(parsed: ParsedSyllabus) -> String {
        var output = ""

        // Frontmatter
        output += "---\n"
        output += "subject: \"\(parsed.subjectTitle)\"\n"
        if !parsed.code.isEmpty {
            output += "code: \"\(parsed.code)\"\n"
        }
        if !parsed.term.isEmpty {
            output += "term: \"\(parsed.term)\"\n"
        }
        output += "icon: \"\(parsed.icon)\"\n"
        output += "color: \"\(parsed.colorHex)\"\n"
        output += "---\n\n"

        // Units
        for unit in parsed.units {
            output += "## \(unit.title)\n"
            for topic in unit.topics {
                output += formatParsedTopic(topic: topic, indentLevel: 0)
            }
            output += "\n"
        }

        return output.trimmingCharacters(in: .newlines) + "\n"
    }

    private static func formatTopic(topic: TopicItem, indentLevel: Int) -> String {
        var result = ""
        let indent = String(repeating: "  ", count: indentLevel)
        let check = topic.isCompleted ? "[x]" : "[ ]"

        var titleWithTags = topic.title
        if !topic.tags.isEmpty {
            let tagsString = topic.tags.map { "[\($0)]" }.joined(separator: " ")
            titleWithTags += " \(tagsString)"
        }

        result += "\(indent)- \(check) \(titleWithTags)\n"

        // Notes
        if !topic.notes.isEmpty {
            let noteIndent = indent + "  > "
            let noteLines = topic.notes.components(separatedBy: "\n")
            for line in noteLines {
                result += "\(noteIndent)\(line)\n"
            }
        }

        // Subtopics
        for sub in topic.sortedSubtopics {
            result += formatTopic(topic: sub, indentLevel: indentLevel + 1)
        }

        return result
    }

    private static func formatParsedTopic(topic: ParsedTopic, indentLevel: Int) -> String {
        var result = ""
        let indent = String(repeating: "  ", count: indentLevel)
        let check = topic.isCompleted ? "[x]" : "[ ]"

        var titleWithTags = topic.title
        if !topic.tags.isEmpty {
            let tagsString = topic.tags.map { "[\($0)]" }.joined(separator: " ")
            titleWithTags += " \(tagsString)"
        }

        result += "\(indent)- \(check) \(titleWithTags)\n"

        // Notes
        if !topic.notes.isEmpty {
            let noteIndent = indent + "  > "
            let noteLines = topic.notes.components(separatedBy: "\n")
            for line in noteLines {
                result += "\(noteIndent)\(line)\n"
            }
        }

        // Subtopics
        for sub in topic.subtopics {
            result += formatParsedTopic(topic: sub, indentLevel: indentLevel + 1)
        }

        return result
    }
}
