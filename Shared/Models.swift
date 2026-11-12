import Foundation

enum SharedConstants {
    static let appGroupID = "group.gay.arisparks.AlterEgo"
    static let stateFileName = "alterego-state.json"
    static let widgetKind = "AlterEgoWidget"
    static let stateNotification = "gay.arisparks.AlterEgo.stateChanged"

    static let themeSettingsKey = "alterego.theme.settings"
    static let themeSnapshotKey = "alterego.theme.snapshot"
    static let accentColorKey = "alterego.theme.accentHex"
    static let partialStripesKey = "alterego.theme.showPartialStripes"
    static let defaultAccentHex = "#6C5CE7"
}

struct Alter: Identifiable, Codable, Hashable {
    static let palette = [
        "#FF6B6B", "#FF9F43", "#FFD93D", "#2ECC71", "#1DD1A1",
        "#4ECDC4", "#45B7D1", "#5F27CD", "#A29BFE", "#F368E0",
        "#EE5A6F", "#54A0FF", "#00D2D3", "#FECA57", "#C8D6E5"
    ]

    var id: UUID
    var name: String
    var emoji: String
    var imageData: Data?
    var colorHex: String
    var createdAt: Date

    var descriptionText: String?
    var pronouns: String?
    var role: String?
    var characteristics: [String]?
    var originalImageData: Data?
    var bannerColorHex: String?

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "🙂",
        imageData: Data? = nil,
        colorHex: String = Alter.palette[0],
        createdAt: Date = Date(),
        descriptionText: String? = nil,
        pronouns: String? = nil,
        role: String? = nil,
        characteristics: [String]? = nil,
        originalImageData: Data? = nil,
        bannerColorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.imageData = imageData
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.descriptionText = descriptionText
        self.pronouns = pronouns
        self.role = role
        self.characteristics = characteristics
        self.originalImageData = originalImageData
        self.bannerColorHex = bannerColorHex
    }

    var displayRole: String? {
        guard let role, !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return role
    }

    var displayPronouns: String? {
        guard let pronouns, !pronouns.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return pronouns
    }

    var displayDescription: String? {
        guard let descriptionText,
              !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return descriptionText
    }

    var displayCharacteristics: [String] {
        (characteristics ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

enum FrontingMode: String, Codable, Hashable, CaseIterable {
    case full
    case partial

    var label: String {
        switch self {
        case .full: return "Fully fronting"
        case .partial: return "Partially fronting"
        }
    }

    var shortLabel: String {
        switch self {
        case .full: return "Full"
        case .partial: return "Partial"
        }
    }
}

struct FrontingSession: Identifiable, Codable, Hashable {
    var id: UUID
    var alterID: UUID
    var start: Date
    var end: Date?
    var mode: FrontingMode

    init(
        id: UUID = UUID(),
        alterID: UUID,
        start: Date = Date(),
        end: Date? = nil,
        mode: FrontingMode
    ) {
        self.id = id
        self.alterID = alterID
        self.start = start
        self.end = end
        self.mode = mode
    }

    var isActive: Bool { end == nil }

    func duration(at date: Date = Date()) -> TimeInterval {
        max(0, (end ?? date).timeIntervalSince(start))
    }
}

struct AppState: Codable {
    var alters: [Alter] = []
    var sessions: [FrontingSession] = []

    func alter(withID id: UUID?) -> Alter? {
        guard let id else { return nil }
        return alters.first { $0.id == id }
    }

    func activeSession(for alterID: UUID) -> FrontingSession? {
        sessions.last { $0.alterID == alterID && $0.isActive }
    }

    var activeSessions: [FrontingSession] {
        sessions.filter(\.isActive)
    }

    var activeAlters: [Alter] {
        var seen = Set<UUID>()
        return activeSessions.compactMap { session in
            guard seen.insert(session.alterID).inserted else { return nil }
            return alter(withID: session.alterID)
        }
    }

    var isAnyoneFronting: Bool {
        sessions.contains(where: \.isActive)
    }
}

struct SharedGradientStop: Codable, Hashable {
    var hex: String
    var location: Double
}

struct SharedFill: Codable, Hashable {
    enum Kind: String, Codable {
        case solid
        case gradient
    }

    var kind: Kind
    var solidHex: String
    var stops: [SharedGradientStop]
    var angle: Double

    static func solid(_ hex: String) -> SharedFill {
        SharedFill(kind: .solid, solidHex: hex, stops: [], angle: 90)
    }

    static func gradient(_ hexes: [String], angle: Double = 90) -> SharedFill {
        let safe = hexes.isEmpty ? [SharedConstants.defaultAccentHex] : hexes
        let step = safe.count > 1 ? 1 / Double(safe.count - 1) : 0
        return SharedFill(
            kind: .gradient,
            solidHex: safe[0],
            stops: safe.enumerated().map { index, hex in
                SharedGradientStop(hex: hex, location: Double(index) * step)
            },
            angle: angle
        )
    }

    var isGradient: Bool {
        kind == .gradient && stops.count >= 2
    }

    var averageHex: String {
        guard isGradient, !stops.isEmpty else { return solidHex }
        return stops[stops.count / 2].hex
    }
}

struct SharedPalette: Codable, Hashable {
    var background: SharedFill
    var surface: SharedFill
    var accent: SharedFill
    var primaryText: SharedFill
    var secondaryText: SharedFill

    static let lightDefault = SharedPalette(
        background: .solid("#F6F6FA"),
        surface: .solid("#FFFFFF"),
        accent: .solid(SharedConstants.defaultAccentHex),
        primaryText: .solid("#17171C"),
        secondaryText: .solid("#6A6A75")
    )

    static let darkDefault = SharedPalette(
        background: .solid("#0E0E13"),
        surface: .solid("#1C1C24"),
        accent: .solid("#8C7CFF"),
        primaryText: .solid("#F7F7FA"),
        secondaryText: .solid("#A7A7B2")
    )
}

struct SharedThemeSnapshot: Codable, Hashable {
    var appearanceMode: String
    var daytimeLightMinutes: Int
    var daytimeDarkMinutes: Int
    var light: SharedPalette
    var dark: SharedPalette
    var showPartialStripes: Bool

    static let `default` = SharedThemeSnapshot(
        appearanceMode: "system",
        daytimeLightMinutes: 7 * 60,
        daytimeDarkMinutes: 19 * 60,
        light: .lightDefault,
        dark: .darkDefault,
        showPartialStripes: true
    )

    func isDark(systemIsDark: Bool, at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch appearanceMode {
        case "light":
            return false
        case "dark":
            return true
        case "daytime":
            let components = calendar.dateComponents([.hour, .minute], from: date)
            let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            let light = normalized(daytimeLightMinutes)
            let dark = normalized(daytimeDarkMinutes)
            guard light != dark else { return systemIsDark }

            if dark < light {
                return minutes >= dark && minutes < light
            } else {
                return minutes >= dark || minutes < light
            }
        default:
            return systemIsDark
        }
    }

    func palette(isDark: Bool) -> SharedPalette {
        isDark ? dark : light
    }

    private func normalized(_ minutes: Int) -> Int {
        ((minutes % 1440) + 1440) % 1440
    }
}

enum SharedTheme {
    static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedConstants.appGroupID) ?? .standard
    }

    static var accentHex: String {
        defaults.string(forKey: SharedConstants.accentColorKey) ?? SharedConstants.defaultAccentHex
    }

    static var showPartialStripes: Bool {
        if defaults.object(forKey: SharedConstants.partialStripesKey) == nil { return true }
        return defaults.bool(forKey: SharedConstants.partialStripesKey)
    }

    static var snapshot: SharedThemeSnapshot {
        guard let data = defaults.data(forKey: SharedConstants.themeSnapshotKey),
              let snapshot = try? JSONDecoder().decode(SharedThemeSnapshot.self, from: data) else {
            return .default
        }
        return snapshot
    }
}

enum SharedStorage {
    private static let fallbackKey = "alterego.fallback.state"

    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID
        )
    }

    static var stateFileURL: URL? {
        containerURL?.appendingPathComponent(SharedConstants.stateFileName)
    }

    static var modificationDate: Date? {
        guard let url = stateFileURL else { return nil }
        return try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    static func load() -> AppState {
        if let url = stateFileURL, let data = try? Data(contentsOf: url) {
            if let state = try? JSONDecoder().decode(AppState.self, from: data) {
                return state
            }
        }

        if let data = UserDefaults.standard.data(forKey: fallbackKey),
           let state = try? JSONDecoder().decode(AppState.self, from: data) {
            return state
        }

        return AppState()
    }

    @discardableResult
    static func save(_ state: AppState) -> AppState {
        guard let data = try? JSONEncoder().encode(state) else { return state }

        if let url = stateFileURL {
            try? data.write(to: url, options: .atomic)
        } else {
            UserDefaults.standard.set(data, forKey: fallbackKey)
        }

        return state
    }

    @discardableResult
    static func mutate(_ body: (inout AppState) -> Void) -> AppState {
        var state = load()
        body(&state)
        return save(state)
    }
}

enum FrontingEngine {
    static func front(
        alterID: UUID,
        mode: FrontingMode,
        in state: inout AppState,
        at date: Date = Date()
    ) {
        guard state.alters.contains(where: { $0.id == alterID }) else { return }

        switch mode {
        case .full:
            for index in state.sessions.indices
            where state.sessions[index].isActive && state.sessions[index].alterID != alterID {
                state.sessions[index].end = date
            }

            if let index = state.sessions.lastIndex(where: { $0.alterID == alterID && $0.isActive }) {
                state.sessions[index].mode = .full
            } else {
                state.sessions.append(
                    FrontingSession(alterID: alterID, start: date, mode: .full)
                )
            }

        case .partial:
            if !state.sessions.contains(where: { $0.alterID == alterID && $0.isActive }) {
                state.sessions.append(
                    FrontingSession(alterID: alterID, start: date, mode: .partial)
                )
            }
        }
    }

    static func stop(alterID: UUID, in state: inout AppState, at date: Date = Date()) {
        for index in state.sessions.indices
        where state.sessions[index].alterID == alterID && state.sessions[index].isActive {
            state.sessions[index].end = date
        }
    }

    static func stopAll(in state: inout AppState, at date: Date = Date()) {
        for index in state.sessions.indices where state.sessions[index].isActive {
            state.sessions[index].end = date
        }
    }
}

func shortDuration(_ interval: TimeInterval) -> String {
    let totalMinutes = Int(interval / 60)
    if totalMinutes < 1 { return "just now" }
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 {
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }
    return "\(minutes)m"
}
