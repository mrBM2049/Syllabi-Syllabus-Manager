import AppKit
import Sparkle

@MainActor
final class SparkleUpdateInstaller: NSObject, SPUUpdaterDelegate {
    static let shared = SparkleUpdateInstaller()
    private let driver = UpdateUserDriver(hostBundle: .main, delegate: nil)
    private lazy var updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)
    private var started = false
    private var completion: (() -> Void)?

    var isAwaitingInstallConsent: Bool { driver.isAwaitingInstallConsent }

    func download(version: String, saveBeforeInstalling: @escaping () throws -> Void,
                  completion: @escaping () -> Void) throws {
        if !started {
            try updater.start()
            started = true
        }
        guard updater.canCheckForUpdates, self.completion == nil else {
            throw CocoaError(.userCancelled)
        }
        self.completion = completion
        driver.version = version
        driver.saveBeforeInstalling = saveBeforeInstalling
        updater.checkForUpdates()
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        driver.version = nil
        driver.saveBeforeInstalling = nil
        driver.isAwaitingInstallConsent = false
        let completed = completion
        completion = nil
        completed?()
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem,
                 updateCheck: SPUUpdateCheck) throws {
        guard let version = driver.version, item.displayVersionString == version, !item.isInformationOnlyUpdate else {
            throw NSError(domain: "Syllabi.Update", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "This release changed. Check for updates again before downloading."
            ])
        }
    }
}

@MainActor
private final class UpdateUserDriver: SPUStandardUserDriver {
    var version: String?
    var saveBeforeInstalling: (() throws -> Void)?
    var isAwaitingInstallConsent = false

    override func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState,
                                  reply: @escaping (SPUUserUpdateChoice) -> Void) {
        switch state.stage {
        case .notDownloaded, .downloaded:
            reply(.install)
        case .installing:
            isAwaitingInstallConsent = true
            reply(confirmInstallation())
        @unknown default:
            reply(.dismiss)
        }
    }

    override func showDownloadDidStartExtractingUpdate() {
        isAwaitingInstallConsent = true
        super.showDownloadDidStartExtractingUpdate()
    }

    override func showReadyToInstallAndRelaunch() async -> SPUUserUpdateChoice {
        confirmInstallation()
    }

    private func confirmInstallation() -> SPUUserUpdateChoice {
        guard let version, let saveBeforeInstalling else { return .skip }
        let alert = NSAlert()
        alert.messageText = "Install Syllabi \(version)?"
        alert.informativeText = "The update is ready. Syllabi will save your changes, quit, install the update, and reopen."
        alert.addButton(withTitle: "Install and Relaunch")
        alert.addButton(withTitle: "Not now").keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else {
            return .skip
        }

        do {
            try saveBeforeInstalling()
            isAwaitingInstallConsent = false
            return .install
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
            Task { @MainActor in
                let saveAlert = NSAlert()
                saveAlert.messageText = "Syllabi couldn’t prepare to quit"
                saveAlert.informativeText = message ?? "Your changes couldn’t be saved. Resolve the save issue and try again."
                saveAlert.runModal()
            }
            return .skip
        }
    }
}
