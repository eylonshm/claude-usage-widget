import SwiftUI

struct MenuBarDropdown: View {
    @ObservedObject var service = UsageDataService.shared
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    private var colors: ThemeColors { settings.effectiveColors(for: colorScheme) }

    var body: some View {
        glassContainer {
            VStack(alignment: .leading, spacing: 10) {
                headerRow
                if service.permissionDenied {
                    permissionDeniedBanner
                } else {
                    sessionCountdownBanner
                    quotaCard
                    if !service.modelBreakdowns.isEmpty {
                        modelCard
                    }
                    if settings.showLifetime, let cache = service.statsCache {
                        lifetimeCard(cache)
                    }
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
            Color.clear
        } else {
            colors.background.ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("Claude Usage")
                .font(ThemeTypography.heading)
                .foregroundColor(colors.text)
            Spacer()
            refreshButton
        }
    }

    // MARK: - Permission Denied Banner

    private var permissionDeniedBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 16))
                    .foregroundColor(colors.accent)
                Text("Permission Required")
                    .font(ThemeTypography.heading)
                    .foregroundColor(colors.text)
            }

            Text("Claude Usage needs access to read your stats from **~/.claude/**. Open Privacy & Security settings and enable access for Claude Usage under **Files and Folders**.")
                .font(ThemeTypography.caption)
                .foregroundColor(colors.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_FilesAndFolders")!
                )
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gear")
                    Text("Open Privacy Settings")
                }
                .font(ThemeTypography.caption)
                .foregroundColor(colors.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(colors.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Text("After granting access, click Refresh.")
                .font(ThemeTypography.caption)
                .foregroundColor(colors.muted)
        }
        .glassCard(cornerRadius: 10)
    }

    // MARK: - Quota Card

    private var hasQuotaContent: Bool {
        service.quota.sessionResetTime != "—" ||
        service.quota.weeklyAllResetTime != "—" ||
        service.quota.weeklySonnetResetTime != "—" ||
        service.quotaError != nil
    }

    @ViewBuilder
    private var quotaCard: some View {
        if hasQuotaContent {
            VStack(spacing: 8) {
                if service.quota.sessionResetTime != "—" {
                    ProgressBarView(
                        value: Double(service.quota.sessionPercent),
                        label: "Session",
                        detail: "Resets \(service.quota.sessionResetTime)"
                    )
                }
                if service.quota.weeklyAllResetTime != "—" {
                    ProgressBarView(
                        value: Double(service.quota.weeklyAllPercent),
                        label: "Weekly (all models)",
                        detail: "Resets \(service.quota.weeklyAllResetTime)"
                    )
                }
                if service.quota.weeklySonnetResetTime != "—" {
                    ProgressBarView(
                        value: Double(service.quota.weeklySonnetPercent),
                        label: "Weekly (Sonnet)",
                        detail: "Resets \(service.quota.weeklySonnetResetTime)"
                    )
                }
                if let error = service.quotaError {
                    Text(error)
                        .font(ThemeTypography.caption)
                        .foregroundColor(colors.accent)
                        .lineLimit(2)
                }
            }
            .glassCard(cornerRadius: 10)
        }
    }

    // MARK: - Model Card

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Models")
            ModelBar(breakdowns: service.modelBreakdowns)
        }
        .glassCard(cornerRadius: 10)
    }

    // MARK: - Lifetime Card

    private func lifetimeCard(_ cache: StatsCache) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionHeader(title: "Lifetime")
                Spacer()
                Button(action: { settings.showLifetime = false }) {
                    Image(systemName: "eye.slash")
                        .foregroundColor(colors.muted)
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)
            StatRow(label: "Messages", value: formatNumber(cache.totalMessages))
            StatRow(label: "Sessions", value: formatNumber(cache.totalSessions))
            if let firstDate = cache.firstSessionDate {
                StatRow(label: "Since", value: String(firstDate.prefix(10)))
            }
        }
        .glassCard(cornerRadius: 10)
    }

    // MARK: - Session Countdown Banner

    @ViewBuilder
    private var sessionCountdownBanner: some View {
        if let resetDate = service.sessionResetDate {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = resetDate.timeIntervalSince(context.date)
                if remaining > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(colors.accent)
                        Text("New session starts in \(formatCountdown(remaining))")
                            .font(ThemeTypography.caption)
                            .foregroundColor(colors.text)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(colors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func formatCountdown(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if days > 0 { return "\(days)d \(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h \(mins)m \(secs)s" }
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
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
            glassButton(icon: "arrow.up.right.square") {
                if let url = URL(string: "https://claude.ai/settings/usage") {
                    NSWorkspace.shared.open(url)
                }
            }
            glassButton(icon: "gear") {
                SettingsWindowController.shared.open()
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
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(colors.muted)
                .font(.system(size: 12))
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.04), in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.07), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
