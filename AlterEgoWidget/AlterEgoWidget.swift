import WidgetKit
import SwiftUI
import AppIntents

struct Fronter: Identifiable {
    let alter: Alter
    let session: FrontingSession

    var id: UUID { session.id }
}

struct WidgetTimelineSegment: Identifiable {
    let id: UUID
    let start: Date
    let end: Date
    let mode: FrontingMode
}

struct WidgetTimelineRow: Identifiable {
    let alter: Alter
    let segments: [WidgetTimelineSegment]

    var id: UUID { alter.id }

    var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
    }
}

struct AlterEgoEntry: TimelineEntry {
    let date: Date
    let dayStart: Date
    let dayEnd: Date
    let fronters: [Fronter]
    let rows: [WidgetTimelineRow]
    let totalAlters: Int
    let theme: SharedThemeSnapshot
}

struct AlterEgoProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlterEgoEntry {
        let alter = Alter(name: "Alex", emoji: "🌙", colorHex: Alter.palette[0])
        let now = Date()
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now.addingTimeInterval(86_400)
        let session = FrontingSession(alterID: alter.id, start: now.addingTimeInterval(-5_400), mode: .full)
        let segment = WidgetTimelineSegment(
            id: session.id,
            start: session.start,
            end: now,
            mode: session.mode
        )

        return AlterEgoEntry(
            date: now,
            dayStart: dayStart,
            dayEnd: dayEnd,
            fronters: [Fronter(alter: alter, session: session)],
            rows: [WidgetTimelineRow(alter: alter, segments: [segment])],
            totalAlters: 1,
            theme: .default
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
        let now = Date()
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(86_400)

        let fronters = state.activeSessions
            .compactMap { session -> Fronter? in
                guard let alter = state.alter(withID: session.alterID) else { return nil }
                return Fronter(alter: alter, session: session)
            }
            .sorted { $0.session.start < $1.session.start }

        let sessionsByAlter = Dictionary(grouping: state.sessions, by: \.alterID)
        let rows = state.alters.compactMap { alter -> WidgetTimelineRow? in
            let segments = (sessionsByAlter[alter.id] ?? []).compactMap { session -> WidgetTimelineSegment? in
                let start = max(session.start, dayStart)
                let end = min(session.end ?? now, dayEnd)
                guard end > start else { return nil }
                return WidgetTimelineSegment(
                    id: session.id,
                    start: start,
                    end: end,
                    mode: session.mode
                )
            }

            guard !segments.isEmpty else { return nil }
            return WidgetTimelineRow(
                alter: alter,
                segments: segments.sorted { $0.start < $1.start }
            )
        }
        .sorted { ($0.segments.first?.start ?? now) < ($1.segments.first?.start ?? now) }

        return AlterEgoEntry(
            date: now,
            dayStart: dayStart,
            dayEnd: dayEnd,
            fronters: fronters,
            rows: rows,
            totalAlters: state.alters.count,
            theme: SharedTheme.snapshot
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
                    WidgetBackground(theme: entry.theme)
                }
        }
        .configurationDisplayName("Alter Fronting")
        .description("See who is fronting and today's fronting timeline.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct AlterEgoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    let entry: AlterEgoEntry

    private let addURL = URL(string: "alterego://add-fronter")!

    private var palette: SharedPalette {
        entry.theme.palette(
            isDark: entry.theme.isDark(systemIsDark: colorScheme == .dark, at: entry.date)
        )
    }

    var body: some View {
        let palette = palette

        Group {
            switch family {
            case .systemSmall:
                smallLayout(palette)
            case .systemLarge:
                largeLayout(palette)
            default:
                mediumLayout(palette)
            }
        }
        .foregroundStyle(palette.primaryText.widgetColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func smallLayout(_ palette: SharedPalette) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            header(palette, title: "FRONTING NOW")

            if entry.fronters.isEmpty {
                smallEmptyView(palette)
            } else {
                VStack(spacing: 4) {
                    ForEach(entry.fronters.prefix(3)) { fronter in
                        compactFronterRow(fronter, palette: palette)
                    }

                    if entry.fronters.count > 3 {
                        Text("+\(entry.fronters.count - 3) more")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(palette.secondaryText.widgetColor)
                            .padding(.leading, 25)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func mediumLayout(_ palette: SharedPalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header(palette, title: "TODAY'S TIMELINE")
            timelinePreview(palette, rowLimit: 3, labelWidth: 44, showsAxis: true)
            currentFrontersStrip(palette)
        }
    }

    private func largeLayout(_ palette: SharedPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(palette, title: "TODAY'S FRONTING")
            timelinePreview(palette, rowLimit: 7, labelWidth: 62, showsAxis: true)
            currentFrontersSection(palette)
        }
    }

    private func header(_ palette: SharedPalette, title: String) -> some View {
        HStack(alignment: .center, spacing: 7) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.9)
                    .foregroundStyle(palette.secondaryText.widgetColor)

                Text(headerSubtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(palette.secondaryText.widgetColor.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Link(destination: addURL) {
                Image(systemName: entry.totalAlters == 0 ? "arrow.up.right" : "plus")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 21, height: 21)
                    .background {
                        palette.accent.fill(Circle())
                    }
                    .foregroundStyle(contrastColor(for: palette.accent))
            }
            .accessibilityLabel(entry.totalAlters == 0 ? "Open AlterEgo" : "Add a fronting alter")
        }
    }

    private var headerSubtitle: String {
        if entry.fronters.isEmpty {
            return entry.totalAlters == 0 ? "No alters yet" : "No one fronting"
        }
        return "\(entry.fronters.count) of \(entry.totalAlters) alters"
    }

    private func compactFronterRow(_ fronter: Fronter, palette: SharedPalette) -> some View {
        HStack(spacing: 5) {
            AvatarView(alter: fronter.alter, size: 20)

            Text(fronter.alter.name)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 0)

            modeBadge(fronter.session.mode, palette: palette, compact: true)
        }
        .frame(height: 21)
    }

    private func timelinePreview(
        _ palette: SharedPalette,
        rowLimit: Int,
        labelWidth: CGFloat,
        showsAxis: Bool
    ) -> some View {
        VStack(spacing: 3) {
            if entry.rows.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.accent.widgetColor)

                    Text("No fronting recorded today")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(palette.secondaryText.widgetColor)
                }
                .frame(maxWidth: .infinity, minHeight: 34)
            } else {
                ForEach(entry.rows.prefix(rowLimit)) { row in
                    timelineRow(row, palette: palette, labelWidth: labelWidth)
                }

                if entry.rows.count > rowLimit {
                    Text("+\(entry.rows.count - rowLimit) more alters")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(palette.secondaryText.widgetColor)
                        .padding(.leading, labelWidth)
                }
            }

            if showsAxis {
                timelineAxis(palette, labelWidth: labelWidth)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background {
            palette.surface.fill(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(palette.secondaryText.widgetColor.opacity(0.08), lineWidth: 0.5)
        }
    }

    private func timelineRow(
        _ row: WidgetTimelineRow,
        palette: SharedPalette,
        labelWidth: CGFloat
    ) -> some View {
        HStack(spacing: 4) {
            HStack(spacing: 3) {
                AvatarView(alter: row.alter, size: 11)

                Text(row.alter.name)
                    .font(.system(size: 7.5, weight: .medium))
                    .lineLimit(1)
            }
            .frame(width: labelWidth, alignment: .leading)

            GeometryReader { geometry in
                let width = geometry.size.width

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(palette.primaryText.widgetColor.opacity(0.06))

                    ForEach(row.segments) { segment in
                        let start = xPosition(for: segment.start, width: width)
                        let end = xPosition(for: segment.end, width: width)

                        FrontingBar(
                            color: Color(hex: row.alter.colorHex),
                            mode: segment.mode,
                            cornerRadius: 2,
                            showStripes: entry.theme.showPartialStripes
                        )
                        .frame(width: max(2, end - start), height: 7)
                        .offset(x: start)
                    }

                    if isToday {
                        Rectangle()
                            .fill(palette.primaryText.widgetColor.opacity(0.5))
                            .frame(width: 1, height: 9)
                            .offset(x: xPosition(for: entry.date, width: width))
                    }
                }
            }
            .frame(height: 9)
        }
        .frame(height: 11)
    }

    private func timelineAxis(_ palette: SharedPalette, labelWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text("12a")
            Spacer()
            Text("6a")
            Spacer()
            Text("12p")
            Spacer()
            Text("6p")
            Spacer()
            Text("12a")
        }
        .font(.system(size: 6.5, weight: .medium))
        .foregroundStyle(palette.secondaryText.widgetColor.opacity(0.75))
        .padding(.leading, labelWidth)
    }

    private func currentFrontersStrip(_ palette: SharedPalette) -> some View {
        HStack(spacing: 6) {
            Text("NOW")
                .font(.system(size: 7.5, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(palette.secondaryText.widgetColor)

            if entry.fronters.isEmpty {
                Text("No one is fronting")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(palette.secondaryText.widgetColor)
            } else {
                ForEach(entry.fronters.prefix(4)) { fronter in
                    HStack(spacing: 3) {
                        AvatarView(alter: fronter.alter, size: 13)

                        Text(fronter.alter.name)
                            .font(.system(size: 8.5, weight: .semibold))
                            .lineLimit(1)
                    }
                }

                if entry.fronters.count > 4 {
                    Text("+\(entry.fronters.count - 4)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(palette.secondaryText.widgetColor)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(height: 16)
    }

    private func currentFrontersSection(_ palette: SharedPalette) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("FRONTING NOW")
                .font(.system(size: 8, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(palette.secondaryText.widgetColor)

            if entry.fronters.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.accent.widgetColor)

                    Text("No one is fronting right now")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(palette.secondaryText.widgetColor)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(entry.fronters.prefix(5)) { fronter in
                    HStack(spacing: 7) {
                        AvatarView(alter: fronter.alter, size: 22)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(fronter.alter.name)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)

                            if let role = fronter.alter.displayRole {
                                Text(role)
                                    .font(.system(size: 8))
                                    .foregroundStyle(palette.secondaryText.widgetColor)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)

                        modeBadge(fronter.session.mode, palette: palette, compact: false)

                        Text(elapsedText(for: fronter))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(palette.secondaryText.widgetColor)
                            .monospacedDigit()
                    }
                    .frame(height: 24)
                }

                if entry.fronters.count > 5 {
                    Text("+\(entry.fronters.count - 5) more fronting")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(palette.secondaryText.widgetColor)
                        .padding(.leading, 29)
                }
            }
        }
    }

    private func modeBadge(_ mode: FrontingMode, palette: SharedPalette, compact: Bool) -> some View {
        Text(compact ? mode.shortLabel : mode.label)
            .font(.system(size: 7, weight: .bold))
            .padding(.horizontal, compact ? 3 : 4)
            .padding(.vertical, 2)
            .foregroundStyle(
                mode == .full
                ? palette.accent.widgetColor
                : palette.secondaryText.widgetColor
            )
            .background {
                (mode == .full ? palette.accent : palette.secondaryText)
                    .fill(Capsule())
                    .opacity(mode == .full ? 0.16 : 0.1)
            }
    }

    private func smallEmptyView(_ palette: SharedPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)

            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 20))
                .foregroundStyle(palette.accent.widgetColor)

            Text("No one is fronting")
                .font(.system(size: 11, weight: .semibold))

            Text(entry.totalAlters == 0 ? "Add alters in the app." : "Tap + to start a session.")
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(palette.secondaryText.widgetColor)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private var isToday: Bool {
        entry.dayStart <= entry.date && entry.date < entry.dayEnd
    }

    private func xPosition(for date: Date, width: CGFloat) -> CGFloat {
        let duration = entry.dayEnd.timeIntervalSince(entry.dayStart)
        guard duration > 0 else { return 0 }

        let fraction = date.timeIntervalSince(entry.dayStart) / duration
        return width * CGFloat(min(max(fraction, 0), 1))
    }

    private func elapsedText(for fronter: Fronter) -> String {
        let end = fronter.session.end ?? entry.date
        return end.timeIntervalSince(fronter.session.start).widgetShortDuration
    }
}

struct WidgetBackground: View {
    let theme: SharedThemeSnapshot

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = theme.palette(
            isDark: theme.isDark(systemIsDark: colorScheme == .dark)
        )

        palette.background.fill(Rectangle())
    }
}

extension SharedFill {
    var widgetColor: Color {
        Color(hex: averageHex)
    }

    var widgetGradient: LinearGradient {
        let sorted = stops.sorted { $0.location < $1.location }
        let radians = angle * .pi / 180
        return LinearGradient(
            gradient: Gradient(stops: sorted.map {
                Gradient.Stop(color: Color(hex: $0.hex), location: $0.location)
            }),
            startPoint: UnitPoint(x: 0.5 - cos(radians) / 2, y: 0.5 - sin(radians) / 2),
            endPoint: UnitPoint(x: 0.5 + cos(radians) / 2, y: 0.5 + sin(radians) / 2)
        )
    }

    @ViewBuilder
    func fill<S: Shape>(_ shape: S) -> some View {
        if isGradient {
            shape.fill(widgetGradient)
        } else {
            shape.fill(Color(hex: solidHex))
        }
    }
}

private func contrastColor(for fill: SharedFill) -> Color {
    let hex = fill.averageHex.replacingOccurrences(of: "#", with: "")
    guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return .white }

    let red = Double((value >> 16) & 0xFF) / 255
    let green = Double((value >> 8) & 0xFF) / 255
    let blue = Double(value & 0xFF) / 255
    let luminance = 0.299 * red + 0.587 * green + 0.114 * blue

    return luminance > 0.62 ? Color(hex: "#111114") : .white
}

private extension TimeInterval {
    var widgetShortDuration: String {
        let totalMinutes = Int(max(0, self)) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(max(1, minutes))m"
    }
}
