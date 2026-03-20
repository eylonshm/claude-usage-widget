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
        // Read from the widget's own Documents directory — always accessible within
        // the sandbox, no App Group provisioning required. The main app writes here.
        guard let containerURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return nil }

        let fileURL = containerURL.appendingPathComponent("widget-data.json")
        guard let data = try? Data(contentsOf: fileURL),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return nil
        }

        return UsageEntry(
            date: widgetData.lastUpdated,
            quota: widgetData.quota,
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
    let modelBreakdowns: [WidgetModelBreakdown]
    let warningThreshold: Double
    let isPlaceholder: Bool

    static let placeholder = UsageEntry(
        date: Date(),
        quota: QuotaData(
            sessionPercent: 0, sessionResetTime: "—",
            weeklyAllPercent: 0, weeklyAllResetTime: "—",
            weeklySonnetPercent: 0, weeklySonnetResetTime: "—"
        ),
        modelBreakdowns: [],
        warningThreshold: 80,
        isPlaceholder: true
    )
}

// MARK: - Adaptive Colors

private extension Color {
    static func widgetPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.694, green: 0.725, blue: 0.976)
            : Color(red: 0.25, green: 0.32, blue: 0.72)
    }

    static func widgetAccent(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.843, green: 0.467, blue: 0.341)
            : Color(red: 0.78, green: 0.35, blue: 0.18)
    }

    static func widgetSuccess(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.298, green: 0.686, blue: 0.314)
            : Color(red: 0.18, green: 0.56, blue: 0.22)
    }
}

// MARK: - Shared Sub-views

/// A quota row: label + percent on top, filled progress bar below, reset time inline
private struct QuotaRow: View {
    let label: String
    let percent: Int
    let reset: String
    let warningThreshold: Double
    @Environment(\.colorScheme) private var colorScheme

    private var isWarning: Bool { Double(percent) >= warningThreshold }

    private var barColor: Color {
        isWarning ? .widgetAccent(colorScheme) : .widgetPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isWarning ? .widgetAccent(colorScheme) : Color.primary)
                Text("· \(reset)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(2, geo.size.width * Double(percent) / 100))
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: UsageEntry
    @Environment(\.colorScheme) private var colorScheme

    private var isWarning: Bool { Double(entry.quota.sessionPercent) >= entry.warningThreshold }
    private var ringColor: Color {
        isWarning ? .widgetAccent(colorScheme) : .widgetPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 6)
                    .frame(width: 76, height: 76)
                Circle()
                    .trim(from: 0, to: Double(entry.quota.sessionPercent) / 100)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(-90))
                if entry.isPlaceholder {
                    Text("—")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 1) {
                        Text("\(entry.quota.sessionPercent)%")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                        Text("session")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if entry.isPlaceholder {
                Text("Loading…")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Text("Resets \(entry.quota.sessionResetTime)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Divider().opacity(0.4)

            HStack(spacing: 0) {
                VStack(spacing: 1) {
                    Text(entry.isPlaceholder ? "—" : "\(entry.quota.weeklyAllPercent)%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle((!entry.isPlaceholder && Double(entry.quota.weeklyAllPercent) >= entry.warningThreshold)
                            ? Color.widgetAccent(colorScheme) : Color.primary)
                    Text("weekly")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 24).opacity(0.4)

                VStack(spacing: 1) {
                    Text(entry.isPlaceholder ? "—" : "\(entry.quota.weeklySonnetPercent)%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle((!entry.isPlaceholder && Double(entry.quota.weeklySonnetPercent) >= entry.warningThreshold)
                            ? Color.widgetAccent(colorScheme) : Color.primary)
                    Text("sonnet")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetGlassBackground()
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Quota")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            QuotaRow(label: "Session",
                     percent: entry.quota.sessionPercent,
                     reset: entry.quota.sessionResetTime,
                     warningThreshold: entry.warningThreshold)
            QuotaRow(label: "Weekly (all)",
                     percent: entry.quota.weeklyAllPercent,
                     reset: entry.quota.weeklyAllResetTime,
                     warningThreshold: entry.warningThreshold)
            QuotaRow(label: "Weekly (Sonnet)",
                     percent: entry.quota.weeklySonnetPercent,
                     reset: entry.quota.weeklySonnetResetTime,
                     warningThreshold: entry.warningThreshold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetGlassBackground()
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: UsageEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Image(systemName: "sparkle")
                    .foregroundStyle(Color.widgetAccent(colorScheme))
                    .font(.system(size: 11))
                Text("Claude Usage")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            widgetDivider

            // Quota section
            Text("Quota")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 4)

            VStack(spacing: 7) {
                QuotaRow(label: "Session",
                         percent: entry.quota.sessionPercent,
                         reset: "Resets \(entry.quota.sessionResetTime)",
                         warningThreshold: entry.warningThreshold)
                QuotaRow(label: "Weekly (all models)",
                         percent: entry.quota.weeklyAllPercent,
                         reset: "Resets \(entry.quota.weeklyAllResetTime)",
                         warningThreshold: entry.warningThreshold)
                QuotaRow(label: "Weekly (Sonnet)",
                         percent: entry.quota.weeklySonnetPercent,
                         reset: "Resets \(entry.quota.weeklySonnetResetTime)",
                         warningThreshold: entry.warningThreshold)
            }
            .padding(.bottom, 8)

            // Model distribution
            if !entry.modelBreakdowns.isEmpty {
                widgetDivider

                Text("Models")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(entry.modelBreakdowns) { model in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorForModel(model.displayName))
                                .frame(width: max(2, geo.size.width * model.percentage / 100))
                        }
                    }
                }
                .frame(height: 7)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(.bottom, 4)

                HStack(spacing: 8) {
                    ForEach(entry.modelBreakdowns) { model in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(colorForModel(model.displayName))
                                .frame(width: 5, height: 5)
                            Text("\(model.displayName) \(Int(model.percentage))%")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetGlassBackground()
    }

    private var widgetDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
    }

    private func colorForModel(_ name: String) -> Color {
        switch name {
        case "Opus": return .widgetPrimary(colorScheme)
        case "Sonnet": return .widgetAccent(colorScheme)
        case "Haiku": return .widgetSuccess(colorScheme)
        default: return Color.secondary
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

private func widgetFormatCompact(_ n: Int) -> String {
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
            self.containerBackground(for: .widget) {
                Color(NSColor.windowBackgroundColor) // adapts to light/dark mode
            }
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
