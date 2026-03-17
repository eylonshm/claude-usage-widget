import Foundation
import Combine
import WidgetKit

@MainActor
final class UsageDataService: ObservableObject {
    static let shared = UsageDataService()

    // Published state
    @Published var quota: QuotaData = .empty
    @Published var statsCache: StatsCache?
    @Published var todayStats: PeriodStats = PeriodStats()
    @Published var weekStats: PeriodStats = PeriodStats()
    @Published var monthStats: PeriodStats = PeriodStats()
    @Published var modelBreakdowns: [ModelBreakdown] = []
    @Published var lastUpdated: Date?
    @Published var isRefreshing: Bool = true  // true from launch so the menu bar shows loading immediately
    @Published var hasLoadedOnce: Bool = false
    @Published var quotaError: String?
    @Published var statsError: String?
    @Published var permissionDenied: Bool = false

    private let statsFetcher = StatsFetcher()
    private let quotaFetcher = QuotaFetcher()
    private var refreshTimer: Timer?
    private var sessionResetTimer: Timer?
    private var refreshInProgress = false
    private let settings = AppSettings.shared

    // Parsed reset date exposed to views for the countdown banner
    var sessionResetDate: Date? { parseSessionResetDate(quota.sessionResetTime) }

    private init() {
        startTimer()
    }

    // MARK: - Refresh

    func refresh() async {
        guard !refreshInProgress else { return }
        refreshInProgress = true
        isRefreshing = true

        async let statsResult: Void = fetchStats()
        async let quotaResult: Void = fetchQuota()

        await statsResult
        await quotaResult

        lastUpdated = Date()
        isRefreshing = false
        hasLoadedOnce = true
        refreshInProgress = false

        writeWidgetData()
        WidgetCenter.shared.reloadAllTimelines()
        scheduleSessionResetRefresh()
    }

    private func fetchStats() async {
        do {
            let cache = try await statsFetcher.fetch()
            self.statsCache = cache
            self.todayStats = statsFetcher.computeToday(from: cache)
            self.weekStats = statsFetcher.computeThisWeek(from: cache)
            self.monthStats = statsFetcher.computeThisMonth(from: cache)
            self.modelBreakdowns = statsFetcher.computeModelBreakdowns(from: cache)
            self.statsError = nil
            self.permissionDenied = false
        } catch FetchError.permissionDenied {
            self.permissionDenied = true
            self.statsError = nil
        } catch {
            self.statsError = error.localizedDescription
        }
    }

    private func fetchQuota() async {
        let logFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude-usage-debug.log")
        func log(_ msg: String) {
            let line = "[\(Date())] \(msg)\n"
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFile.path) {
                    if let fh = try? FileHandle(forWritingTo: logFile) {
                        fh.seekToEndOfFile()
                        fh.write(data)
                        fh.closeFile()
                    }
                } else {
                    try? data.write(to: logFile)
                }
            }
        }

        log("Starting quota fetch...")
        do {
            let quotaData = try await quotaFetcher.fetch()
            self.quota = quotaData
            self.quotaError = nil
            log("OK: session=\(quotaData.sessionPercent)% weekly=\(quotaData.weeklyAllPercent)% sonnet=\(quotaData.weeklySonnetPercent)%")
        } catch {
            self.quotaError = error.localizedDescription
            log("ERROR: \(error)")
        }
    }

    // MARK: - Timer

    func startTimer() {
        refreshTimer?.invalidate()
        let interval = TimeInterval(settings.refreshInterval * 60)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    func restartTimer() {
        startTimer()
    }

    // MARK: - Session Reset Auto-Refresh

    private func scheduleSessionResetRefresh() {
        sessionResetTimer?.invalidate()
        sessionResetTimer = nil

        guard let resetDate = parseSessionResetDate(quota.sessionResetTime) else { return }
        // Fire 5s after the reset to let the new session fully register
        let fireDate = resetDate.addingTimeInterval(5)
        guard fireDate > Date() else { return }

        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sessionResetTimer = nil
                await self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        sessionResetTimer = timer
    }

    func parseSessionResetDate(_ raw: String) -> Date? {
        guard raw != "—", !raw.isEmpty else { return nil }

        var tz = TimeZone.current
        if let open = raw.range(of: "("), let close = raw.range(of: ")") {
            let tzId = String(raw[raw.index(after: open.lowerBound)..<close.lowerBound])
            tz = TimeZone(identifier: tzId) ?? .current
        }

        var cal = Calendar.current
        cal.timeZone = tz

        let stripped = raw.components(separatedBy: "(").first?
            .trimmingCharacters(in: .whitespaces) ?? raw

        let monthMap = ["jan":1,"feb":2,"mar":3,"apr":4,"may":5,"jun":6,
                        "jul":7,"aug":8,"sep":9,"oct":10,"nov":11,"dec":12]

        // Format: "Mar 22 at 11pm"
        let withDate = try? NSRegularExpression(
            pattern: #"([A-Za-z]+)\s+(\d+)\s+at\s+(\d+)(?::(\d+))?\s*(am|pm)"#,
            options: .caseInsensitive)
        if let m = withDate?.firstMatch(in: stripped, range: NSRange(stripped.startIndex..., in: stripped)) {
            let g = { (i: Int) -> String in String(stripped[Range(m.range(at: i), in: stripped)!]) }
            guard let month = monthMap[g(1).lowercased()] else { return nil }
            let day = Int(g(2)) ?? 1
            var hour = Int(g(3)) ?? 0
            let min = m.range(at: 4).length > 0 ? (Int(g(4)) ?? 0) : 0
            let ampm = g(5).lowercased()
            if ampm == "pm" && hour != 12 { hour += 12 }
            if ampm == "am" && hour == 12 { hour = 0 }
            var comps = DateComponents()
            comps.year = cal.component(.year, from: Date())
            comps.month = month; comps.day = day
            comps.hour = hour; comps.minute = min; comps.second = 0
            comps.timeZone = tz
            if let date = cal.date(from: comps) {
                if date < Date() { comps.year! += 1; return cal.date(from: comps) }
                return date
            }
        }

        // Format: "2pm" (time only — today or tomorrow)
        let timeOnly = try? NSRegularExpression(
            pattern: #"(\d+)(?::(\d+))?\s*(am|pm)"#,
            options: .caseInsensitive)
        if let m = timeOnly?.firstMatch(in: stripped, range: NSRange(stripped.startIndex..., in: stripped)) {
            let g = { (i: Int) -> String in String(stripped[Range(m.range(at: i), in: stripped)!]) }
            var hour = Int(g(1)) ?? 0
            let min = m.range(at: 2).length > 0 ? (Int(g(2)) ?? 0) : 0
            let ampm = g(3).lowercased()
            if ampm == "pm" && hour != 12 { hour += 12 }
            if ampm == "am" && hour == 12 { hour = 0 }
            var comps = cal.dateComponents([.year, .month, .day], from: Date())
            comps.hour = hour; comps.minute = min; comps.second = 0
            comps.timeZone = tz
            if let date = cal.date(from: comps) {
                return date < Date() ? cal.date(byAdding: .day, value: 1, to: date) : date
            }
        }

        return nil
    }

    // MARK: - Widget Data Sharing

    private func writeWidgetData() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier
        ) else { return }

        let widgetBreakdowns = modelBreakdowns.map {
            WidgetModelBreakdown(name: $0.name, displayName: $0.displayName, tokens: $0.tokens, percentage: $0.percentage)
        }

        let data = WidgetData(
            quota: quota,
            todayMessages: todayStats.messages,
            todaySessions: todayStats.sessions,
            todayToolCalls: todayStats.toolCalls,
            todayTokens: todayStats.tokens,
            modelBreakdowns: widgetBreakdowns,
            lastUpdated: Date(),
            warningThreshold: settings.warningThreshold
        )

        let fileURL = containerURL.appendingPathComponent(AppConstants.widgetDataFilename)
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: fileURL)
        }
    }
}
