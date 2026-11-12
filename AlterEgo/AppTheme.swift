import SwiftUI
import Combine
import WidgetKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case daytime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .daytime: return "Daytime"
        }
    }

    var explanation: String {
        switch self {
        case .system: return "Follows the system appearance."
        case .light: return "Always uses the light theme."
        case .dark: return "Always uses the dark theme."
        case .daytime: return "Switches between light and dark on your schedule."
        }
    }
}

struct GradientStopSettings: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var hex: String
    var location: Double
}

enum FillKind: String, Codable, CaseIterable, Identifiable {
    case solid
    case gradient

    var id: String { rawValue }
    var title: String { self == .solid ? "Solid" : "Gradient" }
}

struct FillSpec: Codable, Hashable {
    var kind: FillKind
    var solidHex: String
    var stops: [GradientStopSettings]
    var angle: Double

    static func solid(_ hex: String) -> FillSpec {
        FillSpec(kind: .solid, solidHex: hex, stops: [], angle: 90)
    }

    static func gradient(_ hexes: [String], angle: Double = 90) -> FillSpec {
        let safe = hexes.isEmpty ? [SharedConstants.defaultAccentHex] : hexes
        let step = safe.count > 1 ? 1 / Double(safe.count - 1) : 0
        return FillSpec(
            kind: .gradient,
            solidHex: safe[0],
            stops: safe.enumerated().map { index, hex in
                GradientStopSettings(hex: hex, location: Double(index) * step)
            },
            angle: angle
        )
    }

    var isGradient: Bool { kind == .gradient && stops.count >= 2 }

    var color: Color {
        Color(hex: isGradient ? (stops.first?.hex ?? solidHex) : solidHex)
    }

    var gradient: LinearGradient {
        let sorted = stops.sorted { $0.location < $1.location }
        return LinearGradient(
            gradient: Gradient(stops: sorted.map {
                Gradient.Stop(color: Color(hex: $0.hex), location: $0.location)
            }),
            startPoint: startPoint,
            endPoint: endPoint
        )
    }

    var startPoint: UnitPoint {
        let radians = angle * .pi / 180
        return UnitPoint(x: 0.5 - cos(radians) / 2, y: 0.5 - sin(radians) / 2)
    }

    var endPoint: UnitPoint {
        let radians = angle * .pi / 180
        return UnitPoint(x: 0.5 + cos(radians) / 2, y: 0.5 + sin(radians) / 2)
    }

    @ViewBuilder
    func fill<S: Shape>(_ shape: S) -> some View {
        if isGradient {
            shape.fill(gradient)
        } else {
            shape.fill(Color(hex: solidHex))
        }
    }

    var averageHex: String {
        guard isGradient, !stops.isEmpty else { return solidHex }
        return stops[stops.count / 2].hex
    }
}

struct PaletteSettings: Codable, Hashable {
    var background: FillSpec
    var accent: FillSpec
    var primaryText: FillSpec
    var secondaryText: FillSpec
    var surface: FillSpec

    static let lightDefault = PaletteSettings(
        background: .solid("#F6F6FA"),
        accent: .solid(SharedConstants.defaultAccentHex),
        primaryText: .solid("#17171C"),
        secondaryText: .solid("#6A6A75"),
        surface: .solid("#FFFFFF")
    )

    static let darkDefault = PaletteSettings(
        background: .solid("#0E0E13"),
        accent: .solid("#8C7CFF"),
        primaryText: .solid("#F7F7FA"),
        secondaryText: .solid("#A7A7B2"),
        surface: .solid("#1C1C24")
    )
}

struct ThemeSettings: Codable {
    var appearanceMode: AppearanceMode = .system
    var daytimeLightMinutes: Int = 7 * 60
    var daytimeDarkMinutes: Int = 19 * 60
    var accentHex: String = SharedConstants.defaultAccentHex
    var light: PaletteSettings = .lightDefault
    var dark: PaletteSettings = .darkDefault
    var use24HourTime: Bool = false
    var weekStartDay: Int = 1
    var hidePartialStripes: Bool = false

    static let `default` = ThemeSettings()
}

private extension SharedFill {
    init(_ fill: FillSpec) {
        self.init(
            kind: fill.kind == .gradient ? .gradient : .solid,
            solidHex: fill.solidHex,
            stops: fill.stops.map { SharedGradientStop(hex: $0.hex, location: $0.location) },
            angle: fill.angle
        )
    }
}

private extension SharedPalette {
    init(_ palette: PaletteSettings) {
        self.init(
            background: SharedFill(palette.background),
            surface: SharedFill(palette.surface),
            accent: SharedFill(palette.accent),
            primaryText: SharedFill(palette.primaryText),
            secondaryText: SharedFill(palette.secondaryText)
        )
    }
}

private extension SharedThemeSnapshot {
    init(_ settings: ThemeSettings) {
        self.init(
            appearanceMode: settings.appearanceMode.rawValue,
            daytimeLightMinutes: settings.daytimeLightMinutes,
            daytimeDarkMinutes: settings.daytimeDarkMinutes,
            light: SharedPalette(settings.light),
            dark: SharedPalette(settings.dark),
            showPartialStripes: !settings.hidePartialStripes
        )
    }
}

enum SettingsStore {
    static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedConstants.appGroupID) ?? .standard
    }

    static func load() -> ThemeSettings {
        guard let data = defaults.data(forKey: SharedConstants.themeSettingsKey),
              let settings = try? JSONDecoder().decode(ThemeSettings.self, from: data) else {
            return ThemeSettings()
        }
        return settings
    }

    static func save(_ settings: ThemeSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: SharedConstants.themeSettingsKey)
        }
        if let data = try? JSONEncoder().encode(SharedThemeSnapshot(settings)) {
            defaults.set(data, forKey: SharedConstants.themeSnapshotKey)
        }
        defaults.set(settings.accentHex, forKey: SharedConstants.accentColorKey)
        defaults.set(settings.hidePartialStripes, forKey: SharedConstants.partialStripesKey)
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    @Published var settings: ThemeSettings {
        didSet {
            SettingsStore.save(settings)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    @Published private(set) var daytimeIsDark: Bool = false

    private var switchTimer: Timer?

    init() {
        settings = SettingsStore.load()
        refreshDaytime(now: Date())
        scheduleNextSwitch()
        SettingsStore.save(settings)
    }

    func resolvedScheme(_ environmentScheme: ColorScheme) -> ColorScheme {
        switch settings.appearanceMode {
        case .system:
            return environmentScheme
        case .light:
            return .light
        case .dark:
            return .dark
        case .daytime:
            return daytimeIsDark ? .dark : .light
        }
    }

    func palette(for environmentScheme: ColorScheme) -> PaletteSettings {
        resolvedScheme(environmentScheme) == .dark ? settings.dark : settings.light
    }

    var preferredColorScheme: ColorScheme? {
        switch settings.appearanceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        case .daytime: return daytimeIsDark ? .dark : .light
        }
    }

    func accentColor(for environmentScheme: ColorScheme) -> Color {
        palette(for: environmentScheme).accent.color
    }

    func setAccent(_ color: Color) {
        let hex = color.toHex()
        settings.accentHex = hex
        settings.light.accent = .solid(hex)
        settings.dark.accent = .solid(hex)
    }

    func refreshDaytime(now: Date = Date()) {
        let minutes = minutesSinceMidnight(now)
        let value = isDark(minutes: minutes)
        if value != daytimeIsDark {
            daytimeIsDark = value
        }
        scheduleNextSwitch(now: now)
    }

    private func isDark(minutes: Int) -> Bool {
        let light = normalizedMinutes(settings.daytimeLightMinutes)
        let dark = normalizedMinutes(settings.daytimeDarkMinutes)
        guard light != dark else { return false }

        if dark < light {
            return minutes >= dark && minutes < light
        } else {
            return minutes >= dark || minutes < light
        }
    }

    private func scheduleNextSwitch(now: Date = Date()) {
        switchTimer?.invalidate()

        guard settings.appearanceMode == .daytime else { return }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let candidates = [settings.daytimeLightMinutes, settings.daytimeDarkMinutes].compactMap { minutes -> Date? in
            calendar.date(byAdding: .minute, value: normalizedMinutes(minutes), to: startOfToday)
        }

        let next = candidates
            .map { $0 <= now ? calendar.date(byAdding: .day, value: 1, to: $0) ?? $0 : $0 }
            .min() ?? now.addingTimeInterval(3600)

        let interval = max(1, next.timeIntervalSince(now) + 0.5)
        switchTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshDaytime(now: Date())
            }
        }
    }

    private func minutesSinceMidnight(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func normalizedMinutes(_ value: Int) -> Int {
        ((value % 1440) + 1440) % 1440
    }

    var timelineCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = min(7, max(1, settings.weekStartDay))
        return calendar
    }

    func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = settings.use24HourTime ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }

    func hourLabel(_ hour: Int) -> String {
        let normalized = ((hour % 24) + 24) % 24
        if settings.use24HourTime {
            return String(format: "%02d:00", normalized)
        }
        let suffix = normalized < 12 ? "a" : "p"
        let display = normalized % 12 == 0 ? 12 : normalized % 12
        return "\(display)\(suffix)"
    }

    func weekdayName(_ index: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let safe = min(symbols.count - 1, max(0, index - 1))
        return symbols[safe]
    }
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = PaletteSettings.darkDefault
}

extension EnvironmentValues {
    var themePalette: PaletteSettings {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

struct ThemedBackground: View {
    let fill: FillSpec

    var body: some View {
        fill.fill(Rectangle())
            .ignoresSafeArea()
    }
}

struct ThemedCardBackground: View {
    let fill: FillSpec
    var cornerRadius: CGFloat = 20

    var body: some View {
        fill.fill(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension Color {
    func toHex() -> String {
        #if os(macOS)
        guard let color = NSColor(self).usingColorSpace(.sRGB) else {
            return SharedConstants.defaultAccentHex
        }
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
        #else
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return SharedConstants.defaultAccentHex
        }
        return String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
        #endif
    }
}

enum Haptics {
    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func impact() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

func hexContrastRatio(_ first: String, _ second: String) -> Double {
    let l1 = relativeLuminance(first)
    let l2 = relativeLuminance(second)
    let lighter = max(l1, l2)
    let darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)
}

private func relativeLuminance(_ hex: String) -> Double {
    let rgb = rgbComponents(hex)
    func channel(_ value: Double) -> Double {
        value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(rgb.0) + 0.7152 * channel(rgb.1) + 0.0722 * channel(rgb.2)
}

private func rgbComponents(_ hex: String) -> (Double, Double, Double) {
    var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix("#") { value.removeFirst() }
    var number: UInt64 = 0
    Scanner(string: value).scanHexInt64(&number)
    if value.count == 8 {
        return (
            Double((number >> 24) & 0xFF) / 255,
            Double((number >> 16) & 0xFF) / 255,
            Double((number >> 8) & 0xFF) / 255
        )
    }
    guard value.count == 6 else { return (0.5, 0.5, 0.5) }
    return (
        Double((number >> 16) & 0xFF) / 255,
        Double((number >> 8) & 0xFF) / 255,
        Double(number & 0xFF) / 255
    )
}
