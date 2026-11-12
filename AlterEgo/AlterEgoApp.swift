import SwiftUI

@main
struct AlterEgoApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        store.reload()
                    }
                }
        }
    }
}
