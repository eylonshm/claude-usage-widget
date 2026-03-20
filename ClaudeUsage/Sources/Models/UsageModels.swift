import Foundation

// MARK: - Stats Cache Models (from ~/.claude/stats-cache.json)

struct StatsCache: Codable {
    let version: Int
    let lastComputedDate: String
    let dailyActivity: [DailyActivity]
    let dailyModelTokens: [DailyModelTokens]
    let modelUsage: [String: ModelUsage]
    let totalSessions: Int
    let totalMessages: Int
    let longestSession: LongestSession?
    let firstSessionDate: String?
    let hourCounts: [String: Int]?
}

struct DailyActivity: Codable {
    let date: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
}

struct DailyModelTokens: Codable {
    let date: String
    let tokensByModel: [String: Int]
}

struct ModelUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadInputTokens: Int
    let cacheCreationInputTokens: Int
}

struct LongestSession: Codable {
    let sessionId: String
    let duration: Int
    let messageCount: Int
    let timestamp: String
}

// MARK: - Quota Data (from /usage command)

struct QuotaData: Codable, Equatable {
    var sessionPercent: Int
    var sessionResetTime: String
    var weeklyAllPercent: Int
    var weeklyAllResetTime: String
    var weeklySonnetPercent: Int
    var weeklySonnetResetTime: String

    static let empty = QuotaData(
        sessionPercent: 0, sessionResetTime: "—",
        weeklyAllPercent: 0, weeklyAllResetTime: "—",
        weeklySonnetPercent: 0, weeklySonnetResetTime: "—"
    )
}

// MARK: - Derived Stats

struct PeriodStats {
    var messages: Int = 0
    var sessions: Int = 0
    var toolCalls: Int = 0
    var tokens: Int = 0
}

struct ModelBreakdown: Identifiable {
    let id = UUID()
    let name: String
    let displayName: String
    let tokens: Int
    let percentage: Double
}

// MARK: - Widget Shared Data

struct WidgetData: Codable {
    let quota: QuotaData
    let todayMessages: Int
    let todaySessions: Int
    let todayToolCalls: Int
    let todayTokens: Int
    let modelBreakdowns: [WidgetModelBreakdown]
    let lastUpdated: Date
    let warningThreshold: Double
}

struct WidgetModelBreakdown: Codable, Identifiable {
    var id: String { name }
    let name: String
    let displayName: String
    let tokens: Int
    let percentage: Double
}

// MARK: - App Group Constants

enum AppConstants {
    static let appGroupIdentifier = "group.com.claudeusage.shared"
    static let widgetBundleIdentifier = "com.claudeusage.app.widget"
    static let widgetDataFilename = "widget-data.json"
    static let widgetKind = "ClaudeUsageWidget"
}

// MARK: - Model Name Helpers

extension String {
    var cleanModelName: String {
        // Extract model family and version, e.g. "claude-sonnet-4-6" -> "Sonnet 4.6"
        let lower = self.lowercased()
        let family: String
        if lower.contains("opus") { family = "Opus" }
        else if lower.contains("sonnet") { family = "Sonnet" }
        else if lower.contains("haiku") { family = "Haiku" }
        else { return self }

        // Try to extract version like "4-6", "4-5" from the model ID
        // e.g. "claude-sonnet-4-6" or "claude-sonnet-4-5-20250929"
        if let range = lower.range(of: #"(\d+)-(\d+)"#, options: .regularExpression) {
            let version = String(lower[range]).replacingOccurrences(of: "-", with: ".")
            return "\(family) \(version)"
        }
        return family
    }

    var modelSortOrder: Int {
        if self.contains("opus") { return 0 }
        if self.contains("sonnet") { return 1 }
        if self.contains("haiku") { return 2 }
        return 3
    }
}
