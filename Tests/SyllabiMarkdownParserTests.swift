import XCTest
@testable import Syllabi

final class SyllabusMarkdownParserTests: XCTestCase {

    func testStandardSyllabusParsing() {
        let markdown = """
        ---
        subject: "Data Structures & Algorithms"
        code: "CS201"
        term: "Semester 3"
        icon: "🌲"
        color: "#10B981"
        ---

        ## Unit 1: Foundations
        - [x] Asymptotic Analysis [Theory] [Exam]
          > Big O, Big Omega, and Theta notation definitions
        - [ ] Recurrence Relations [Math]

        ## Unit 2: Trees & Graphs
        - [ ] Binary Search Trees [Core]
          - [x] BST Insertion & Deletion
            > Handle node with two children via in-order successor
          - [ ] AVL Rotations [Exam]
        - [ ] Graph Traversals
          - [ ] BFS Implementation
          - [ ] DFS Implementation
        """

        let parsed = SyllabusMarkdownParser.parse(markdown: markdown)

        XCTAssertEqual(parsed.subjectTitle, "Data Structures & Algorithms")
        XCTAssertEqual(parsed.code, "CS201")
        XCTAssertEqual(parsed.term, "Semester 3")
        XCTAssertEqual(parsed.icon, "🌲")
        XCTAssertEqual(parsed.colorHex, "#10B981")
        XCTAssertEqual(parsed.units.count, 2)

        // Unit 1
        let unit1 = parsed.units[0]
        XCTAssertEqual(unit1.title, "Unit 1: Foundations")
        XCTAssertEqual(unit1.topics.count, 2)
        XCTAssertEqual(unit1.topics[0].title, "Asymptotic Analysis")
        XCTAssertTrue(unit1.topics[0].isCompleted)
        XCTAssertEqual(unit1.topics[0].tags, ["Theory", "Exam"])
        XCTAssertEqual(unit1.topics[0].notes, "Big O, Big Omega, and Theta notation definitions")
        XCTAssertEqual(unit1.topics[1].title, "Recurrence Relations")
        XCTAssertFalse(unit1.topics[1].isCompleted)
        XCTAssertEqual(unit1.topics[1].tags, ["Math"])

        // Unit 2
        let unit2 = parsed.units[1]
        XCTAssertEqual(unit2.title, "Unit 2: Trees & Graphs")
        XCTAssertEqual(unit2.topics.count, 2)

        let bstTopic = unit2.topics[0]
        XCTAssertEqual(bstTopic.title, "Binary Search Trees")
        XCTAssertEqual(bstTopic.tags, ["Core"])
        XCTAssertEqual(bstTopic.subtopics.count, 2)
        XCTAssertEqual(bstTopic.subtopics[0].title, "BST Insertion & Deletion")
        XCTAssertTrue(bstTopic.subtopics[0].isCompleted)
        XCTAssertEqual(bstTopic.subtopics[0].notes, "Handle node with two children via in-order successor")
        XCTAssertEqual(bstTopic.subtopics[1].title, "AVL Rotations")
        XCTAssertFalse(bstTopic.subtopics[1].isCompleted)
        XCTAssertEqual(bstTopic.subtopics[1].tags, ["Exam"])

        let graphTopic = unit2.topics[1]
        XCTAssertEqual(graphTopic.title, "Graph Traversals")
        XCTAssertEqual(graphTopic.subtopics.count, 2)
        XCTAssertEqual(graphTopic.subtopics[0].title, "BFS Implementation")
        XCTAssertEqual(graphTopic.subtopics[1].title, "DFS Implementation")
    }

    func testFallbackAndMessyMarkdown() {
        let markdown = """
        # Machine Learning Basics

        - Introduction to Supervised Learning [Basics]
        * [x] Linear Regression [Core]
          > Gradient descent formula: w = w - alpha * grad
        1. Logistic Regression
        """

        let parsed = SyllabusMarkdownParser.parse(markdown: markdown, fallbackTitle: "Untitled Subject")

        XCTAssertEqual(parsed.subjectTitle, "Machine Learning Basics")
        XCTAssertEqual(parsed.units.count, 1)
        XCTAssertEqual(parsed.units[0].title, "General")
        XCTAssertEqual(parsed.units[0].topics.count, 3)
        XCTAssertEqual(parsed.units[0].topics[0].title, "Introduction to Supervised Learning")
        XCTAssertEqual(parsed.units[0].topics[0].tags, ["Basics"])
        XCTAssertFalse(parsed.units[0].topics[0].isCompleted)

        XCTAssertEqual(parsed.units[0].topics[1].title, "Linear Regression")
        XCTAssertTrue(parsed.units[0].topics[1].isCompleted)
        XCTAssertEqual(parsed.units[0].topics[1].tags, ["Core"])
        XCTAssertTrue(parsed.units[0].topics[1].notes.contains("Gradient descent"))

        XCTAssertEqual(parsed.units[0].topics[2].title, "Logistic Regression")
    }

    func testTrailingTagExtraction() {
        let (title1, tags1) = SyllabusMarkdownParser.extractTrailingTags(from: "Database Normalization [3NF] Concepts [Exam]")
        XCTAssertEqual(title1, "Database Normalization [3NF] Concepts") // Mid-title bracket preserved
        XCTAssertEqual(tags1, ["Exam"])

        let (title2, tags2) = SyllabusMarkdownParser.extractTrailingTags(from: "Operating Systems [Kernel] [High Priority]")
        XCTAssertEqual(title2, "Operating Systems")
        XCTAssertEqual(tags2, ["Kernel", "High Priority"])

        let (title3, tags3) = SyllabusMarkdownParser.extractTrailingTags(from: "Plain Topic Without Tags")
        XCTAssertEqual(title3, "Plain Topic Without Tags")
        XCTAssertTrue(tags3.isEmpty)

        let (title4, tags4) = SyllabusMarkdownParser.extractTrailingTags(from: "Multiple Trailing Tags [TagA] [TagB] [TagC]")
        XCTAssertEqual(title4, "Multiple Trailing Tags")
        XCTAssertEqual(tags4, ["TagA", "TagB", "TagC"])
    }

    func testExporterRoundTrip() {
        let parsed = ParsedSyllabus(
            subjectTitle: "Cybersecurity 101",
            code: "SEC101",
            term: "Fall 2024",
            icon: "🔒",
            colorHex: "#EF4444",
            units: [
                ParsedUnit(
                    title: "Unit 1: Cryptography",
                    orderIndex: 0,
                    topics: [
                        ParsedTopic(
                            title: "RSA Encryption",
                            isCompleted: true,
                            notes: "Public and private key mathematics",
                            tags: ["Math", "High"],
                            orderIndex: 0,
                            subtopics: [
                                ParsedTopic(
                                    title: "Key Generation",
                                    isCompleted: true,
                                    notes: "",
                                    tags: [],
                                    orderIndex: 0,
                                    subtopics: []
                                ),
                                ParsedTopic(
                                    title: "Modular Arithmetic",
                                    isCompleted: false,
                                    notes: "",
                                    tags: ["Basics"],
                                    orderIndex: 1,
                                    subtopics: []
                                )
                            ]
                        )
                    ]
                )
            ]
        )

        let exported = SyllabusMarkdownExporter.export(parsed: parsed)
        XCTAssertTrue(exported.contains("subject: \"Cybersecurity 101\""))
        XCTAssertTrue(exported.contains("code: \"SEC101\""))
        XCTAssertTrue(exported.contains("icon: \"🔒\""))
        XCTAssertTrue(exported.contains("## Unit 1: Cryptography"))
        XCTAssertTrue(exported.contains("- [x] RSA Encryption [Math] [High]"))
        XCTAssertTrue(exported.contains("  > Public and private key mathematics"))
        XCTAssertTrue(exported.contains("  - [x] Key Generation"))
        XCTAssertTrue(exported.contains("  - [ ] Modular Arithmetic [Basics]"))

        // Re-parse exported string
        let reparsed = SyllabusMarkdownParser.parse(markdown: exported)
        XCTAssertEqual(reparsed.subjectTitle, parsed.subjectTitle)
        XCTAssertEqual(reparsed.code, parsed.code)
        XCTAssertEqual(reparsed.units.count, 1)
        XCTAssertEqual(reparsed.units[0].topics.count, 1)
        XCTAssertEqual(reparsed.units[0].topics[0].subtopics.count, 2)
        XCTAssertTrue(reparsed.units[0].topics[0].subtopics[0].isCompleted)
        XCTAssertFalse(reparsed.units[0].topics[0].subtopics[1].isCompleted)
    }
}
