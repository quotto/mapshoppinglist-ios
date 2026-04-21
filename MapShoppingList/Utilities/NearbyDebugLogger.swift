import Foundation

enum NearbyDebugCategory: String {
    case activity = "ACTIVITY"
    case categoryAPI = "CATEGORY_API"
    case placesAPI = "PLACES_API"
    case nearbyDecision = "NEARBY_DECISION"
}

enum NearbyDebugLogger {
    static let shared = NearbyDebugLogStore()

    static func log(
        _ category: NearbyDebugCategory,
        _ message: String,
        metadata: [String: String] = [:]
    ) {
        guard AppBuildFlags.isNearbyDebugLoggingEnabled else { return }
        Task {
            await shared.write(category: category, message: message, metadata: metadata)
        }
    }
}

actor NearbyDebugLogStore {
    private let dateFormatter: ISO8601DateFormatter
    private let fileDateFormatter: DateFormatter
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        fileDateFormatter = DateFormatter()
        fileDateFormatter.calendar = Calendar(identifier: .gregorian)
        fileDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        fileDateFormatter.dateFormat = "yyyy-MM-dd"
    }

    func write(
        category: NearbyDebugCategory,
        message: String,
        metadata: [String: String]
    ) {
        do {
            try prepareDirectoryIfNeeded()
            let logLine = makeLine(category: category, message: message, metadata: metadata)
            let data = Data(logLine.utf8)

            let url = logFileURL()
            if fileManager.fileExists(atPath: url.path) == false {
                try data.write(to: url, options: .atomic)
                return
            }

            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // ログ出力失敗でアプリ本体の動作を止めない
        }
    }
}

private extension NearbyDebugLogStore {
    func makeLine(
        category: NearbyDebugCategory,
        message: String,
        metadata: [String: String]
    ) -> String {
        let timestamp = dateFormatter.string(from: Date())
        let metadataText = metadata
            .sorted(by: { $0.key < $1.key })
            .map { key, value in "\(key)=\(sanitize(value))" }
            .joined(separator: " ")

        if metadataText.isEmpty {
            return "\(timestamp) [\(category.rawValue)] \(message)\n"
        }
        return "\(timestamp) [\(category.rawValue)] \(message) \(metadataText)\n"
    }

    func sanitize(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: "\\n")
    }

    func prepareDirectoryIfNeeded() throws {
        let directory = logsDirectoryURL()
        if fileManager.fileExists(atPath: directory.path) == false {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func logsDirectoryURL() -> URL {
        documentsDirectoryURL().appendingPathComponent("DebugLogs", isDirectory: true)
    }

    func logFileURL() -> URL {
        logsDirectoryURL().appendingPathComponent(
            "nearby-debug-\(fileDateFormatter.string(from: Date())).log"
        )
    }

    func documentsDirectoryURL() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ??
            fileManager.temporaryDirectory
    }
}

struct NearbyDebugLogFile: Identifiable, Equatable {
    let url: URL
    let size: Int64
    let modifiedAt: Date

    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

enum NearbyDebugLogFiles {
    static func list(fileManager: FileManager = .default) -> [NearbyDebugLogFile] {
        guard AppBuildFlags.isNearbyDebugLoggingEnabled else { return [] }
        let directory = logsDirectoryURL(fileManager: fileManager)
        guard let enumerated = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerated.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else {
                return nil
            }
            return NearbyDebugLogFile(
                url: url,
                size: Int64(values.fileSize ?? 0),
                modifiedAt: values.contentModificationDate ?? .distantPast
            )
        }
        .sorted(by: { $0.modifiedAt > $1.modifiedAt })
    }

    static func read(_ file: NearbyDebugLogFile) -> String {
        guard AppBuildFlags.isNearbyDebugLoggingEnabled else { return "" }
        return (try? String(contentsOf: file.url, encoding: .utf8)) ?? ""
    }

    private static func logsDirectoryURL(fileManager: FileManager) -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ??
            fileManager.temporaryDirectory
        return documentsURL.appendingPathComponent("DebugLogs", isDirectory: true)
    }
}
