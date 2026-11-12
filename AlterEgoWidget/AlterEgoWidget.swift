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
    let accentHex: String
    let showStripes: Bool
}

struct AlterEgoProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlterEgoEntry {
        let alter = Alter(name: "Alex", emoji: "🌙", colorHex: Alter.palette[0])
        let session = FrontingSession(alterID: alter.id, mode: .full)
        return AlterEgoEntry(
            date: .now,
            fronters: [Fronter(alter: alter, session: session)],
            totalAlters: 1,
            accentHex: SharedConstants.defaultAccentHex,
            showStripes: true
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
            totalAlters: state.alters.count,
            accentHex: SharedTheme.accentHex,
            showStripes: SharedTheme.showPartialStripes
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
                    WidgetBackground(
                        alter: entry.fronters.first?.alter,
                        accentHex: entry.accentHex
                    )
                }
        }
        .configurationDisplayName("Alter Fronting")
        .description("See who is fronting, with full or partial fronting at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct AlterEgoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AlterEgoEntry

    private let addURL = URL(string: "alterego://add-fronter")!

    private var accent: Color {
        Color(hex: entry.accentHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

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

            Spacer(minLength: 0)
            addButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.fronters.isEmpty ? "ALTER EGO" : "FRONTING NOW")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)

                Text(
                    entry.fronters.isEmpty
                    ? "\(entry.totalAlters) alters"
                    : "\(entry.fronters.count) of \(entry.totalAlters) alters"
                )
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            if !entry.fronters.isEmpty {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: accent.opacity(0.7), radius: 4)
                    .widgetAccentable()
            }
        }
    }

    private var smallView: some View {
        let first = entry.fronters[0]

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                AvatarView(alter: first.alter, size: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(first.alter.name)
                        .font(.headline)
                        .lineLimit(1)

                    if let role = first.alter.displayRole {
                        Text(role)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            frontingBar(first)

            if entry.fronters.count > 1 {
                Text("+\(entry.fronters.count - 1) more")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(entry.fronters.prefix(2)) { fronter in
                fronterRow(fronter)
            }

            if entry.fronters.count > 2 {
                Text("+\(entry.fronters.count - 2) more fronting")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entry.fronters.prefix(6)) { fronter in
                fronterRow(fronter, showsRole: true)

                if fronter.id != entry.fronters.prefix(6).last?.id {
                    Divider()
                        .opacity(0.35)
                }
            }

            if entry.fronters.count > 6 {
                Text("+\(entry.fronters.count - 6) more fronting")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func fronterRow(_ fronter: Fronter, showsRole: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                AvatarView(alter: fronter.alter, size: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text(fronter.alter.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if showsRole, let role = fronter.alter.displayRole {
                        Text(role)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(fronter.session.mode.shortLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: fronter.session.mode == .full
                      ? "person.fill.checkmark"
                      : "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(fronter.session.mode == .full ? accent : .orange)
                    .widgetAccentable(fronter.session.mode == .full)
            }

            frontingBar(fronter)
        }
    }

    private func frontingBar(_ fronter: Fronter) -> some View {
        FrontingBar(
            color: Color(hex: fronter.alter.colorHex),
            mode: fronter.session.mode,
            cornerRadius: 3,
            showStripes: entry.showStripes
        )
        .frame(height: 4)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 44, height: 44)

                Image(systemName: "moon.zzz.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
                    .widgetAccentable()
            }

            Text("No one is fronting")
                .font(.subheadline.weight(.semibold))

            Text(entry.totalAlters == 0
                 ? "Add alters in the app to get started."
                 : "Tap Add to start a new session.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var addButton: some View {
        Link(destination: addURL) {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                Text(buttonTitle)
                    .lineLimit(1)
            }
            .font(.caption.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(accent, in: Capsule())
            .foregroundStyle(.white)
            .widgetAccentable()
        }
        .accessibilityLabel(entry.totalAlters == 0 ? "Open AlterEgo" : "Add a fronting alter")
    }

    private var buttonTitle: String {
        if entry.totalAlters == 0 { return "Open AlterEgo" }
        return entry.fronters.isEmpty ? "Start Fronting" : "Add Fronter"
    }
}

struct WidgetBackground: View {
    let alter: Alter?
    let accentHex: String

    var body: some View {
        let color = Color(hex: alter?.bannerColorHex ?? alter?.colorHex ?? accentHex)

        ZStack {
            LinearGradient(
                colors: [color.opacity(0.48), color.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [color.opacity(0.34), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 170
            )

            DiagonalStripes(color: color.opacity(0.18), spacing: 16)
                .opacity(0.35)
        }
    }
}
