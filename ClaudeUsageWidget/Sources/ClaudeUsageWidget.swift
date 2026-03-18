import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct UsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(loadEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let entry = loadEntry() ?? .placeholder
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> UsageEntry? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.claudeusage.shared"
        ) else { return nil }

        let fileURL = containerURL.appendingPathComponent("widget-data.json")
        guard let data = try? Data(contentsOf: fileURL),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return nil
        }

        return UsageEntry(
            date: widgetData.lastUpdated,
            quota: widgetData.quota,
            todayMessages: widgetData.todayMessages,
            todaySessions: widgetData.todaySessions,
            todayToolCalls: widgetData.todayToolCalls,
            todayTokens: widgetData.todayTokens,
            modelBreakdowns: widgetData.modelBreakdowns,
            warningThreshold: widgetData.warningThreshold,
            isPlaceholder: false
        )
    }
}

// MARK: - Timeline Entry

struct UsageEntry: TimelineEntry {
    let date: Date
    let quota: QuotaData
    let todayMessages: Int
    let todaySessions: Int
    let todayToolCalls: Int
    let todayTokens: Int
    let modelBreakdowns: [WidgetModelBreakdown]
    let warningThreshold: Double
    let isPlaceholder: Bool

    static let placeholder = UsageEntry(
        date: Date(),
        quota: QuotaData(
            sessionPercent: 20, sessionResetTime: "2pm",
            weeklyAllPercent: 5, weeklyAllResetTime: "Mar 22",
            weeklySonnetPercent: 2, weeklySonnetResetTime: "Mar 23"
        ),
        todayMessages: 1234,
        todaySessions: 5,
        todayToolCalls: 189,
        todayTokens: 45230,
        modelBreakdowns: [
            WidgetModelBreakdown(name: "sonnet", displayName: "Sonnet", tokens: 63000, percentage: 63),
            WidgetModelBreakdown(name: "opus", displayName: "Opus", tokens: 25000, percentage: 25),
            WidgetModelBreakdown(name: "haiku", displayName: "Haiku", tokens: 12000, percentage: 12),
        ],
        warningThreshold: 80,
        isPlaceholder: true
    )
}

// MARK: - Widget Colors

enum WidgetColors {
    static let background = Color(red: 0.102, green: 0.102, blue: 0.180)
    static let surface = Color(red: 0.086, green: 0.129, blue: 0.243)
    static let primary = Color(red: 0.694, green: 0.725, blue: 0.976)
    static let accent = Color(red: 0.843, green: 0.467, blue: 0.341)
    static let text = Color(red: 0.878, green: 0.878, blue: 0.878)
    static let muted = Color(red: 0.533, green: 0.533, blue: 0.533)
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        let isWarning = Double(entry.quota.weeklyAllPercent) >= entry.warningThreshold

        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(WidgetColors.surface, lineWidth: 6)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: Double(entry.quota.weeklyAllPercent) / 100)
                    .stroke(
                        isWarning ? WidgetColors.accent : WidgetColors.primary,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                Text("\(entry.quota.weeklyAllPercent)%")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(WidgetColors.text)
            }
            Text("Weekly Quota")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(WidgetColors.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetGlassBackground()
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        HStack(spacing: 16) {
            // Quota bars
            VStack(alignment: .leading, spacing: 6) {
                quotaRow("Session", percent: entry.quota.sessionPercent, reset: entry.quota.sessionResetTime)
                quotaRow("Weekly", percent: entry.quota.weeklyAllPercent, reset: entry.quota.weeklyAllResetTime)
                quotaRow("Sonnet", percent: entry.quota.weeklySonnetPercent, reset: entry.quota.weeklySonnetResetTime)
            }
            .frame(maxWidth: .infinity)

            // Today stats
            VStack(alignment: .trailing, spacing: 4) {
                Text("Today")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(WidgetColors.text)
                statLine("msgs", value: entry.todayMessages)
                statLine("sessions", value: entry.todaySessions)
                statLine("tools", value: entry.todayToolCalls)
            }
            .frame(width: 90)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetGlassBackground()
    }

    private func quotaRow(_ label: String, percent: Int, reset: String) -> some View {
        let isWarning = Double(percent) >= entry.warningThreshold
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(WidgetColors.muted)
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(isWarning ? WidgetColors.accent : WidgetColors.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(WidgetColors.surface)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isWarning ? WidgetColors.accent : WidgetColors.primary)
                        .frame(width: max(0, geo.size.width * Double(percent) / 100))
                }
            }
            .frame(height: 5)
        }
    }

    private func statLine(_ label: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(WidgetColors.muted)
            Text(formatCompact(value))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(WidgetColors.text)
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "sparkle")
                    .foregroundColor(WidgetColors.accent)
                    .font(.system(size: 12))
                Text("Claude Usage")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(WidgetColors.text)
                Spacer()
            }

            divider

            // Quota
            quotaRow("Session", percent: entry.quota.sessionPercent, reset: entry.quota.sessionResetTime)
            quotaRow("Weekly (all)", percent: entry.quota.weeklyAllPercent, reset: entry.quota.weeklyAllResetTime)
            quotaRow("Weekly (Sonnet)", percent: entry.quota.weeklySonnetPercent, reset: entry.quota.weeklySonnetResetTime)

            divider

            // Today stats grid
            Text("Today")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(WidgetColors.text)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                statCell("Messages", value: entry.todayMessages)
                statCell("Sessions", value: entry.todaySessions)
                statCell("Tool Calls", value: entry.todayToolCalls)
                statCell("Tokens", value: entry.todayTokens)
            }

            divider

            // Model distribution
            if !entry.modelBreakdowns.isEmpty {
                Text("Models")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(WidgetColors.text)

                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(entry.modelBreakdowns) { model in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorForModel(model.displayName))
                                .frame(width: max(2, geo.size.width * model.percentage / 100))
                        }
                    }
                }
                .frame(height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 3))

                HStack(spacing: 8) {
                    ForEach(entry.modelBreakdowns) { model in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(colorForModel(model.displayName))
                                .frame(width: 6, height: 6)
                            Text("\(model.displayName) \(Int(model.percentage))%")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(WidgetColors.muted)
                        }
                    }
                }
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetGlassBackground()
    }

    private var divider: some View {
        Text(String(repeating: "─", count: 40))
            .font(.system(size: 8, design: .monospaced))
            .foregroundColor(WidgetColors.muted)
            .lineLimit(1)
    }

    private func quotaRow(_ label: String, percent: Int, reset: String) -> some View {
        let isWarning = Double(percent) >= entry.warningThreshold
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(WidgetColors.muted)
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isWarning ? WidgetColors.accent : WidgetColors.text)
                Text("· \(reset)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(WidgetColors.muted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(WidgetColors.surface)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isWarning ? WidgetColors.accent : WidgetColors.primary)
                        .frame(width: max(0, geo.size.width * Double(percent) / 100))
                }
            }
            .frame(height: 6)
        }
    }

    private func statCell(_ label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(WidgetColors.muted)
            Spacer()
            Text(formatCompact(value))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(WidgetColors.text)
        }
    }

    private func colorForModel(_ name: String) -> Color {
        switch name {
        case "Opus": return WidgetColors.primary
        case "Sonnet": return WidgetColors.accent
        case "Haiku": return Color(red: 0.298, green: 0.686, blue: 0.314)
        default: return WidgetColors.muted
        }
    }
}

// MARK: - Widget Definition

struct ClaudeUsageWidget: Widget {
    let kind = "ClaudeUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Claude Usage")
        .description("Monitor your Claude Code usage and quota")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: UsageEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Helpers

private func formatCompact(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
    return "\(n)"
}

// MARK: - Shared Models (duplicated for widget target)

struct QuotaData: Codable, Equatable {
    var sessionPercent: Int
    var sessionResetTime: String
    var weeklyAllPercent: Int
    var weeklyAllResetTime: String
    var weeklySonnetPercent: Int
    var weeklySonnetResetTime: String
}

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

// MARK: - Glass Background Helper

extension View {
    @ViewBuilder
    func widgetGlassBackground() -> some View {
        if #available(macOS 26, *) {
            self.containerBackground(for: .widget) {
                Color.clear // system applies Liquid Glass automatically on macOS 26
            }
        } else {
            self.containerBackground(WidgetColors.background, for: .widget)
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    ClaudeUsageWidget()
} timeline: {
    UsageEntry.placeholder
}

#Preview(as: .systemMedium) {
    ClaudeUsageWidget()
} timeline: {
    UsageEntry.placeholder
}

#Preview(as: .systemLarge) {
    ClaudeUsageWidget()
} timeline: {
    UsageEntry.placeholder
}
