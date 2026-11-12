import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case fronting
    case alters
    case timeline
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fronting: return "Fronting"
        case .alters: return "Alters"
        case .timeline: return "Timeline"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .fronting: return "person.2.fill"
        case .alters: return "person.crop.circle"
        case .timeline: return "chart.bar.xaxis"
        case .settings: return "gearshape.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var selection: AppSection = .fronting
    @State private var showAddFronter = false

    var body: some View {
        let scheme = theme.resolvedScheme(colorScheme)
        let palette = theme.palette(for: scheme)

        layout
            .environment(\.themePalette, palette)
            .tint(palette.accent.color)
            .background(ThemedBackground(fill: palette.background))
            .preferredColorScheme(theme.preferredColorScheme)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    store.reloadIfChanged()
                }
            }
            .sheet(isPresented: $showAddFronter) {
                AddFronterView()
                    .environmentObject(store)
                    .environmentObject(theme)
            }
            .onOpenURL { url in
                guard url.scheme == "alterego", url.host == "add-fronter" else { return }
                selection = .fronting
                showAddFronter = true
            }
    }

    @ViewBuilder
    private var layout: some View {
        #if os(macOS)
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            content(for: selection)
        }
        #else
        TabView(selection: $selection) {
            ForEach(AppSection.allCases) { section in
                content(for: section)
                    .tabItem {
                        Label(section.title, systemImage: section.icon)
                    }
                    .tag(section)
            }
        }
        #endif
    }

    @ViewBuilder
    private func content(for section: AppSection) -> some View {
        switch section {
        case .fronting:
            FrontingView()
        case .alters:
            AltersView()
        case .timeline:
            TimelineView()
        case .settings:
            SettingsView()
        }
    }
}
