import SwiftUI
import Combine

@main
struct AlterEgoApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var theme = ThemeManager()
    @StateObject private var cloudSync = CloudSyncManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(theme)
                .environmentObject(cloudSync)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        store.reload()
                        theme.refreshDaytime()
                    }
                }
                .onReceive(
                    store.$state
                        .dropFirst()
                        .debounce(for: .seconds(2), scheduler: RunLoop.main)
                ) { state in
                    cloudSync.uploadIfEnabled(state)
                }
                .onReceive(cloudSync.$pendingRemoteState.compactMap { $0 }) { remote in
                    store.mergeState(remote)
                    cloudSync.clearPendingRemote()
                }
                .task {
                    if cloudSync.isEnabled, let remote = cloudSync.download() {
                        store.mergeState(remote)
                    }
                }
        }
    }
}
