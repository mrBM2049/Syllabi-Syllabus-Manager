import SwiftUI
import EventKit
import SwiftData

public struct CalendarScheduleView: View {
    public var subjects: [Subject]
    public var onSelectSubject: (Subject) -> Void

    @StateObject private var calendarService = CalendarService.shared
    @State private var selectedDate: Date = Date()
    @State private var isShowingScheduleSheet = false
    @State private var selectedTopicToSchedule: (TopicItem, Subject)? = nil
    @State private var scheduleTime: Date = Date()
    @State private var scheduleDurationMinutes: Int = 45
    @State private var toastMessage: String? = nil
    @State private var selectedCourseFilter: UUID? = nil
    @State private var displayMode: CalendarDisplayMode = .day

    private enum CalendarDisplayMode: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"

        var id: String { rawValue }
    }

    public init(subjects: [Subject], onSelectSubject: @escaping (Subject) -> Void) {
        self.subjects = subjects
        self.onSelectSubject = onSelectSubject
    }

    private var allTopicsWithCourse: [(topic: TopicItem, subject: Subject)] {
        var list: [(topic: TopicItem, subject: Subject)] = []
        for s in subjects {
            if let filter = selectedCourseFilter, s.id != filter { continue }
            for u in s.sortedUnits {
                for t in u.topLevelTopics {
                    list.append((t, s))
                    for sub in t.sortedSubtopics {
                        list.append((sub, s))
                    }
                }
            }
        }
        return list
    }

    private var formattedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: selectedDate)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                // Header (Title & Mac Calendar Sync Status)
                headerSection

                // Responsive Two-Column Layout (Calendar Timeline + Task Scheduler)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 24) {
                        timelineCalendarCard
                            .frame(maxWidth: .infinity)

                        tasksSidebarCard
                            .frame(width: 320)
                    }

                    VStack(alignment: .leading, spacing: 24) {
                        timelineCalendarCard
                        tasksSidebarCard
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            calendarService.loadEvents(for: selectedDate)
        }
        .onChange(of: selectedDate) { _, newDate in
            calendarService.loadEvents(for: newDate)
        }
        .overlay(alignment: .top) {
            if let msg = toastMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThickMaterial, in: Capsule())
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $isShowingScheduleSheet) {
            scheduleModalSheet
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Study Calendar")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)

                CurvedAccentMark()
                    .frame(width: 80, height: 7)
            }

            Spacer()

            // Mac Calendar Connection Status Badge
            HStack(spacing: 8) {
                if calendarService.isAuthorized {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                        Text("Connected to Mac Calendar")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .liquidGlass(cornerRadius: 12)
                } else {
                    Button(action: {
                        Task {
                            let granted = await calendarService.requestAccess()
                            if granted {
                                calendarService.loadEvents(for: selectedDate)
                            }
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 11))
                            Text("Connect Mac Calendar")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                    }
                    .buttonStyle(.liquidGlass(prominent: true))
                }
            }
        }
    }

    // MARK: - Timeline Calendar Card (Matching Reference Widget)

    private var timelineCalendarCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Header with Date Switcher
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("Calendar")
                        .font(.system(size: 16, weight: .bold))
                }

                Spacer()

                Picker("Calendar view", selection: $displayMode) {
                    ForEach(CalendarDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)

                // Day Navigation (< Tuesday, June 15 >)
                HStack(spacing: 12) {
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)

                    DatePicker("Selected day", selection: $selectedDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(width: 150)

                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)

                    Button("Today") {
                        selectedDate = Date()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.liquidGlass)
                }
            }
            .padding(.horizontal, 4)

            Divider()

            calendarContent
        }
        .padding(18)
        .liquidGlass(cornerRadius: 18)
    }

    @ViewBuilder
    private var calendarContent: some View {
        switch displayMode {
        case .day:
            VStack(spacing: 0) {
                ForEach(7..<21, id: \.self) { hour in
                    timelineHourRow(hour: hour)
                }
            }
        case .week:
            weekCalendar
        case .month:
            monthCalendar
        case .year:
            yearCalendar
        }
    }

    private var weekCalendar: some View {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        return HStack(alignment: .top, spacing: 8) {
            ForEach(days, id: \.self) { day in
                Button {
                    selectedDate = day
                    displayMode = .day
                } label: {
                    VStack(spacing: 8) {
                        Text(day, format: .dateTime.weekday(.abbreviated))
                            .font(.caption.weight(.semibold))
                        Text(day, format: .dateTime.day())
                            .font(.title3.weight(.bold))
                        Circle()
                            .fill(calendar.isDate(day, inSameDayAs: selectedDate) ? SyllabiTheme.accent : .clear)
                            .frame(width: 7, height: 7)
                        Spacer(minLength: 60)
                    }
                    .foregroundStyle(calendar.isDate(day, inSameDayAs: selectedDate) ? SyllabiTheme.ink : SyllabiTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .padding(.vertical, 12)
                    .background(calendar.isDate(day, inSameDayAs: selectedDate) ? SyllabiTheme.lavender.opacity(0.32) : SyllabiTheme.surface.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var monthCalendar: some View {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: selectedDate) ?? DateInterval(start: selectedDate, duration: 0)
        let firstWeekday = calendar.component(.weekday, from: interval.start) - 1
        let days = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 0
        let cells = Array(repeating: Optional<Date>.none, count: firstWeekday) + (1...days).compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }.map(Optional.some)
        return VStack(alignment: .leading, spacing: 12) {
            Text(interval.start, format: .dateTime.month(.wide).year())
                .font(.title3.weight(.bold))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, weekday in
                    Text(weekday).font(.caption.weight(.semibold)).foregroundStyle(SyllabiTheme.secondaryText)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        Button {
                            selectedDate = date
                            displayMode = .day
                        } label: {
                            Text(date, format: .dateTime.day())
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .background(calendar.isDate(date, inSameDayAs: selectedDate) ? SyllabiTheme.accent : .clear, in: Circle())
                                .foregroundStyle(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.white : SyllabiTheme.ink)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(minHeight: 30)
                    }
                }
            }
        }
    }

    private var yearCalendar: some View {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedDate)
        return VStack(alignment: .leading, spacing: 12) {
            Text(String(year)).font(.largeTitle.weight(.bold))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(1...12, id: \.self) { month in
                    let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? selectedDate
                    Button {
                        selectedDate = date
                        displayMode = .month
                    } label: {
                        Text(date, format: .dateTime.month(.wide))
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(SyllabiTheme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SyllabiTheme.ink)
                }
            }
        }
    }

    private func timelineHourRow(hour: Int) -> some View {
        let matchingEvents = calendarService.dayEvents.filter { event in
            let eventHour = Calendar.current.component(.hour, from: event.startDate)
            return eventHour == hour
        }

        let hourLabel: String = {
            if hour == 12 { return "12 PM" }
            if hour > 12 { return "\(hour - 12) PM" }
            return "\(hour) AM"
        }()

        return HStack(alignment: .top, spacing: 14) {
            Text(hourLabel)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color.secondary.opacity(0.8))
                .frame(width: 48, alignment: .trailing)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                if matchingEvents.isEmpty {
                    // Empty hour slot line
                    Rectangle()
                        .fill(Color.secondary.opacity(0.08))
                        .frame(height: 1)
                        .padding(.vertical, 12)
                } else {
                    ForEach(matchingEvents, id: \.eventIdentifier) { event in
                        timelineEventBubble(event: event)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func timelineEventBubble(event: EKEvent) -> some View {
        let isStudyEvent = event.title.contains("[")
        let bubbleColor = isStudyEvent ? Color(red: 0.22, green: 0.32, blue: 0.99) : Color(red: 0.16, green: 0.68, blue: 0.44)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeRange = "\(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))"

        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(bubbleColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(timeRange)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: 11))
                .foregroundStyle(bubbleColor.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(bubbleColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(bubbleColor.opacity(0.25), lineWidth: 0.8)
        )
    }

    // MARK: - Tasks Scheduler Card (Matching Reference Widget)

    private var tasksSidebarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("Tasks & Topics")
                        .font(.system(size: 15, weight: .bold))
                }

                Spacer()

                Menu {
                    Button("All Courses") { selectedCourseFilter = nil }
                    Divider()
                    ForEach(subjects) { s in
                        Button(s.title) { selectedCourseFilter = s.id }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 10))
                        Text(selectedCourseTitle)
                            .font(.system(size: 11.5, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .frame(width: 158, height: 30, alignment: .leading)
                    .padding(.horizontal, 10)
                    .background(SyllabiTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(SyllabiTheme.ink.opacity(0.14), lineWidth: 0.8))
                }
                .menuStyle(.borderlessButton)
            }

            Divider()

            if allTopicsWithCourse.isEmpty {
                VStack(spacing: 8) {
                    Text("No tasks available")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(allTopicsWithCourse.prefix(35), id: \.topic.id) { item in
                            taskRowBubble(topic: item.topic, subject: item.subject)
                        }
                    }
                }
                .frame(maxHeight: 520)
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 18)
    }

    private var selectedCourseTitle: String {
        guard let selectedCourseFilter,
              let subject = subjects.first(where: { $0.id == selectedCourseFilter }) else {
            return "All Courses"
        }
        return subject.title
    }

    private func taskRowBubble(topic: TopicItem, subject: Subject) -> some View {
        HStack(spacing: 8) {
            // Checkbox (Expanded Hitbox & Save)
            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    topic.toggleCompletion()
                    try? topic.modelContext?.save()
                }
            }) {
                Image(systemName: topic.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(topic.isCompleted ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(topic.isCompleted ? "Mark task uncompleted" : "Mark task completed")

            // Topic Title
            VStack(alignment: .leading, spacing: 1) {
                Text(topic.title)
                    .font(.system(size: 12, weight: topic.isCompleted ? .regular : .medium))
                    .foregroundStyle(topic.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(topic.isCompleted, color: Color.secondary.opacity(0.4))
                    .lineLimit(1)

                Text(subject.code.isEmpty ? subject.title : subject.code)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: subject.colorHex))
            }

            Spacer(minLength: 4)

            // Status Pill Badge (Done, Pending, Due)
            statusPill(isCompleted: topic.isCompleted)

            // Schedule Button
            Button(action: {
                selectedTopicToSchedule = (topic, subject)
                scheduleTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: selectedDate) ?? Date()
                isShowingScheduleSheet = true
            }) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Schedule in Mac Calendar")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func statusPill(isCompleted: Bool) -> some View {
        Text(isCompleted ? "Done" : "Pending")
            .font(.system(size: 9.5, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(
                Capsule()
                    .fill(isCompleted ? Color.green.opacity(0.14) : Color.blue.opacity(0.12))
            )
            .foregroundStyle(isCompleted ? Color.green : Color.blue)
    }

    // MARK: - Schedule Modal Sheet

    private var scheduleModalSheet: some View {
        VStack(spacing: 16) {
            Text("Schedule Study in Mac Calendar")
                .font(.system(size: 15, weight: .bold))

            if let item = selectedTopicToSchedule {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.0.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text("Course: \(item.1.title)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                )
            }

            Form {
                DatePicker("Start Time:", selection: $scheduleTime)

                Picker("Duration:", selection: $scheduleDurationMinutes) {
                    Text("30 minutes").tag(30)
                    Text("45 minutes").tag(45)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                }
            }
            .padding(.horizontal, 10)

            HStack {
                Spacer()
                Button("Cancel") { isShowingScheduleSheet = false }
                    .buttonStyle(.liquidGlass)

                Button("Add to Mac Calendar") {
                    confirmScheduleEvent()
                }
                .buttonStyle(.liquidGlass(prominent: true))
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func confirmScheduleEvent() {
        guard let item = selectedTopicToSchedule else { return }

        Task {
            do {
                try await calendarService.scheduleStudyTask(
                    title: item.0.title,
                    courseName: item.1.code.isEmpty ? item.1.title : item.1.code,
                    notes: item.0.notes,
                    startDate: scheduleTime,
                    durationMinutes: scheduleDurationMinutes
                )

                await MainActor.run {
                    isShowingScheduleSheet = false
                    withAnimation {
                        toastMessage = "Event added to macOS Calendar!"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { toastMessage = nil }
                    }
                }
            } catch {
                print("Failed to schedule in Calendar: \(error)")
            }
        }
    }
}
