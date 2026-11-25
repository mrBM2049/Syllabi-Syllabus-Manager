import SwiftUI
import SwiftData
import AppKit

@main
struct SyllabiApp: App {
    @NSApplicationDelegateAdaptor(UpdateConsentAppDelegate.self) private var updateConsentDelegate
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Subject.self,
            SyllabusUnit.self,
            TopicItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 760, minHeight: 480)
                .tint(SyllabiTheme.accent)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Course Notebook...") {
                    NotificationCenter.default.post(name: .newCourseNotification, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Import Syllabus...") {
                    NotificationCenter.default.post(name: .importSyllabusNotification, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Open Syllabus File...") {
                    NotificationCenter.default.post(name: .importSyllabusNotification, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .importExport) {
                Button("Save Syllabus to Disk...") {
                    NotificationCenter.default.post(name: .saveSyllabusNotification, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
    }
}

private final class UpdateConsentAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Sparkle can install a staged update on quit. Keep normal quit behind the consent prompt.
        SparkleUpdateInstaller.shared.isAwaitingInstallConsent ? .terminateCancel : .terminateNow
    }
}

extension Notification.Name {
    static let importSyllabusNotification = Notification.Name("importSyllabusNotification")
    static let newCourseNotification = Notification.Name("newCourseNotification")
    static let saveSyllabusNotification = Notification.Name("saveSyllabusNotification")
}
