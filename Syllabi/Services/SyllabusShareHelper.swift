import SwiftUI
import AppKit
import UniformTypeIdentifiers

public enum SyllabusShareHelper {
    @MainActor
    static func copyMarkdown(_ subject: Subject) {
        let markdown = SyllabusMarkdownExporter.export(subject: subject)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
    }

    /// Opens the native macOS sharing service picker (AirDrop, Messages, Mail, Notes, etc.)
    @MainActor
    public static func shareSubject(_ subject: Subject, from sourceView: NSView? = nil) {
        let markdown = SyllabusMarkdownExporter.export(subject: subject)
        let sanitized = subject.title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        let filename = (sanitized.isEmpty ? "syllabus" : sanitized) + ".md"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try markdown.write(to: tempURL, atomically: true, encoding: .utf8)
            let picker = NSSharingServicePicker(items: [tempURL])

            if let window = NSApp.keyWindow {
                let view = sourceView ?? window.contentView ?? window.firstResponder as? NSView
                if let view = view {
                    picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
                }
            }
        } catch {
            print("Failed to share syllabus markdown: \(error)")
        }
    }

    /// Exports the subject to a file using standard macOS NSSavePanel
    @MainActor
    public static func saveSubjectToFile(_ subject: Subject) {
        let markdown = SyllabusMarkdownExporter.export(subject: subject)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false

        let sanitized = subject.title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        savePanel.nameFieldStringValue = "\((sanitized.isEmpty ? "syllabus" : sanitized)).md"

        savePanel.begin { response in
            if response == .OK, let targetURL = savePanel.url {
                do {
                    try markdown.write(to: targetURL, atomically: true, encoding: .utf8)
                } catch {
                    print("Error saving syllabus to file: \(error)")
                }
            }
        }
    }

    /// Prompts the user to pick an updated .md file to sync with an existing subject
    @MainActor
    public static func pickUpdatedSyllabus(for subject: Subject, completion: @escaping (Bool) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.message = "Select updated .md syllabus for \(subject.title)"

        openPanel.begin { response in
            if response == .OK, let selectedURL = openPanel.url {
                do {
                    let content = try SyllabusFile.read(selectedURL)
                    let parsed = SyllabusMarkdownParser.parse(markdown: content, fallbackTitle: subject.title)
                    guard parsed.totalTopicsCount > 0 else { throw SyllabusFile.ReadError.noTopics }
                    updateSubject(subject, with: parsed)
                    completion(true)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Couldn’t update the syllabus"
                    alert.informativeText = error.localizedDescription
                    if let window = NSApp.keyWindow {
                        alert.beginSheetModal(for: window)
                    } else {
                        alert.runModal()
                    }
                    completion(false)
                }
            } else {
                completion(false)
            }
        }
    }

    /// Updates an existing subject from parsed syllabus while preserving completed status for matching topics
    public static func updateSubject(_ subject: Subject, with parsed: ParsedSyllabus) {
        guard parsed.totalTopicsCount > 0 else { return }
        // Collect existing completed states and notes keyed by trimmed title
        var existingCompletedMap: [String: Bool] = [:]
        var existingNotesMap: [String: String] = [:]

        for unit in subject.units {
            for topic in unit.allTopics {
                let key = topic.title.trimmingCharacters(in: .whitespaces).lowercased()
                existingCompletedMap[key] = topic.isCompleted
                if !topic.notes.isEmpty {
                    existingNotesMap[key] = topic.notes
                }
            }
        }

        if !parsed.subjectTitle.isEmpty {
            subject.title = parsed.subjectTitle
        }
        if !parsed.code.isEmpty {
            subject.code = parsed.code
        }
        if !parsed.term.isEmpty {
            subject.term = parsed.term
        }
        if !parsed.icon.isEmpty {
            subject.icon = parsed.icon
        }
        if !parsed.colorHex.isEmpty {
            subject.colorHex = parsed.colorHex
        }

        // Remove existing units
        subject.units.removeAll()

        // Build new units & topics
        for (uIdx, parsedUnit) in parsed.units.enumerated() {
            let unit = SyllabusUnit(title: parsedUnit.title, orderIndex: uIdx, subject: subject)

            for (tIdx, parsedTopic) in parsedUnit.topics.enumerated() {
                let key = parsedTopic.title.trimmingCharacters(in: .whitespaces).lowercased()
                let wasCompleted = existingCompletedMap[key] ?? parsedTopic.isCompleted
                let preservedNote = parsedTopic.notes.isEmpty ? (existingNotesMap[key] ?? "") : parsedTopic.notes

                let topic = TopicItem(
                    title: parsedTopic.title,
                    isCompleted: wasCompleted,
                    notes: preservedNote,
                    tags: parsedTopic.tags,
                    orderIndex: tIdx,
                    unit: unit
                )

                for (sIdx, parsedSub) in parsedTopic.subtopics.enumerated() {
                    let subKey = parsedSub.title.trimmingCharacters(in: .whitespaces).lowercased()
                    let subWasCompleted = existingCompletedMap[subKey] ?? parsedSub.isCompleted
                    let subPreservedNote = parsedSub.notes.isEmpty ? (existingNotesMap[subKey] ?? "") : parsedSub.notes

                    let subtopic = TopicItem(
                        title: parsedSub.title,
                        isCompleted: subWasCompleted,
                        notes: subPreservedNote,
                        tags: parsedSub.tags,
                        orderIndex: sIdx,
                        unit: unit,
                        parentTopic: topic
                    )
                    topic.subtopics.append(subtopic)
                }

                unit.topics.append(topic)
            }
            subject.units.append(unit)
        }
    }
}
