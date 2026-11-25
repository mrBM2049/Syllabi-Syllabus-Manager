import CryptoKit
import XCTest
@testable import Syllabi

final class AppUpdateServiceTests: XCTestCase {
    @MainActor
    func testFourPartVersionWithVerifiableInstaller() async {
        let older = makeService(version: "1.0.2")
        await older.checkForUpdates()
        XCTAssertEqual(older.availableUpdate?.version, "1.0.2.2")
        XCTAssertNil(older.availableUpdate?.body)
        XCTAssertNil(older.errorMessage)

        let current = makeService(version: "1.0.2.2")
        await current.checkForUpdates()
        XCTAssertFalse(current.hasUpdate)
    }

    @MainActor
    func testMissingAssetAndHTTPFailuresHaveVisibleErrors() async {
        for repo in ["no-installer", "not-found", "rate-limited"] {
            let service = makeService(repo: repo)
            await service.checkForUpdates()
            XCTAssertFalse(service.hasUpdate, repo)
            XCTAssertNotNil(service.errorMessage, repo)
        }
    }

    @MainActor
    func testAutomaticInstallationRequiresEmbeddedKeyAndUploadedAppcast() async throws {
        let configured = makeService(repo: "signed", key: Data(repeating: 1, count: 32).base64EncodedString())
        await configured.checkForUpdates()
        let release = try XCTUnwrap(configured.availableUpdate)
        XCTAssertTrue(configured.canInstall(release))
        XCTAssertFalse(makeService().canInstall(release))

        let unsigned = makeService(key: Data(repeating: 1, count: 32).base64EncodedString())
        await unsigned.checkForUpdates()
        XCTAssertFalse(unsigned.canInstall(try XCTUnwrap(unsigned.availableUpdate)))
    }

    func testInstallerMustMatchTheExpectedSizeAndSHA256() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let bytes = Data("sample installer".utf8)
        let digest = "sha256:" + SHA256.hash(data: bytes).description.split(separator: " ").last!
        try bytes.write(to: url)
        let asset = AppUpdateService.Asset(name: "Syllabi.dmg", state: "uploaded", size: bytes.count, digest: digest)
        let valid = try await AppUpdateService.matchesAsset(at: url, asset: asset)
        XCTAssertTrue(valid)
        try Data(repeating: 0, count: bytes.count).write(to: url)
        let wrongHash = try await AppUpdateService.matchesAsset(at: url, asset: asset)
        XCTAssertFalse(wrongHash)
        try Data().write(to: url)
        let wrongSize = try await AppUpdateService.matchesAsset(at: url, asset: asset)
        XCTAssertFalse(wrongSize)
    }

    func testInstallerRedirectsRequireAnApprovedHTTPSHost() throws {
        let redirects = GitHubRedirects(hosts: ["github.com", "release-assets.githubusercontent.com"])
        XCTAssertTrue(redirects.allows(try XCTUnwrap(URL(string: "https://release-assets.githubusercontent.com/file"))))
        for url in ["http://github.com/file", "https://example.com/file", "https://github.com:8443/file",
                    "https://user@github.com/file"] {
            XCTAssertFalse(redirects.allows(try XCTUnwrap(URL(string: url))))
        }
    }

    @MainActor
    private func makeService(repo: String = "valid", version: String = "1.0.2", key: String? = nil) -> AppUpdateService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReleaseProtocol.self]
        var info = ["SyllabiGitHubRepository": "test/\(repo)", "CFBundleShortVersionString": version]
        info["SUPublicEDKey"] = key
        info["SUFeedURL"] = "https://github.com/test/\(repo)/releases/latest/download/appcast.xml"
        return AppUpdateService(info: info, session: URLSession(configuration: configuration))
    }
}

private final class ReleaseProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url, let client else { return }
        let statusCode = url.path.contains("/not-found/") ? 404 : url.path.contains("/rate-limited/") ? 429 : 200
        let digest = "sha256:" + String(repeating: "a", count: 64)
        var assets: [[String: Any]] = url.path.contains("/no-installer/") ? [] : [
            ["name": "Syllabi.dmg", "state": "uploaded", "size": 42, "digest": digest]
        ]
        if url.path.contains("/signed/") {
            assets.append(["name": "appcast.xml", "state": "uploaded", "size": 42])
        }
        let release: [String: Any] = ["tag_name": "v1.0.2.2", "name": NSNull(), "body": NSNull(), "assets": assets]
        guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil),
              let data = try? JSONSerialization.data(withJSONObject: release) else {
            client.urlProtocol(self, didFailWithError: URLError(.cannotParseResponse))
            return
        }
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: data)
        client.urlProtocolDidFinishLoading(self)
    }
}
