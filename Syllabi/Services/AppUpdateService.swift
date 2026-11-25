import Foundation
import AppKit
import Combine
import CryptoKit

/// GitHub Releases based update discovery and download helper.
/// Set SyllabiGitHubRepository in Info.plist to `owner/repository` before publishing.
@MainActor
public final class AppUpdateService: ObservableObject {
    public struct Release: Codable, Identifiable, Equatable {
        public let tagName: String
        public let name: String?
        public let body: String?
        public let assets: [Asset]

        public var id: String { tagName }
        public var version: String { tagName.hasPrefix("v") || tagName.hasPrefix("V") ? String(tagName.dropFirst()) : tagName }

        enum CodingKeys: String, CodingKey { case tagName = "tag_name", name, body, assets }
    }

    public struct Asset: Codable, Equatable {
        public let name: String
        public let state: String
        public let size: Int
        public let digest: String?
    }

    @Published public private(set) var latestRelease: Release?
    @Published public private(set) var isChecking = false
    @Published public private(set) var isDownloading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var lastCheckedAt: Date?

    public let repository: String
    public let currentVersion: String
    private let session: URLSession
    private let hasInstallerConfiguration: Bool
    private static let installerName = "Syllabi.dmg"
    nonisolated private static let maximumInstallerSize = 128 * 1024 * 1024

    public init(info: [String: Any] = Bundle.main.infoDictionary ?? [:], session: URLSession = .shared) {
        repository = (info["SyllabiGitHubRepository"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        currentVersion = (info["CFBundleShortVersionString"] as? String) ?? "1.0"
        let publicKey = (info["SUPublicEDKey"] as? String).flatMap { Data(base64Encoded: $0) }
        hasInstallerConfiguration = publicKey?.count == 32 && info["SUFeedURL"] is String
        self.session = session
    }

    public var hasUpdate: Bool { availableUpdate != nil }

    func canInstall(_ release: Release) -> Bool {
        hasInstallerConfiguration && release.assets.contains { $0.name == "appcast.xml" && $0.state == "uploaded" }
    }

    var availableUpdate: Release? {
        guard let latestRelease, isNewer(latestRelease), verifiedAsset(for: latestRelease) != nil else { return nil }
        return latestRelease
    }

    public func checkForUpdates(force: Bool = false) async {
        guard !isChecking, !isDownloading else { return }
        if !force, let lastCheckedAt, Date().timeIntervalSince(lastCheckedAt) < 15 * 60 { return }
        guard repository.range(of: #"\A[A-Za-z0-9_-]+/[A-Za-z0-9_-][A-Za-z0-9_.-]*\z"#, options: .regularExpression) != nil,
              let endpoint = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            errorMessage = "The update source is missing or invalid."
            return
        }
        isChecking = true
        errorMessage = nil
        defer {
            lastCheckedAt = Date()
            isChecking = false
        }

        do {
            var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Syllabi/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            let redirects = GitHubRedirects(hosts: ["api.github.com"])
            let (data, response) = try await session.data(for: request, delegate: redirects)
            guard let http = response as? HTTPURLResponse, let responseURL = http.url,
                  redirects.allows(responseURL) else { throw URLError(.badServerResponse) }
            switch http.statusCode {
            case 200:
                let release = try JSONDecoder().decode(Release.self, from: data)
                guard Self.versionParts(release.version) != nil else { throw URLError(.cannotParseResponse) }
                latestRelease = release
                if isNewer(release), verifiedAsset(for: release) == nil {
                    errorMessage = "Syllabi \(release.version) has no verifiable installer yet. Check again later."
                }
            case 403, 429:
                errorMessage = "GitHub limited update checks. Try again later."
            case 404:
                latestRelease = nil
                errorMessage = "GitHub couldn’t find a public release for Syllabi."
            default:
                throw URLError(.badServerResponse)
            }
        } catch {
            if !Task.isCancelled {
                errorMessage = "Couldn’t check for updates. Check your connection and try again."
            }
        }
    }

    func downloadUpdate(expectedTag: String, saveBeforeInstalling: @escaping () throws -> Void) async {
        guard !isDownloading, !isChecking, let release = availableUpdate,
              release.tagName == expectedTag,
              let asset = verifiedAsset(for: release),
              let url = URL(string: "https://github.com/\(repository)/releases/download/\(release.tagName)/\(asset.name)") else { return }

        isDownloading = true
        errorMessage = nil
        if canInstall(release) {
            do {
                try SparkleUpdateInstaller.shared.download(version: release.version, saveBeforeInstalling: saveBeforeInstalling) { [weak self] in
                    self?.isDownloading = false
                }
            } catch {
                isDownloading = false
                errorMessage = "Couldn’t start the installer. Check for updates and try again."
            }
            return
        }
        defer { isDownloading = false }
        do {
            let redirects = GitHubRedirects(hosts: ["github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"])
            let (temporaryURL, response) = try await session.download(
                for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60),
                delegate: redirects
            )
            defer { try? FileManager.default.removeItem(at: temporaryURL) }
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let responseURL = response.url, redirects.allows(responseURL) else {
                throw URLError(.badServerResponse)
            }
            guard try await Self.matchesAsset(at: temporaryURL, asset: asset) else {
                errorMessage = "The installer couldn’t be verified. Check for updates again before retrying."
                return
            }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let destination = directory.appendingPathComponent(Self.installerName)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                    attributes: [.posixPermissions: 0o700])
            do {
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
                // Preserve Gatekeeper evaluation when handing off a network download.
                try (destination as NSURL).setResourceValue(
                    [kLSQuarantineTypeKey as String: kLSQuarantineTypeOtherDownload as String,
                     kLSQuarantineOriginURLKey as String: url] as NSDictionary,
                    forKey: .quarantinePropertiesKey
                )
                guard NSWorkspace.shared.open(destination) else { throw URLError(.cannotOpenFile) }
            } catch {
                try? FileManager.default.removeItem(at: directory)
                throw error
            }
        } catch {
            errorMessage = "Couldn’t download or open the installer. Try again."
        }
    }

    private func verifiedAsset(for release: Release) -> Asset? {
        release.assets.first {
            $0.name == Self.installerName && $0.state == "uploaded" &&
            (1...Self.maximumInstallerSize).contains($0.size) &&
            $0.digest?.range(of: #"\Asha256:[a-f0-9]{64}\z"#, options: .regularExpression) != nil
        }
    }

    nonisolated static func matchesAsset(at url: URL, asset: Asset) async throws -> Bool {
        guard try url.resourceValues(forKeys: [.fileSizeKey]).fileSize == asset.size,
              (1...maximumInstallerSize).contains(asset.size) else { return false }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hash = SHA256()
        while let chunk = try file.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            hash.update(data: chunk)
        }
        return asset.digest == "sha256:\(hash.finalize().map { String(format: "%02x", $0) }.joined())"
    }

    private static func versionParts(_ version: String) -> [Int]? {
        let fields = version.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(fields.count), fields.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) else { return nil }
        let values = fields.compactMap { Int($0) }
        return values.count == fields.count ? values : nil
    }

    private func isNewer(_ release: Release) -> Bool {
        guard let left = Self.versionParts(release.version), let right = Self.versionParts(currentVersion) else { return false }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l > r }
        }
        return false
    }
}

final class GitHubRedirects: NSObject, URLSessionTaskDelegate {
    let hosts: Set<String>

    init(hosts: Set<String>) { self.hosts = hosts }

    func allows(_ url: URL) -> Bool {
        url.scheme == "https" && url.port == nil && url.user == nil && url.password == nil &&
        url.host.map(hosts.contains) == true
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.map(allows) == true ? request : nil)
    }
}
