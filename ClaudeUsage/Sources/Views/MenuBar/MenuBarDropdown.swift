import SwiftUI

struct MenuBarDropdown: View {
    @ObservedObject var service = UsageDataService.shared
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.openWindow) private var openWindow

    private var colors: ThemeColors { settings.colors }

    var body: some View {
        glassContainer {
            VStack(alignment: .leading, spacing: 10) {
                headerRow
                quotaCard
                statsCard
                if !service.modelBreakdowns.isEmpty {
                    modelCard
                }
                footerRow
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(panelBackground)
        .task {
            if service.lastUpdated == nil {
                await service.refresh()
            }
        }
    }

    // MARK: - Glass Container wrapper

    @ViewBuilder
    private func glassContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 8) {
                content()
            }
        } else {
            content()
        }
    }

    @ViewBuilder
    private var panelBackground: some View {
        if #available(macOS 26, *) {
            Color.clear // macOS 26 popover gets glass automatically
        } else {
            colors.background
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(colors.accent)
                .font(.system(size: 14))
            Text("Claude Usage")
                .font(ThemeTypography.heading)
                .foregroundColor(colors.text)
            Spacer()
            refreshButton
        }
    }

    // MARK: - Quota Card

    private var quotaCard: some View {
        VStack(spacing: 8) {
            ProgressBarView(
                value: Double(service.quota.sessionPercent),
                label: "Session",
                detail: "Resets \(service.quota.sessionResetTime)"
            )
            ProgressBarView(
                value: Double(service.quota.weeklyAllPercent),
                label: "Weekly (all models)",
                detail: "Resets \(service.quota.weeklyAllResetTime)"
            )
            ProgressBarView(
                value: Double(service.quota.weeklySonnetPercent),
                label: "Weekly (Sonnet)",
                detail: "Resets \(service.quota.weeklySonnetResetTime)"
            )
            if let error = service.quotaError {
                Text(error)
                    .font(ThemeTypography.caption)
                    .foregroundColor(colors.accent)
                    .lineLimit(2)
            }
        }
        .glassCard(cornerRadius: 10)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            if service.todayStats.messages > 0 {
                SectionHeader(title: "Today")
                statsRows(service.todayStats)
            } else if let cache = service.statsCache,
                      let lastDay = cache.dailyActivity.last {
                SectionHeader(title: "Latest (\(lastDay.date))")
                StatRow(label: "Messages", value: formatNumber(lastDay.messageCount))
                StatRow(label: "Sessions", value: formatNumber(lastDay.sessionCount))
                StatRow(label: "Tool Calls", value: formatNumber(lastDay.toolCallCount))
            }

            if let cache = service.statsCache {
                SectionDivider()
                SectionHeader(title: "Lifetime")
                StatRow(label: "Messages", value: formatNumber(cache.totalMessages))
                StatRow(label: "Sessions", value: formatNumber(cache.totalSessions))
            }
        }
        .glassCard(cornerRadius: 10)
    }

    // MARK: - Model Card

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Models")
            ModelBar(breakdowns: service.modelBreakdowns)
        }
        .glassCard(cornerRadius: 10)
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack {
            if let lastUpdated = service.lastUpdated {
                Text("Updated \(lastUpdated, style: .relative) ago")
                    .font(ThemeTypography.caption)
                    .foregroundColor(colors.muted)
            }
            Spacer()
            glassButton(icon: "gear") {
                openWindow(id: "settings")
            }
        }
    }

    // MARK: - Buttons

    @ViewBuilder
    private var refreshButton: some View {
        if service.isRefreshing {
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)
        } else {
            glassButton(icon: "arrow.clockwise") {
                Task { await service.refresh() }
            }
        }
    }

    @ViewBuilder
    private func glassButton(icon: String, action: @escaping () -> Void) -> some View {
        if #available(macOS 26, *) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 12))
            }
            .buttonStyle(.glass)
        } else {
            Button(action: action) {
                Image(systemName: icon)
                    .foregroundColor(colors.muted)
                    .font(.system(size: 12))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func statsRows(_ stats: PeriodStats) -> some View {
        Group {
            StatRow(label: "Messages", value: formatNumber(stats.messages))
            StatRow(label: "Sessions", value: formatNumber(stats.sessions))
            StatRow(label: "Tool Calls", value: formatNumber(stats.toolCalls))
            StatRow(label: "Tokens", value: formatTokens(stats.tokens))
        }
    }
}
