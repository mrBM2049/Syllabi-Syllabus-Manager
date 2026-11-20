import SwiftUI
import SwiftData
import UniformTypeIdentifiers

public struct ImportSyllabusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    public var onImportSuccess: ((Subject) -> Void)? = nil

    @State private var selectedTab: Int = 0
    @State private var rawMarkdown: String = ""
    @State private var parsedSyllabus: ParsedSyllabus? = nil
    @State private var selectedFileName: String? = nil
    @State private var isTargetedForDrop = false
    @State private var isFileImporterPresented = false
    @State private var showCopiedToast = false

    public init(initialMarkdown: String = "", onImportSuccess: ((Subject) -> Void)? = nil) {
        self._rawMarkdown = State(initialValue: initialMarkdown)
        self.onImportSuccess = onImportSuccess
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            modalHeader

            Divider()

            // Two-column split
            HSplitView {
                inputColumn
                    .frame(minWidth: 320, idealWidth: 380)

                previewColumn
                    .frame(minWidth: 380, idealWidth: 440)
            }

            Divider()

            // Footer Bar
            modalFooter
        }
        .frame(width: 840, height: 600)
        .overlay(alignment: .top) {
            if showCopiedToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("AI prompt copied to clipboard")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.ultraThickMaterial, in: Capsule())
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            if !rawMarkdown.isEmpty {
                updateParsedResult()
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [UTType.plainText, UTType(filenameExtension: "md") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImporterResult(result)
        }
    }

    // MARK: - Header

    private var modalHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Import Syllabus")
                    .font(.system(size: 15, weight: .bold))
                Text("Upload a .md file or paste formatted Markdown")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button(action: copyAIPrompt) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10.5))
                    Text("Copy AI prompt")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.liquidGlass)
            .help("Copy prompt template for ChatGPT or Claude to format any syllabus")

            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .padding(.leading, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Input Column

    private var inputColumn: some View {
        VStack(spacing: 12) {
            Picker("", selection: $selectedTab) {
                Text("File upload").tag(0)
                Text("Paste Markdown").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 14)

            if selectedTab == 0 {
                VStack(spacing: 14) {
                    Spacer()

                    Image(systemName: selectedFileName == nil ? "doc.badge.plus" : "doc.badge.checkmark")
                        .font(.system(size: 38))
                        .foregroundStyle(selectedFileName == nil ? Color.accentColor : Color.green)

                    if let fileName = selectedFileName {
                        VStack(spacing: 3) {
                            Text(fileName)
                                .font(.system(size: 13, weight: .semibold))
                            Text("Ready to import")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                        }
                    } else {
                        VStack(spacing: 3) {
                            Text("Drop your .md syllabus here")
                                .font(.system(size: 13, weight: .semibold))
                            Text("or browse to select from disk")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                        }
                    }

                    Button("Browse files...") {
                        isFileImporterPresented = true
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isTargetedForDrop ? Color.accentColor.opacity(0.06) : Color.primary.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isTargetedForDrop ? Color.accentColor : Color.secondary.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                        )
                )
                .padding(16)
                .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
                    handleDrop(providers: providers)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Markdown content")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.secondary)
                        Spacer()
                        if !rawMarkdown.isEmpty {
                            Button("Clear") {
                                rawMarkdown = ""
                                updateParsedResult()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                        }
                    }

                    TextEditor(text: $rawMarkdown)
                        .font(.system(size: 11.5, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.secondary.opacity(0.18), lineWidth: 0.5)
                        )
                        .onChange(of: rawMarkdown) {
                            updateParsedResult()
                        }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Preview Column

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Parsed Preview")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.secondary)
                Spacer()
                if let parsed = parsedSyllabus {
                    Text("\(parsed.units.count) units · \(parsed.totalTopicsCount) topics")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            if let parsed = parsedSyllabus {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Subject Summary Dossier
                        HStack(spacing: 12) {
                            let iconName = Subject(title: "", icon: parsed.icon).sfSymbolName
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(hex: parsed.colorHex).opacity(0.12))
                                    .frame(width: 44, height: 44)

                                Image(systemName: iconName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Color(hex: parsed.colorHex))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(parsed.subjectTitle)
                                    .font(.system(size: 14.5, weight: .bold))

                                HStack(spacing: 6) {
                                    if !parsed.code.isEmpty {
                                        Text(parsed.code)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: parsed.colorHex).opacity(0.12), in: Capsule())
                                            .foregroundStyle(Color(hex: parsed.colorHex))
                                    }
                                    if !parsed.term.isEmpty {
                                        Text(parsed.term)
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.025))
                        )

                        Divider()

                        // Units Tree
                        ForEach(parsed.units, id: \.title) { unit in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(unit.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.primary)

                                ForEach(unit.topics, id: \.title) { topic in
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Image(systemName: topic.isCompleted ? "checkmark.square.fill" : "square")
                                                .font(.system(size: 11))
                                                .foregroundStyle(topic.isCompleted ? Color.accentColor : Color.secondary)

                                            Text(topic.title)
                                                .font(.system(size: 12, weight: .medium))
                                                .strikethrough(topic.isCompleted, color: Color.secondary.opacity(0.5))

                                            ForEach(topic.tags, id: \.self) { tag in
                                                TagBadgeView(tag: tag)
                                            }
                                        }

                                        if !topic.notes.isEmpty {
                                            Text(topic.notes)
                                                .font(.system(size: 10.5))
                                                .foregroundStyle(Color.secondary)
                                                .padding(.leading, 18)
                                        }

                                        // Subtopics
                                        ForEach(topic.subtopics, id: \.title) { sub in
                                            HStack(spacing: 5) {
                                                Image(systemName: sub.isCompleted ? "checkmark.square.fill" : "square")
                                                    .font(.system(size: 9.5))
                                                    .foregroundStyle(sub.isCompleted ? Color.accentColor : Color.secondary)
                                                Text(sub.title)
                                                    .font(.system(size: 11))
                                                    .strikethrough(sub.isCompleted, color: Color.secondary.opacity(0.5))
                                                ForEach(sub.tags, id: \.self) { tag in
                                                    TagBadgeView(tag: tag)
                                                }
                                            }
                                            .padding(.leading, 18)
                                        }
                                    }
                                    .padding(.leading, 6)
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                }
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                    Text("No syllabus loaded")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary)
                    Text("Choose a file or paste markdown to view preview")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Footer

    private var modalFooter: some View {
        HStack {
            Spacer()

            Button("Cancel") { dismiss() }
                .buttonStyle(.liquidGlass)

            Button("Import subject") { confirmImport() }
                .buttonStyle(.liquidGlass(prominent: true))
                .disabled(parsedSyllabus == nil || (parsedSyllabus?.units.isEmpty ?? true))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Actions

    private func updateParsedResult() {
        guard !rawMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            parsedSyllabus = nil
            return
        }
        let fallback = selectedFileName?.replacingOccurrences(of: ".md", with: "") ?? "Untitled Subject"
        parsedSyllabus = SyllabusMarkdownParser.parse(markdown: rawMarkdown, fallbackTitle: fallback)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url = url {
                DispatchQueue.main.async {
                    loadFile(from: url)
                }
            }
        }
        return true
    }

    private func handleFileImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                loadFile(from: url)
            } else {
                loadFile(from: url)
            }
        case .failure(let error):
            print("Failed to import file: \(error)")
        }
    }

    public func loadFile(from url: URL) {
        selectedFileName = url.lastPathComponent
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            rawMarkdown = content
            updateParsedResult()
        } catch {
            print("Error reading file: \(error)")
        }
    }

    private func confirmImport() {
        guard let parsed = parsedSyllabus else { return }

        let subject = Subject(
            title: parsed.subjectTitle,
            code: parsed.code,
            term: parsed.term,
            icon: parsed.icon,
            colorHex: parsed.colorHex
        )
        modelContext.insert(subject)

        for unitDTO in parsed.units {
            let unit = SyllabusUnit(
                title: unitDTO.title,
                orderIndex: unitDTO.orderIndex,
                isExpanded: true,
                subject: subject
            )
            modelContext.insert(unit)
            subject.units.append(unit)

            for topicDTO in unitDTO.topics {
                let topic = TopicItem(
                    title: topicDTO.title,
                    isCompleted: topicDTO.isCompleted,
                    notes: topicDTO.notes,
                    tags: topicDTO.tags,
                    orderIndex: topicDTO.orderIndex,
                    unit: unit
                )
                modelContext.insert(topic)
                unit.topics.append(topic)

                for subDTO in topicDTO.subtopics {
                    let subtopic = TopicItem(
                        title: subDTO.title,
                        isCompleted: subDTO.isCompleted,
                        notes: subDTO.notes,
                        tags: subDTO.tags,
                        orderIndex: subDTO.orderIndex,
                        parentTopic: topic
                    )
                    modelContext.insert(subtopic)
                    topic.subtopics.append(subtopic)
                }

                topic.updateCompletionFromSubtopics()
            }
        }

        try? modelContext.save()
        onImportSuccess?(subject)
        dismiss()
    }

    private func copyAIPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(PromptTemplate.aiFormatterPrompt, forType: .string)
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { showCopiedToast = false }
        }
    }
}
