import Foundation

public struct UsageRepository {
    public let cacheURL: URL

    public init(cacheURL: URL? = nil) {
        if let cacheURL {
            self.cacheURL = cacheURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
            self.cacheURL = support
                .appendingPathComponent("AgentBar", isDirectory: true)
                .appendingPathComponent("usage-cache.json")
        }
    }

    public func load() throws -> [DailyUsage] {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return []
        }

        let data = try Data(contentsOf: cacheURL)
        let envelope = try JSONDecoder().decode(CacheEnvelope.self, from: data)
        return envelope.days.sorted { $0.day < $1.day }
    }

    public func save(_ days: [DailyUsage]) throws {
        let parent = cacheURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        let envelope = CacheEnvelope(
            version: 1,
            updatedAt: Date(),
            days: compact(days)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        try data.write(to: cacheURL, options: .atomic)
    }

    public func mergeAndSave(_ incoming: [DailyUsage]) throws -> [DailyUsage] {
        let merged = UsageRepository.merge(existing: try load(), incoming: incoming)
        try save(merged)
        return merged
    }

    public static func merge(existing: [DailyUsage], incoming: [DailyUsage]) -> [DailyUsage] {
        var byDay = Dictionary(uniqueKeysWithValues: compact(existing).map { ($0.day, $0) })
        for day in compact(incoming) {
            byDay[day.day] = day
        }
        return byDay.values.sorted { $0.day < $1.day }
    }

    private static func compact(_ days: [DailyUsage]) -> [DailyUsage] {
        var byDay: [String: DailyUsage] = [:]
        for day in days {
            byDay[day.day] = (byDay[day.day] ?? DailyUsage(day: day.day)).merging(day)
        }
        return byDay.values.sorted { $0.day < $1.day }
    }

    private func compact(_ days: [DailyUsage]) -> [DailyUsage] {
        UsageRepository.compact(days)
    }
}

private struct CacheEnvelope: Codable {
    let version: Int
    let updatedAt: Date
    let days: [DailyUsage]
}
