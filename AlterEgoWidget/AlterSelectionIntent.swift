import AppIntents
import WidgetKit

struct AlterEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Alter")
    static var defaultQuery = AlterEntityQuery()

    var id: String
    var name: String
    var emoji: String

    init(id: String, name: String, emoji: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
    }

    init(alter: Alter) {
        self.init(id: alter.id.uuidString, name: alter.name, emoji: alter.emoji)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: emoji.isEmpty ? nil : "\(emoji)",
            image: .init(systemName: "person.crop.circle.fill")
        )
    }
}

struct AlterEntityQuery: EntityQuery {
    func entities(for identifiers: [AlterEntity.ID]) async throws -> [AlterEntity] {
        let state = SharedStorage.load()
        let ids = Set(identifiers)
        return state.alters
            .filter { ids.contains($0.id.uuidString) }
            .map(AlterEntity.init)
    }

    func suggestedEntities() async throws -> [AlterEntity] {
        SharedStorage.load().alters.map(AlterEntity.init)
    }

    func defaultResult() async -> AlterEntity? {
        SharedStorage.load().alters.first.map(AlterEntity.init)
    }
}

struct AlterSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose Alter" }
    static var description: IntentDescription { "Pick which alter this widget controls." }

    @Parameter(title: "Alter")
    var alter: AlterEntity?

    init() {}

    init(alter: AlterEntity?) {
        self.alter = alter
    }
}
