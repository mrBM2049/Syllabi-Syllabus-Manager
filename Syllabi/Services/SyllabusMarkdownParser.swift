import Foundation

// MARK: - Parsed DTOs

public struct ParsedSyllabus: Equatable {
    public var subjectTitle: String
    public var code: String
    public var term: String
    public var icon: String
    public var colorHex: String
    public var units: [ParsedUnit]

    public init(
        subjectTitle: String = "Untitled Subject",
        code: String = "",
        term: String = "",
        icon: String = "book.closed.fill",
        colorHex: String = "#3652FD",
        units: [ParsedUnit] = []
    ) {
        self.subjectTitle = subjectTitle
        self.code = code
        self.term = term
        self.icon = icon
        self.colorHex = colorHex
        self.units = units
    }

    public var totalTopicsCount: Int {
        units.reduce(0) { $0 + $1.totalTopicsCount }
    }

    public var completedTopicsCount: Int {
        units.reduce(0) { $0 + $1.completedTopicsCount }
    }
}

public struct ParsedUnit: Equatable {
    public var title: String
    public var orderIndex: Int
    public var topics: [ParsedTopic]

    public init(
        title: String,
        orderIndex: Int = 0,
        topics: [ParsedTopic] = []
    ) {
        self.title = title
        self.orderIndex = orderIndex
        self.topics = topics
    }

    public var totalTopicsCount: Int {
        topics.reduce(0) { $0 + 1 + $1.subtopics.count }
    }

    public var completedTopicsCount: Int {
        topics.reduce(0) { acc, topic in
            acc + (topic.isCompleted ? 1 : 0) + topic.subtopics.filter { $0.isCompleted }.count
        }
    }
}

public struct ParsedTopic: Equatable {
    public var title: String
    public var isCompleted: Bool
    public var notes: String
    public var tags: [String]
    public var orderIndex: Int
    public var subtopics: [ParsedTopic]

    public init(
        title: String,
        isCompleted: Bool = false,
        notes: String = "",
        tags: [String] = [],
        orderIndex: Int = 0,
        subtopics: [ParsedTopic] = []
    ) {
        self.title = title
        self.isCompleted = isCompleted
        self.notes = notes
        self.tags = tags
        self.orderIndex = orderIndex
        self.subtopics = subtopics
    }
}

// MARK: - Parser Implementation

public struct SyllabusMarkdownParser {

    public init() {}

    public static func parse(markdown: String, fallbackTitle: String = "Untitled Subject") -> ParsedSyllabus {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var currentIndex = 0
        var subjectTitle = fallbackTitle
        var code = ""
        var term = ""
        var icon = "book.closed.fill"
        var colorHex = "#3652FD"

        // 1. Parse Frontmatter if present
        if currentIndex < lines.count && lines[currentIndex].trimmingCharacters(in: .whitespaces) == "---" {
            currentIndex += 1
            while currentIndex < lines.count {
                let line = lines[currentIndex]
                if line.trimmingCharacters(in: .whitespaces) == "---" {
                    currentIndex += 1
                    break
                }

                parseFrontmatterLine(line, title: &subjectTitle, code: &code, term: &term, icon: &icon, color: &colorHex)
                currentIndex += 1
            }
        }

        var units: [ParsedUnit] = []
        var currentUnit: ParsedUnit?
        var lastTopicWasSubtopic = false

        func ensureCurrentUnit() -> ParsedUnit {
            if let unit = currentUnit {
                return unit
            }
            let defaultUnit = ParsedUnit(title: "General", orderIndex: units.count, topics: [])
            currentUnit = defaultUnit
            return defaultUnit
        }

        while currentIndex < lines.count {
            let rawLine = lines[currentIndex]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            currentIndex += 1

            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }

            // H1 check: If subject title is still default, an H1 line can provide the title
            if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                let h1Title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if subjectTitle == fallbackTitle || subjectTitle.isEmpty {
                    subjectTitle = h1Title
                }
                continue
            }

            // 2. Units: H2 (##)
            if trimmed.hasPrefix("## ") || trimmed == "##" {
                if let finishedUnit = currentUnit {
                    units.append(finishedUnit)
                }
                let unitTitle = trimmed.hasPrefix("## ") ? String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces) : "Unit"
                currentUnit = ParsedUnit(title: unitTitle.isEmpty ? "Unit" : unitTitle, orderIndex: units.count, topics: [])
                lastTopicWasSubtopic = false
                continue
            }

            // 6. Notes: > ...
            if let noteContent = extractNoteContent(from: rawLine) {
                if var unit = currentUnit, !unit.topics.isEmpty {
                    let lastTopicIndex = unit.topics.count - 1
                    if lastTopicWasSubtopic && !unit.topics[lastTopicIndex].subtopics.isEmpty {
                        let lastSubIndex = unit.topics[lastTopicIndex].subtopics.count - 1
                        var sub = unit.topics[lastTopicIndex].subtopics[lastSubIndex]
                        sub.notes = sub.notes.isEmpty ? noteContent : "\(sub.notes)\n\(noteContent)"
                        unit.topics[lastTopicIndex].subtopics[lastSubIndex] = sub
                    } else {
                        var top = unit.topics[lastTopicIndex]
                        top.notes = top.notes.isEmpty ? noteContent : "\(top.notes)\n\(noteContent)"
                        unit.topics[lastTopicIndex] = top
                    }
                    currentUnit = unit
                }
                continue
            }

            // 3 & 4. Topics and Subtopics
            if let topicInfo = parseTopicLine(rawLine: rawLine) {
                var unit = ensureCurrentUnit()

                if topicInfo.isSubtopic && !unit.topics.isEmpty {
                    // Attach to most recent top-level topic
                    let lastIndex = unit.topics.count - 1
                    var parentTopic = unit.topics[lastIndex]
                    let subtopic = ParsedTopic(
                        title: topicInfo.title,
                        isCompleted: topicInfo.isCompleted,
                        notes: "",
                        tags: topicInfo.tags,
                        orderIndex: parentTopic.subtopics.count,
                        subtopics: []
                    )
                    parentTopic.subtopics.append(subtopic)
                    unit.topics[lastIndex] = parentTopic
                    lastTopicWasSubtopic = true
                } else {
                    // Top-level topic
                    let newTopic = ParsedTopic(
                        title: topicInfo.title,
                        isCompleted: topicInfo.isCompleted,
                        notes: "",
                        tags: topicInfo.tags,
                        orderIndex: unit.topics.count,
                        subtopics: []
                    )
                    unit.topics.append(newTopic)
                    lastTopicWasSubtopic = false
                }
                currentUnit = unit
            }
        }

        if let lastUnit = currentUnit {
            units.append(lastUnit)
        }

        return ParsedSyllabus(
            subjectTitle: subjectTitle,
            code: code,
            term: term,
            icon: icon,
            colorHex: colorHex,
            units: units
        )
    }

    // MARK: - Helper Methods

    private static func parseFrontmatterLine(
        _ line: String,
        title: inout String,
        code: inout String,
        term: inout String,
        icon: inout String,
        color: inout String
    ) {
        guard let colonIndex = line.firstIndex(of: ":") else { return }
        let key = line[..<colonIndex].trimmingCharacters(in: .whitespaces).lowercased()
        var val = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)

        // Strip quotes
        if (val.hasPrefix("\"") && val.hasSuffix("\"")) || (val.hasPrefix("'") && val.hasSuffix("'")) {
            val = String(val.dropFirst().dropLast())
        }
        val = val.trimmingCharacters(in: .whitespaces)

        switch key {
        case "subject", "title", "name":
            if !val.isEmpty { title = val }
        case "code", "course_code", "course":
            code = val
        case "term", "semester", "session":
            term = val
        case "icon", "emoji":
            if !val.isEmpty { icon = val }
        case "color", "colorhex", "color_hex":
            if !val.isEmpty {
                color = val.hasPrefix("#") ? val : "#\(val)"
            }
        default:
            break
        }
    }

    private static func extractNoteContent(from rawLine: String) -> String? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(">") else { return nil }
        var afterGt = trimmed.dropFirst()
        if afterGt.hasPrefix(" ") {
            afterGt = afterGt.dropFirst()
        }
        return String(afterGt)
    }

    private struct TopicLineInfo {
        var title: String
        var isCompleted: Bool
        var tags: [String]
        var isSubtopic: Bool
    }

    private static func parseTopicLine(rawLine: String) -> TopicLineInfo? {
        // Determine indentation level
        let leadingSpaces = rawLine.prefix(while: { $0 == " " || $0 == "\t" })
        var indentScore = 0
        for char in leadingSpaces {
            if char == "\t" { indentScore += 4 }
            else if char == " " { indentScore += 1 }
        }
        let isSubtopic = indentScore >= 2

        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

        var isCompleted = false
        var restOfLine = ""

        // Check for checkbox format: - [ ] or - [x] or * [ ] or * [x]
        if let match = matchCheckbox(trimmed) {
            isCompleted = match.completed
            restOfLine = match.text
        } else if trimmed.hasPrefix("- ") {
            restOfLine = String(trimmed.dropFirst(2))
        } else if trimmed.hasPrefix("* ") {
            restOfLine = String(trimmed.dropFirst(2))
        } else if let numBullet = matchNumberedBullet(trimmed) {
            restOfLine = numBullet
        } else {
            return nil
        }

        let (cleanTitle, tags) = extractTrailingTags(from: restOfLine)
        guard !cleanTitle.isEmpty else { return nil }

        return TopicLineInfo(
            title: cleanTitle,
            isCompleted: isCompleted,
            tags: tags,
            isSubtopic: isSubtopic
        )
    }

    private static func matchCheckbox(_ line: String) -> (completed: Bool, text: String)? {
        // Matches: "- [ ] foo", "- [x] foo", "- [X] foo", "* [ ] foo", "* [x] foo", "1. [ ] foo"
        var str = line
        if str.hasPrefix("- ") || str.hasPrefix("* ") {
            str = String(str.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        } else if let numBullet = matchNumberedBullet(str) {
            str = numBullet.trimmingCharacters(in: .whitespaces)
        } else {
            return nil
        }

        if str.hasPrefix("[ ] ") || str == "[ ]" {
            return (false, String(str.dropFirst(3)).trimmingCharacters(in: .whitespaces))
        } else if str.hasPrefix("[x] ") || str.hasPrefix("[X] ") || str == "[x]" || str == "[X]" {
            return (true, String(str.dropFirst(3)).trimmingCharacters(in: .whitespaces))
        }

        return nil
    }

    private static func matchNumberedBullet(_ line: String) -> String? {
        // e.g. "1. " or "12. "
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let prefix = line[..<dotIndex]
        guard !prefix.isEmpty && prefix.allSatisfy({ $0.isNumber }) else { return nil }
        let afterDot = line[line.index(after: dotIndex)...]
        guard afterDot.hasPrefix(" ") else { return nil }
        return String(afterDot.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    /// Extracts trailing bracketed tags like `[Tag1] [Tag2]` and returns (cleanTitle, tags)
    public static func extractTrailingTags(from text: String) -> (title: String, tags: [String]) {
        var current = text.trimmingCharacters(in: .whitespaces)
        var tags: [String] = []

        while current.hasSuffix("]") {
            guard let openBracket = current.lastIndex(of: "["),
                  openBracket > current.startIndex,
                  current[current.index(before: openBracket)].isWhitespace else { break }
            let tagContent = current[current.index(after: openBracket)..<current.index(before: current.endIndex)]
                .trimmingCharacters(in: .whitespaces)

            // Check that tag content doesn't contain brackets
            if !tagContent.isEmpty && !tagContent.contains("[") && !tagContent.contains("]") {
                if !tags.contains(tagContent) { tags.append(String(tagContent)) }
                current = String(current[..<openBracket]).trimmingCharacters(in: .whitespaces)
            } else {
                break
            }
        }

        // Tags were extracted from right to left, reverse to preserve original order
        tags.reverse()
        return (current, tags)
    }
}
