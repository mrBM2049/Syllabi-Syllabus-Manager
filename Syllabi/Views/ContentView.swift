import SwiftUI
import SwiftData
import UniformTypeIdentifiers

public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Query(sort: \Subject.createdAt, order: .forward) private var subjects: [Subject]

    @State private var selection: SidebarSelection = .dashboard
    @State private var isShowingImportSheet = false
    @State private var isShowingNewCourseSheet = false
    @State private var droppedFileURL: URL? = nil
    @State private var showCopiedToast = false
    @State private var isShowingWhatsNew = false
    @StateObject private var updateService = AppUpdateService()
    @AppStorage("lastSeenWhatsNewVersion") private var lastSeenWhatsNewVersion = ""
    @AppStorage("lastPromptedUpdateVersion") private var lastPromptedUpdateVersion = ""
    @State private var isShowingUpdatePrompt = false

    // Blank course form fields
    @State private var blankTitle = ""
    @State private var blankCode = ""
    @State private var blankTerm = ""
    @State private var blankIcon = "book.closed.fill"
    @State private var blankColorHex = "#3652FD"
    @State private var blankCustomIconData: Data? = nil

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $selection,
                subjects: subjects,
                onImportClicked: {
                    isShowingImportSheet = true
                },
                onNewCourseClicked: {
                    resetAndOpenNewCourse()
                },
                onDropFile: { url in
                    droppedFileURL = url
                    isShowingImportSheet = true
                },
                onExportSubject: { subject in
                    SyllabusShareHelper.saveSubjectToFile(subject)
                },
                updateAvailable: updateService.hasUpdate,
                updateVersion: updateService.latestRelease?.version ?? "",
                isUpdating: updateService.isDownloading,
                onUpdateClicked: startUpdate
            )
        } detail: {
            ZStack {
                ambientBackground
                VStack(spacing: 0) {
                    switch selection {
                    case .dashboard:
                        DashboardView(
                            subjects: subjects,
                            onSelectSubject: { subject in selection = .subject(subject.id) },
                            onOpenAllCourses: { selection = .courses },
                            onOpenLessons: { selection = .lessons },
                            onImportClicked: { isShowingImportSheet = true },
                            onDropFile: { url in droppedFileURL = url; isShowingImportSheet = true }
                        )
                    case .courses:
                        CoursesView(
                            subjects: subjects,
                            onSelectSubject: { subject in selection = .subject(subject.id) },
                            onImportClicked: { isShowingImportSheet = true },
                            onNewCourseClicked: { resetAndOpenNewCourse() }
                        )
                    case .lessons:
                        LessonsView(subjects: subjects, onSelectSubject: { subject in selection = .subject(subject.id) })
                    case .calendar:
                        CalendarScheduleView(subjects: subjects, onSelectSubject: { subject in selection = .subject(subject.id) })
                    case .subject(let id):
                        if let subject = subjects.first(where: { $0.id == id }) {
                            SubjectDetailView(subject: subject, onExportMarkdown: { SyllabusShareHelper.saveSubjectToFile(subject) }, onDeleteSubject: { selection = .courses })
                        } else {
                            CoursesView(subjects: subjects, onSelectSubject: { subject in selection = .subject(subject.id) }, onImportClicked: { isShowingImportSheet = true }, onNewCourseClicked: { resetAndOpenNewCourse() })
                        }
                    }
                }
            }
            .navigationTitle("Syllabi")
            .toolbar {
                // Global Top Navigation Bar: Compact, clean liquid glass buttons
                ToolbarItemGroup(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        Button {
                            undoManager?.undo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .buttonStyle(.liquidGlass(cornerRadius: 10))
                        .disabled(!(undoManager?.canUndo ?? false))
                        .help("Undo (⌘Z)")

                        Button {
                            undoManager?.redo()
                        } label: {
                            Image(systemName: "arrow.uturn.forward")
                        }
                        .buttonStyle(.liquidGlass(cornerRadius: 10))
                        .disabled(!(undoManager?.canRedo ?? false))
                        .help("Redo (⇧⌘Z)")

                        // 1. Copy AI Prompt Button (Crisp Sparkles Icon)
                        Button(action: copyAIPrompt) {
                            Label("Copy AI prompt", systemImage: "wand.and.stars")
                                .font(.system(size: 10.5, weight: .semibold))
                                .padding(.horizontal, 2)
                        }
                        .buttonStyle(.liquidGlass(cornerRadius: 10))
                        .fixedSize(horizontal: true, vertical: false)
                        .help("Copy AI Syllabus Formatter Prompt (Cmd+Shift+C)")

                        // 2. Add Course Menu Button
                        Menu {
                            Button(action: resetAndOpenNewCourse) {
                                Label("New Course Notebook...", systemImage: "plus")
                            }
                            .keyboardShortcut("n", modifiers: .command)

                            Button(action: { isShowingImportSheet = true }) {
                                Label("Import Syllabus (.md)...", systemImage: "square.and.arrow.down")
                            }
                            .keyboardShortcut("i", modifiers: .command)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Course")
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.accentColor)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .help("Add Course: Create new notebook or import .md (Cmd+N / Cmd+I)")

                    }
                    .padding(.leading, 8)
                }
            }
            .overlay(alignment: .top) {
                if showCopiedToast {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                        Text("AI Formatter Prompt copied to clipboard")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThickMaterial, in: Capsule())
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .overlay {
            FocusDismissalView()
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        }
        .sheet(isPresented: $isShowingImportSheet) {
            importSheetContent
        }
        .sheet(isPresented: $isShowingNewCourseSheet) {
            newCourseSheet
        }
        .sheet(isPresented: $isShowingWhatsNew) {
            WhatsNewView(
                version: updateService.latestRelease?.version ?? updateService.currentVersion,
                releaseName: updateService.latestRelease?.name ?? "A calmer way to study",
                releaseNotes: updateService.latestRelease?.body ?? ""
            )
        }
        .alert("Update available", isPresented: $isShowingUpdatePrompt) {
            Button("Update now") { startUpdate() }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Syllabi \(updateService.latestRelease?.version ?? "") is ready. Would you like to download it now?")
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleGlobalDrop(providers: providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .importSyllabusNotification)) { _ in
            droppedFileURL = nil
            isShowingImportSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .newCourseNotification)) { _ in
            resetAndOpenNewCourse()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveSyllabusNotification)) { _ in
            if case .subject(let id) = selection, let sub = subjects.first(where: { $0.id == id }) {
                SyllabusShareHelper.saveSubjectToFile(sub)
            }
        }
        .onChange(of: selection) { _, _ in
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .task {
            if modelContext.undoManager == nil {
                modelContext.undoManager = UndoManager()
            }
            await updateService.checkForUpdates()
            if updateService.hasUpdate,
               let version = updateService.latestRelease?.version,
               lastPromptedUpdateVersion != version {
                lastPromptedUpdateVersion = version
                isShowingUpdatePrompt = true
            }
            if lastSeenWhatsNewVersion != updateService.currentVersion {
                lastSeenWhatsNewVersion = updateService.currentVersion
                isShowingWhatsNew = true
            }
        }
    }

    private func startUpdate() {
        isShowingUpdatePrompt = false
        Task { await updateService.downloadAndOpenLatestRelease() }
    }
    private func resetAndOpenNewCourse() {
        blankTitle = ""
        blankCode = ""
        blankTerm = ""
        blankIcon = "book.closed.fill"
        blankColorHex = "#3652FD"
        blankCustomIconData = nil
        isShowingNewCourseSheet = true
    }

    private func copyAIPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(PromptTemplate.aiFormatterPrompt, forType: .string)
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { showCopiedToast = false }
        }
    }

    // MARK: - Atmospheric Background

    private var ambientBackground: some View {
        GeometryReader { geo in
            ZStack {
                Color(nsColor: .windowBackgroundColor)

                // Ambient colorful gradients for Liquid Glass to blur
                Circle()
                    .fill(Color(red: 0.22, green: 0.32, blue: 0.99).opacity(0.04))
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .blur(radius: 90)
                    .offset(x: geo.size.width * 0.3, y: -geo.size.height * 0.2)

                Circle()
                    .fill(Color(red: 0.05, green: 0.65, blue: 0.85).opacity(0.03))
                    .frame(width: geo.size.width * 0.6, height: geo.size.width * 0.6)
                    .blur(radius: 80)
                    .offset(x: -geo.size.width * 0.2, y: geo.size.height * 0.3)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private var importSheetContent: some View {
        if let fileURL = droppedFileURL {
            ImportSyllabusSheet(
                initialMarkdown: (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "",
                onImportSuccess: { subject in
                    selection = .subject(subject.id)
                    droppedFileURL = nil
                }
            )
        } else {
            ImportSyllabusSheet(
                onImportSuccess: { subject in
                    selection = .subject(subject.id)
                }
            )
        }
    }

    private var newCourseSheet: some View {
        VStack(spacing: 16) {
            Text("Create New Course Notebook")
                .font(.system(size: 16, weight: .bold))

            Form {
                TextField("Course title:", text: $blankTitle)
                TextField("Course code (e.g. CS101):", text: $blankCode)
                TextField("Term / semester (e.g. Fall 2024):", text: $blankTerm)

                HStack {
                    TextField("SF Symbol icon (e.g. laptopcomputer):", text: $blankIcon)

                    Button("Custom Icon") {
                        uploadBlankIcon()
                    }
                    .buttonStyle(.liquidGlass)
                }

                if let data = blankCustomIconData, let img = NSImage(data: data) {
                    HStack(spacing: 8) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("Custom icon loaded")
                            .font(.system(size: 11))
                        Spacer()
                        Button("Remove") { blankCustomIconData = nil }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.red)
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Cover color & hex:")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)

                    NotebookColorPicker(selectedHex: $blankColorHex)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 10)

            HStack {
                Spacer()
                Button("Cancel") { isShowingNewCourseSheet = false }
                    .buttonStyle(.liquidGlass)

                Button("Create Notebook") {
                    createBlankCourse()
                }
                .buttonStyle(.liquidGlass(prominent: true))
                .disabled(blankTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 400)
    }

    private func uploadBlankIcon() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType.ico, UTType.png, UTType.jpeg, UTType.icns, UTType.image]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true

        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                Task {
                    do {
                        blankCustomIconData = try await IconProcessingService.transparentIconData(from: url)
                    } catch {
                        print("Error processing custom icon: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func createBlankCourse() {
        let title = blankTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        let newSubject = Subject(
            title: title,
            code: blankCode.trimmingCharacters(in: .whitespaces),
            term: blankTerm.trimmingCharacters(in: .whitespaces),
            icon: blankIcon.isEmpty ? "book.closed.fill" : blankIcon,
            colorHex: blankColorHex,
            customIconData: blankCustomIconData
        )
        let defaultUnit = SyllabusUnit(title: "Unit 1: Foundations", orderIndex: 0, subject: newSubject)
        newSubject.units.append(defaultUnit)

        modelContext.insert(newSubject)
        modelContext.insert(defaultUnit)
        try? modelContext.save()

        selection = .subject(newSubject.id)
        isShowingNewCourseSheet = false
    }

    private func handleGlobalDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url = url {
                DispatchQueue.main.async {
                    self.droppedFileURL = url
                    self.isShowingImportSheet = true
                }
            }
        }
        return true
    }
}
