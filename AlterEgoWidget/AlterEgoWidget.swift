import WidgetKit
import SwiftUI
import AppIntents

struct Fronter: Identifiable {
    let alter: Alter
    let session: FrontingSession

    var id: UUID { session.id }
}

struct AlterEgoEntry: TimelineEntry {
    let date: Date
    let fronters: [Fronter]
    let totalAlters: Int
}

struct AlterEgoProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlterEgoEntry {
        let alter = Alter(name: "Alex", emoji: "🌙", colorHex: Alter.palette[0])
        let session = FrontingSession(alterID: alter.id, mode: .full)
        return AlterEgoEntry(
            date: .now,
            fronters: [Fronter(alter: alter, session: session)],
            totalAlters: 1
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AlterEgoEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlterEgoEntry>) -> Void) {
        let entry = makeEntry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now)
            ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry() -> AlterEgoEntry {
        let state = SharedStorage.load()
        let fronters = state.activeSessions
            .compactMap { session -> Fronter? in
                guard let alter = state.alter(withID: session.alterID) else { return nil }
                return Fronter(alter: alter, session: session)
            }
            .sorted { $0.session.start < $1.session.start }

        return AlterEgoEntry(
            date: .now,
            fronters: fronters,
            totalAlters: state.alters.count
        )
    }
}

struct AlterEgoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: SharedConstants.widgetKind,
            provider: AlterEgoProvider()
        ) { entry in
            AlterEgoWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground(alter: entry.fronters.first?.alter)
                }
        }
        .configurationDisplayName("Alter Fronting")
        .description("See who is fronting and add another alter with a tap.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct AlterEgoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AlterEgoEntry

    private let addURL = URL(string: "alterego://add-fronter")!

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content
            Spacer(minLength: 0)
            addButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(entry.fronters.isEmpty ? "AlterEgo" : "Fronting now")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if !entry.fronters.isEmpty {
                Text("\(entry.fronters.count)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if entry.fronters.isEmpty {
            emptyView
        } else {
            switch family {
            case .systemSmall:
                smallView
            case .systemLarge:
                largeView
            default:
                mediumView
            }
        }
    }

    private var smallView: some View {
        let first = entry.fronters[0]

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                AvatarView(alter: first.alter, size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(first.alter.name)
                        .font(.headline)
                        .lineLimit(1)
                    StatusBadge(mode: first.session.mode, compact: true)
                }
            }

            if entry.fronters.count > 1 {
                Text("+\(entry.fronters.count - 1) more fronting")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entry.fronters.prefix(2)) { fronter in
                fronterRow(fronter)
            }

            if entry.fronters.count > 2 {
                Text("+\(entry.fronters.count - 2) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entry.fronters.prefix(5)) { fronter in
                fronterRow(fronter)
            }

            if entry.fronters.count > 5 {
                Text("+\(entry.fronters.count - 5) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func fronterRow(_ fronter: Fronter) -> some View {
        HStack(spacing: 8) {
            AvatarView(alter: fronter.alter, size: 30)

            Text(fronter.alter.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 0)

            StatusBadge(mode: fronter.session.mode, compact: true)
        }
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "moon.zzz.fill")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("No one is fronting")
                .font(.subheadline.weight(.semibold))

            if entry.totalAlters == 0 {
                Text("Add alters in the app to get started.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var addButton: some View {
        Link(destination: addURL) {
            Label(entry.totalAlters == 0 ? "Open AlterEgo" : "Add Fronter", systemImage: "plus")
                .font(.caption.bold())
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.accentColor, in: Capsule())
                .foregroundStyle(.white)
        }
        .accessibilityLabel("Add another fronting alter")
    }
}

struct WidgetBackground: View {
    let alter: Alter?

    var body: some View {
        let color = Color(hex: alter?.colorHex ?? "#6C5CE7")
        LinearGradient(
            colors: [color.opacity(0.38), color.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
