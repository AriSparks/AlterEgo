import Foundation

enum SharedConstants {
    static let appGroupID = "group.gay.arisparks.AlterEgo"
    static let stateFileName = "alterego-state.json"
    static let widgetKind = "AlterEgoWidget"
    static let stateNotification = "gay.arisparks.AlterEgo.stateChanged"

    static let themeSettingsKey = "alterego.theme.settings"
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
