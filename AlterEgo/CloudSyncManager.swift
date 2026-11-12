import SwiftUI
import Combine

@MainActor
final class CloudSyncManager: ObservableObject {
    static var isCompiledIn: Bool {
        #if CLOUD_SYNC
        true
        #else
        false
        #endif
    }

    private static let enabledKey = "alterego.cloudSync.enabled"
    private static let payloadKey = "alterego.cloudSync.payload"
    private static let dateKey = "alterego.cloudSync.date"

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
        }
    }

    @Published private(set) var lastSync: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var pendingRemoteState: AppState?

    #if CLOUD_SYNC
    private var observer: NSObjectProtocol?
    #endif

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)

        #if CLOUD_SYNC
        lastSync = loadLastSyncDate()
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshFromCloud()
            }
        }
        #endif
    }

    var isAvailable: Bool {
        #if CLOUD_SYNC
        FileManager.default.ubiquityIdentityToken != nil
        #else
        false
        #endif
    }

    func uploadIfEnabled(_ state: AppState) {
        guard isEnabled else { return }
        upload(state)
    }

    func upload(_ state: AppState) {
        lastError = nil

        #if CLOUD_SYNC
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)

            guard data.count < 900_000 else {
                lastError = "Your data is too large for iCloud key-value sync. Use an export backup instead."
                return
            }

            let store = NSUbiquitousKeyValueStore.default
            store.set(data, forKey: Self.payloadKey)
            store.set(Date().timeIntervalSince1970, forKey: Self.dateKey)
            store.synchronize()

            lastSync = Date()
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    func download() -> AppState? {
        #if CLOUD_SYNC
        let store = NSUbiquitousKeyValueStore.default
        guard let data = store.data(forKey: Self.payloadKey) else { return nil }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(AppState.self, from: data)
            lastSync = loadLastSyncDate()
            lastError = nil
            return state
        } catch {
            lastError = error.localizedDescription
            return nil
        }
        #else
        return nil
        #endif
    }

    func refreshFromCloud() {
        guard isEnabled, let remote = download() else { return }
        pendingRemoteState = remote
    }

    func clearPendingRemote() {
        pendingRemoteState = nil
    }

    #if CLOUD_SYNC
    private func loadLastSyncDate() -> Date? {
        let value = NSUbiquitousKeyValueStore.default.double(forKey: Self.dateKey)
        guard value > 0 else { return nil }
        return Date(timeIntervalSince1970: value)
    }
    #endif
}
