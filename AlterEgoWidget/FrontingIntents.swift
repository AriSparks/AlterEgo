import AppIntents
import WidgetKit

struct FrontAlongsideIntent: AppIntent {
    static var title: LocalizedStringResource { "Front Alongside" }
    static var description: IntentDescription {
        IntentDescription("Mark this alter as partially fronting alongside everyone currently fronting.")
    }

    @Parameter(title: "Alter ID")
    var alterID: String

    init() {}

    init(alterID: UUID) {
        self.alterID = alterID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alterID) else { return .result() }

        SharedStorage.mutate { state in
            FrontingEngine.front(alterID: id, mode: .partial, in: &state)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct TakeOverIntent: AppIntent {
    static var title: LocalizedStringResource { "Take Over" }
    static var description: IntentDescription {
        IntentDescription("Mark this alter as fully fronting and end everyone else's session.")
    }

    @Parameter(title: "Alter ID")
    var alterID: String

    init() {}

    init(alterID: UUID) {
        self.alterID = alterID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alterID) else { return .result() }

        SharedStorage.mutate { state in
            FrontingEngine.front(alterID: id, mode: .full, in: &state)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct StopFrontingIntent: AppIntent {
    static var title: LocalizedStringResource { "Stop Fronting" }
    static var description: IntentDescription {
        IntentDescription("End this alter's current fronting session.")
    }

    @Parameter(title: "Alter ID")
    var alterID: String

    init() {}

    init(alterID: UUID) {
        self.alterID = alterID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alterID) else { return .result() }

        SharedStorage.mutate { state in
            FrontingEngine.stop(alterID: id, in: &state)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
