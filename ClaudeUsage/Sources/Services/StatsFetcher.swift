import Foundation

final class StatsFetcher {
    private let fileManager = FileManager.default

    func fetch() async throws -> StatsCache {
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let statsPath = homeDir.appendingPathComponent(".claude/stats-cache.json")

        guard fileManager.fileExists(atPath: statsPath.path) else {
            throw FetchError.fileNotFound
        }

        do {
            let data = try Data(contentsOf: statsPath)
            let decoder = JSONDecoder()
            return try decoder.decode(StatsCache.self, from: data)
        } catch let error as NSError
            where error.code == NSFileReadNoPermissionError
               || (error.domain == NSPOSIXErrorDomain && (error.code == Int(EACCES) || error.code == Int(EPERM))) {
            throw FetchError.permissionDenied
        }
    }

    func computeToday(from cache: StatsCache) -> PeriodStats {
        let todayStr = Self.dateString(for: Date())
        return aggregateActivity(from: cache, matching: { $0.date == todayStr })
    }

    func computeThisWeek(from cache: StatsCache) -> PeriodStats {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return PeriodStats()
        }
        let weekStartStr = Self.dateString(for: weekStart)
        let todayStr = Self.dateString(for: now)
        return aggregateActivity(from: cache, matching: { $0.date >= weekStartStr && $0.date <= todayStr })
    }

    func computeThisMonth(from cache: StatsCache) -> PeriodStats {
        let prefix = String(Self.dateString(for: Date()).prefix(7)) // "YYYY-MM"
        return aggregateActivity(from: cache, matching: { $0.date.hasPrefix(prefix) })
    }

    func computeModelBreakdowns(from cache: StatsCache) -> [ModelBreakdown] {
        let totalTokens = cache.modelUsage.values.reduce(0) {
            $0 + $1.inputTokens + $1.outputTokens
        }
        guard totalTokens > 0 else { return [] }

        return cache.modelUsage
            .sorted { $0.key.modelSortOrder < $1.key.modelSortOrder }
            .map { key, usage in
                let tokens = usage.inputTokens + usage.outputTokens
                return ModelBreakdown(
                    name: key,
                    displayName: key.cleanModelName,
                    tokens: tokens,
                    percentage: Double(tokens) / Double(totalTokens) * 100
                )
            }
    }

    // MARK: - Helpers

    private func aggregateActivity(from cache: StatsCache, matching predicate: (DailyActivity) -> Bool) -> PeriodStats {
        let activities = cache.dailyActivity.filter(predicate)
        let dates = Set(activities.map(\.date))
        let tokenDays = cache.dailyModelTokens.filter { dates.contains($0.date) }
        let totalTokens = tokenDays.reduce(0) { sum, day in
            sum + day.tokensByModel.values.reduce(0, +)
        }

        return PeriodStats(
            messages: activities.reduce(0) { $0 + $1.messageCount },
            sessions: activities.reduce(0) { $0 + $1.sessionCount },
            toolCalls: activities.reduce(0) { $0 + $1.toolCallCount },
            tokens: totalTokens
        )
    }

    static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum FetchError: LocalizedError {
    case fileNotFound
    case cliNotFound
    case notAuthenticated
    case parseFailed(String)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Claude CLI not detected. Install Claude Code and run it once."
        case .cliNotFound:
            return "Claude CLI not found. Install from https://claude.ai/code"
        case .notAuthenticated:
            return "Not logged in — run `claude` to authenticate."
        case .parseFailed(let detail):
            return "Failed to parse usage data: \(detail)"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}
