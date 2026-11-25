import Foundation

enum SyllabusFile {
    static let maximumBytes = 1024 * 1024

    enum ReadError: LocalizedError {
        case invalidFile, tooLarge, invalidEncoding, noTopics

        var errorDescription: String? {
            switch self {
            case .invalidFile: return "Choose a local Markdown file."
            case .tooLarge: return "Choose a syllabus no larger than 1 MB."
            case .invalidEncoding: return "Save the syllabus as UTF-8 Markdown and try again."
            case .noTopics: return "The syllabus has no topics. Add a Markdown list of topics and try again."
            }
        }
    }

    static func read(_ url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard url.isFileURL, try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw ReadError.invalidFile
        }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var data = Data()
        while let chunk = try file.read(upToCount: maximumBytes + 1 - data.count), !chunk.isEmpty {
            data.append(chunk)
            guard data.count <= maximumBytes else { throw ReadError.tooLarge }
        }
        guard let text = String(data: data, encoding: .utf8) else { throw ReadError.invalidEncoding }
        return text
    }
}
