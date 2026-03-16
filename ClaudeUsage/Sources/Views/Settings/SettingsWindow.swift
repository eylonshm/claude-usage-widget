import SwiftUI
import ServiceManagement

struct SettingsWindow: View {
    @State private var selectedTab = 0
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            UsageTab()
                .tabItem { Label("Usage", systemImage: "chart.bar") }
                .tag(0)
            SettingsTab()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(1)
        }
        .frame(minWidth: 480, minHeight: 560)
    }
}

// MARK: - Usage Tab

struct UsageTab: View {
    @ObservedObject var service = UsageDataService.shared
    @ObservedObject var settings = AppSettings.shared

    private var colors: ThemeColors { settings.colors }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with refresh
                HStack {
                    Text("Usage Overview")
                        .font(ThemeTypography.title)
                        .foregroundColor(colors.text)
                    Spacer()
                    if service.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    refreshButton
                }

                if let lastUpdated = service.lastUpdated {
                    Text("Last refreshed: \(lastUpdated, style: .relative) ago")
                        .font(ThemeTypography.caption)
                        .foregroundColor(colors.muted)
                }

                // Quota card
                if service.quotaError == nil || service.quota != .empty {
                    VStack(spacing: 10) {
                        SectionHeader(title: "Quota")
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
                    }
                    .glassCard(cornerRadius: 12)
                }

                // Model Breakdown
                if !service.modelBreakdowns.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Models")
                        ModelBar(breakdowns: service.modelBreakdowns)
                    }
                    .glassCard(cornerRadius: 12)
                }

                // Lifetime
                if let cache = service.statsCache {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Lifetime")
                        StatRow(label: "Total Sessions", value: formatNumber(cache.totalSessions))
                        StatRow(label: "Total Messages", value: formatNumber(cache.totalMessages))
                        if let firstDate = cache.firstSessionDate {
                            StatRow(label: "Member Since", value: String(firstDate.prefix(10)))
                        }
                    }
                    .glassCard(cornerRadius: 12)
                }
            }
            .padding(20)
        }
        .background(colors.background)
        .task {
            if service.lastUpdated == nil {
                await service.refresh()
            }
        }
    }

    @ViewBuilder
    private var refreshButton: some View {
        if #available(macOS 26, *) {
            Button(action: { Task { await service.refresh() } }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glass)
            .disabled(service.isRefreshing)
        } else {
            Button(action: { Task { await service.refresh() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(ThemeTypography.caption)
                .foregroundColor(colors.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .disabled(service.isRefreshing)
        }
    }

    private func statsGrid(_ stats: PeriodStats) -> some View {
        VStack(spacing: 4) {
            StatRow(label: "Messages", value: formatNumber(stats.messages))
            StatRow(label: "Sessions", value: formatNumber(stats.sessions))
            StatRow(label: "Tool Calls", value: formatNumber(stats.toolCalls))
            StatRow(label: "Tokens", value: formatTokens(stats.tokens))
        }
    }
}

// MARK: - Settings Tab

struct SettingsTab: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var service = UsageDataService.shared

    private var colors: ThemeColors { settings.colors }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(ThemeTypography.title)
                    .foregroundColor(colors.text)

                // General
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "General")

                    HStack {
                        Text("Refresh Interval")
                            .font(ThemeTypography.body)
                            .foregroundColor(colors.text)
                        Spacer()
                        Picker("", selection: $settings.refreshInterval) {
                            Text("5 min").tag(5)
                            Text("10 min").tag(10)
                            Text("15 min").tag(15)
                            Text("30 min").tag(30)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                        .onChange(of: settings.refreshInterval) { _, _ in
                            service.restartTimer()
                        }
                    }

                    Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                        .font(ThemeTypography.body)
                        .foregroundColor(colors.text)
                        .onChange(of: settings.launchAtLogin) { _, newValue in
                            LoginItemManager.setEnabled(newValue)
                        }

                    Toggle("Show Menu Bar Icon", isOn: $settings.showMenuBar)
                        .font(ThemeTypography.body)
                        .foregroundColor(colors.text)

                    Toggle("Show Lifetime Stats", isOn: $settings.showLifetime)
                        .font(ThemeTypography.body)
                        .foregroundColor(colors.text)

                    HStack {
                        Text("Menu Bar Style")
                            .font(ThemeTypography.body)
                            .foregroundColor(colors.text)
                        Spacer()
                        Picker("", selection: $settings.menuBarStyle) {
                            Text("Icon + %").tag("iconAndPercent")
                            Text("% Only").tag("percentOnly")
                            Text("Circle").tag("progressCircle")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                    }

                }
                .glassCard(cornerRadius: 12)

                // Warning Threshold
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Warning Threshold")
                    HStack {
                        Text("\(Int(settings.warningThreshold))%")
                            .font(ThemeTypography.body)
                            .foregroundColor(colors.text)
                            .frame(width: 40)
                        Slider(value: $settings.warningThreshold, in: 50...100, step: 5)
                            .tint(colors.primary)
                    }
                }
                .glassCard(cornerRadius: 12)

                // Appearance
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Appearance")

                    colorPickerRow("Background", hex: $settings.backgroundHex)
                    colorPickerRow("Surface", hex: $settings.surfaceHex)
                    colorPickerRow("Primary", hex: $settings.primaryHex)
                    colorPickerRow("Accent", hex: $settings.accentHex)
                    colorPickerRow("Text", hex: $settings.textHex)
                    colorPickerRow("Muted", hex: $settings.mutedHex)
                    colorPickerRow("Warning", hex: $settings.warningHex)

                    HStack {
                        Spacer()
                        Button(action: { settings.resetColors() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset to Defaults")
                            }
                            .font(ThemeTypography.caption)
                            .foregroundColor(colors.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.02), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .glassCard(cornerRadius: 12)

                // CLI Path
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Advanced")
                    HStack {
                        Text("Claude CLI Path")
                            .font(ThemeTypography.body)
                            .foregroundColor(colors.text)
                        TextField("Auto-detected", text: $settings.cliPath)
                            .font(ThemeTypography.body)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .glassCard(cornerRadius: 12)

                // Updates
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Updates")
                    HStack {
                        Spacer()
                        Button(action: {
                            AppDelegate.shared?.updaterController.updater.checkForUpdates(nil)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                Text("Check for Updates")
                            }
                            .font(ThemeTypography.caption)
                            .foregroundColor(colors.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.02), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .glassCard(cornerRadius: 12)
            }
            .padding(20)
        }
        .background(colors.background)
    }

    private func colorPickerRow(_ label: String, hex: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(ThemeTypography.body)
                .foregroundColor(colors.text)
            Spacer()
            ColorPicker("", selection: Binding(
                get: { Color(hex: hex.wrappedValue) ?? .white },
                set: { hex.wrappedValue = $0.hexString }
            ))
            .labelsHidden()
            .frame(width: 40)
            Text("#\(hex.wrappedValue)")
                .font(ThemeTypography.caption)
                .foregroundColor(colors.muted)
                .frame(width: 60)
        }
    }
}

// MARK: - Login Item Manager

enum LoginItemManager {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Login item error: \(error)")
        }
    }
}
