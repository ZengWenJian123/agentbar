import XCTest
@testable import AgentBarCore

final class UsageRepositoryTests: XCTestCase {
    func testMergeReplacesIncomingDayAndPreservesExisting() {
        let existing = [
            DailyUsage(day: "2026-06-12", inputTokens: 100, costUSD: 1),
            DailyUsage(day: "2026-06-13", inputTokens: 100, costUSD: 1)
        ]
        let incoming = [
            DailyUsage(day: "2026-06-13", inputTokens: 300, outputTokens: 200, costUSD: 5)
        ]

        let merged = UsageRepository.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.first { $0.day == "2026-06-12" }?.totalTokens, 100)
        XCTAssertEqual(merged.first { $0.day == "2026-06-13" }?.totalTokens, 500)
        XCTAssertEqual(merged.first { $0.day == "2026-06-13" }?.costUSD, 5)
    }
}
