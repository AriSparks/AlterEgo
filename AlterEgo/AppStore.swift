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

    func addSession(_ session: FrontingSession) {
        mutate { state in
            state.sessions.append(session)
        }
    }

    func updateSession(_ session: FrontingSession) {
        mutate { state in
            guard let index = state.sessions.firstIndex(where: { $0.id == session.id }) else { return }
            state.sessions[index] = session
        }
    }

    func deleteSession(_ session: FrontingSession) {
        mutate { state in
            state.sessions.removeAll { $0.id == session.id }
        }
    }

    func replaceState(_ newState: AppState) {
        mutate { state in
            state = newState
        }
    }

    func mergeState(_ incoming: AppState) {
        mutate { state in
            var altersByID = Dictionary(uniqueKeysWithValues: state.alters.map { ($0.id, $0) })
            for alter in incoming.alters {
                if let existing = altersByID[alter.id] {
                    var merged = existing
                    if merged.imageData == nil { merged.imageData = alter.imageData }
                    if merged.originalImageData == nil { merged.originalImageData = alter.originalImageData }
                    if merged.descriptionText == nil { merged.descriptionText = alter.descriptionText }
                    if merged.pronouns == nil { merged.pronouns = alter.pronouns }
                    if merged.role == nil { merged.role = alter.role }
                    if (merged.characteristics ?? []).isEmpty { merged.characteristics = alter.characteristics }
                    if merged.bannerColorHex == nil { merged.bannerColorHex = alter.bannerColorHex }
                    altersByID[alter.id] = merged
                } else {
                    altersByID[alter.id] = alter
                }
            }
            state.alters = Array(altersByID.values).sorted { $0.createdAt < $1.createdAt }

            var sessionsByID = Dictionary(uniqueKeysWithValues: state.sessions.map { ($0.id, $0) })
            for session in incoming.sessions {
                sessionsByID[session.id] = session
            }
            state.sessions = Array(sessionsByID.values).sorted { $0.start < $1.start }
        }
    }

    private func mutate(_ body: (inout AppState) -> Void) {
        state = SharedStorage.mutate(body)
        lastModificationDate = SharedStorage.modificationDate
        WidgetCenter.shared.reloadAllTimelines()
    }
}
