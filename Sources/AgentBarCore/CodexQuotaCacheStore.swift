import Foundation

public struct CodexQuotaCacheRecord: Codable, Equatable, Sendable {
    public let snapshot: CodexQuotaSnapshot
    public let lastNetworkAttemptAt: Date?
    public let cachedAt: Date

    public init(
        snapshot: CodexQuotaSnapshot,
        lastNetworkAttemptAt: Date?,
        cachedAt: Date = Date()
    ) {
        self.snapshot = snapshot
        self.lastNetworkAttemptAt = lastNetworkAttemptAt
        self.cachedAt = cachedAt
    }
}

public struct CodexQuotaCacheStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
            self.fileURL = support
                .appendingPathComponent("AgentBar", isDirectory: true)
                .appendingPathComponent("codex-quota-cache.json")
        }
    }

    public func load() throws -> CodexQuotaCacheRecord? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(CodexQuotaCacheRecord.self, from: data)
    }

    public func save(_ record: CodexQuotaCacheRecord) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(record)
        try data.write(to: fileURL, options: .atomic)
    }
}
