import Foundation
import AppKit
import Combine

/// GitHub Releases based update discovery and download helper.
/// Set SyllabiGitHubRepository in Info.plist to `owner/repository` before publishing.
@MainActor
public final class AppUpdateService: ObservableObject {
    public struct Release: Codable, Identifiable, Equatable {
        public let tagName: String
        public let name: String
        public let body: String
        public let htmlURL: URL
        public let assets: [Asset]

        public var id: String { tagName }
        public var version: String { tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV")) }
        public var dmgAsset: Asset? { assets.first { $0.name.lowercased().hasSuffix(".dmg") } }

        enum CodingKeys: String, CodingKey { case tagName = "tag_name", name, body, htmlURL = "html_url", assets }
    }

    public struct Asset: Codable, Equatable {
        public let name: String
        public let browserDownloadURL: URL
        enum CodingKeys: String, CodingKey { case name, browserDownloadURL = "browser_download_url" }
    }

    @Published public private(set) var latestRelease: Release?
    @Published public private(set) var isChecking = false
    @Published public private(set) var isDownloading = false
    @Published public private(set) var errorMessage: String?

    public let repository: String
    public let currentVersion: String

    public init(info: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        repository = (info["SyllabiGitHubRepository"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        currentVersion = (info["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    public var hasUpdate: Bool {
        guard let latestRelease else { return false }
        return compare(latestRelease.version, currentVersion) == .orderedDescending
    }

    public func checkForUpdates() async {
        guard !repository.isEmpty, !repository.contains("YOUR_") else { return }
        isChecking = true
        errorMessage = nil
        defer { isChecking = false }

        do {
            let endpoint = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
            var request = URLRequest(url: endpoint)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Syllabi/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            latestRelease = try JSONDecoder().decode(Release.self, from: data)
        } catch {
            errorMessage = "Could not check for updates."
        }
    }

    public func downloadAndOpenLatestRelease() async {
        guard let url = latestRelease?.dmgAsset?.browserDownloadURL else {
            if let url = latestRelease?.htmlURL { NSWorkspace.shared.open(url) }
            return
        }
        isDownloading = true
        defer { isDownloading = false }
        do {
            let (temporaryURL, _) = try await URLSession.shared.download(from: url)
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent("Syllabi-Update.dmg")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            NSWorkspace.shared.open(destination)
        } catch {
            errorMessage = "The update could not be downloaded."
        }
    }

    private func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}
