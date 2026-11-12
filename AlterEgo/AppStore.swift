import SwiftUI
import Combine
import WidgetKit

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var state: AppState

    private var lastModificationDate: Date?

    init() {
        state = SharedStorage.load()
        lastModificationDate = SharedStorage.modificationDate
    }

    func reload() {
        state = SharedStorage.load()
        lastModificationDate = SharedStorage.modificationDate
    }

    func reloadIfChanged() {
        let current = SharedStorage.modificationDate
        guard current != lastModificationDate else { return }
        state = SharedStorage.load()
        lastModificationDate = current
    }

    func activeSession(for alterID: UUID) -> FrontingSession? {
        state.activeSession(for: alterID)
    }

    func front(_ alter: Alter, mode: FrontingMode) {
        mutate { state in
            FrontingEngine.front(alterID: alter.id, mode: mode, in: &state)
        }
    }

    func stop(_ alter: Alter) {
        mutate { state in
            FrontingEngine.stop(alterID: alter.id, in: &state)
        }
    }

    func stopAll() {
        mutate { state in
            FrontingEngine.stopAll(in: &state)
        }
    }

    func addAlter(_ alter: Alter) {
        mutate { state in
            state.alters.append(alter)
        }
    }

    func updateAlter(_ alter: Alter) {
        mutate { state in
            guard let index = state.alters.firstIndex(where: { $0.id == alter.id }) else { return }
            state.alters[index] = alter
        }
    }

    func deleteAlter(_ alter: Alter) {
        mutate { state in
            state.alters.removeAll { $0.id == alter.id }
            state.sessions.removeAll { $0.alterID == alter.id }
        }
    }

    private func mutate(_ body: (inout AppState) -> Void) {
        state = SharedStorage.mutate(body)
        lastModificationDate = SharedStorage.modificationDate
        WidgetCenter.shared.reloadAllTimelines()
    }
}
