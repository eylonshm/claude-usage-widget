import SwiftUI

struct ProgressBarView: View {
    let value: Double
    let label: String
    let detail: String
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    private var colors: ThemeColors { settings.effectiveColors(for: colorScheme) }
    private var isWarning: Bool { value >= settings.warningThreshold }
    private var fillColor: Color { isWarning ? colors.accent : colors.primary }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(ThemeTypography.caption)
                    .foregroundColor(colors.muted)
                Spacer()
                Text("\(Int(value))%")
                    .font(ThemeTypography.body)
                    .foregroundColor(isWarning ? colors.accent : colors.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(colors.surface.opacity(0.5))
                        .frame(height: 8)
                    // Fill
                    Capsule()
                        .fill(fillColor)
                        .frame(width: max(0, geo.size.width * min(value / 100, 1.0)), height: 8)
                        .tintedGlass(fillColor, cornerRadius: 4)
                        .shadow(color: fillColor.opacity(0.3), radius: 4, y: 0)
                }
            }
            .frame(height: 8)
            if !detail.isEmpty {
                Text(detail)
                    .font(ThemeTypography.caption)
                    .foregroundColor(colors.muted.opacity(0.6))
            }
        }
    }
}

struct CircularProgressView: View {
    let value: Double
    let label: String
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    private var colors: ThemeColors { settings.effectiveColors(for: colorScheme) }
    private var isWarning: Bool { value >= settings.warningThreshold }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(colors.surface.opacity(0.5), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(value / 100, 1.0))
                    .stroke(
                        isWarning ? colors.accent : colors.primary,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: (isWarning ? colors.accent : colors.primary).opacity(0.4), radius: 6)
                Text("\(Int(value))%")
                    .font(ThemeTypography.statValue)
                    .foregroundColor(colors.text)
            }
            Text(label)
                .font(ThemeTypography.caption)
                .foregroundColor(colors.muted)
        }
    }
}
