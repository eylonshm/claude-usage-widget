import SwiftUI
import ServiceManagement
import Sparkle

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var service = UsageDataService.shared
    @StateObject private var settings = AppSettings.shared
    @AppStorage("showMenuBar") private var showMenuBar: Bool = true
    // Loading phase: 0–360, driven by a sine wave so the fill breathes smoothly 0→100→0→…
    @State private var spinnerAngle: Double = 180
    private let spinnerTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some Scene {
        // Menu Bar
        MenuBarExtra(isInserted: $showMenuBar) {
            MenuBarDropdown()
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }
    @ViewBuilder
    private var menuBarLabel: some View {
        let pct = service.quota.sessionPercent
        let hasData = !(service.quotaError != nil && service.quota == .empty)
        let isLoading = service.isRefreshing || !service.hasLoadedOnce

        if isLoading {
            // Sine-eased oscillation: fill breathes 0→100→0→… over 2 s with smooth ease-in/out.
            // Driven by absolute time so easing is frame-rate-independent and jitter-free.
            Image(nsImage: progressCircleImage(percent: Int(spinnerAngle / 360.0 * 100)))
                .onReceive(spinnerTimer) { date in
                    let period = 2.0 // seconds per breath
                    let t = date.timeIntervalSince1970.truncatingRemainder(dividingBy: period) / period
                    // sin maps t ∈ [0,1] → smooth 0→1→0 without any hard jump
                    let eased = (sin(t * 2 * .pi - .pi / 2) + 1) / 2
                    spinnerAngle = eased * 360
                }
        } else {
            switch settings.menuBarStyle {
            case "progressCircle":
                Image(nsImage: progressCircleImage(percent: hasData ? pct : 0))
            case "percentOnly":
                Text(hasData ? "\(pct)%" : "—")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            default: // iconAndPercent
                HStack(spacing: 3) {
                    Image("MenuBarIcon")
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(hasData ? "\(pct)%" : "—")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
        }
    }

    private func progressCircleImage(percent: Int) -> NSImage {
        let size: CGFloat = 18
        let lineWidth: CGFloat = 2
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = (size - lineWidth) / 2

            // Track
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            NSColor.gray.withAlphaComponent(0.3).setStroke()
            track.lineWidth = lineWidth
            track.stroke()

            // Fill
            if percent > 0 {
                let fill = NSBezierPath()
                let startAngle: CGFloat = 90 // top
                let endAngle: CGFloat = 90 - (CGFloat(percent) / 100.0 * 360)
                fill.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                NSColor.labelColor.setStroke()
                fill.lineWidth = lineWidth
                fill.lineCapStyle = .round
                fill.stroke()
            }

            return true
        }
        image.isTemplate = true
        return image
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    var updaterController: SPUStandardUpdaterController!
    var updaterViewModel: UpdaterViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        updaterViewModel = UpdaterViewModel(updater: updaterController.updater)

        let settings = AppSettings.shared
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")

            // Enable launch at login on first run
            settings.launchAtLogin = true
            LoginItemManager.setEnabled(true)
        }

        // Start polling immediately
        Task { @MainActor in
            await UsageDataService.shared.refresh()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.open()
        return true
    }
}
