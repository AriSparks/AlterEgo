import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var store: AppStore

    @State private var now = Date()

    private var days: [TimelineDay] {
        TimelineBuilder.build(state: store.state, now: now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    legend

                    if days.isEmpty {
                        ContentUnavailableView {
                            Label("No history yet", systemImage: "chart.bar.xaxis")
                        } description: {
                            Text("Start fronting an alter and their sessions will appear here.")
                        }
                        .padding(.top, 50)
                    } else {
                        ForEach(days) { day in
                            NavigationLink {
                                TimelineDayDetailView(dayID: day.date)
                            } label: {
                                TimelineDayCard(day: day, now: now)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 1020)
                .frame(maxWidth: .infinity)
            }
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.08), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Timeline")
            .task {
                while !Task.isCancelled {
                    now = Date()
                    try? await Task.sleep(for: .seconds(60))
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 18) {
            LegendSwatch(title: "Fully fronting", isPartial: false)
            LegendSwatch(title: "Partially fronting", isPartial: true)
            Spacer()
            Text("Tap a day to explore")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct LegendSwatch: View {
    let title: String
    let isPartial: Bool

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.primary.opacity(isPartial ? 0.35 : 0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(
                            Color.primary.opacity(0.6),
                            style: StrokeStyle(lineWidth: 1, dash: isPartial ? [3, 2] : [])
                        )
                )
                .frame(width: 24, height: 10)
            Text(title)
        }
    }
}

struct TimelineDay: Identifiable {
    let id: Date
    let date: Date
    let rows: [TimelineRow]
}

struct TimelineRow: Identifiable {
    var id: UUID { alter.id }
    let alter: Alter
    let segments: [TimelineSegment]

    var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
    }
}

struct TimelineSegment: Identifiable {
    let id: UUID
    let start: Date
    let end: Date
    let mode: FrontingMode
    let isOngoing: Bool
}

enum TimelineBuilder {
    static func build(state: AppState, now: Date) -> [TimelineDay] {
        guard !state.sessions.isEmpty else { return [] }

        let calendar = Calendar.current
        let earliest = state.sessions.map(\.start).min() ?? now
        var day = calendar.startOfDay(for: now)
        let firstDay = calendar.startOfDay(for: earliest)

        var days: [TimelineDay] = []
        var dayCount = 0

        while day >= firstDay && dayCount < 366 {
            if let timelineDay = buildDay(day, state: state, now: now) {
                days.append(timelineDay)
            }

            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
            dayCount += 1
        }

        return days
    }

    static func buildDay(_ day: Date, state: AppState, now: Date) -> TimelineDay? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }

        var segmentsByAlter: [UUID: [TimelineSegment]] = [:]

        for session in state.sessions {
            let start = max(session.start, dayStart)
            let end = min(session.end ?? now, dayEnd)
            guard end > start else { continue }
            guard state.alters.contains(where: { $0.id == session.alterID }) else { continue }

            let isOngoing = session.end == nil && end >= now
            segmentsByAlter[session.alterID, default: []].append(
                TimelineSegment(
                    id: session.id,
                    start: start,
                    end: end,
                    mode: session.mode,
                    isOngoing: isOngoing
                )
            )
        }

        guard !segmentsByAlter.isEmpty else { return nil }

        let rows = state.alters.compactMap { alter -> TimelineRow? in
            guard let segments = segmentsByAlter[alter.id]?.sorted(by: { $0.start < $1.start }) else {
                return nil
            }
            return TimelineRow(alter: alter, segments: segments)
        }

        return TimelineDay(id: dayStart, date: dayStart, rows: rows)
    }
}

private struct TimelineDayCard: View {
    let day: TimelineDay
    let now: Date

    private let labelWidth: CGFloat = 118

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(day.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                Color.clear
                    .frame(width: labelWidth, height: 1)

                HStack {
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
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            VStack(spacing: 9) {
                ForEach(day.rows) { row in
                    TimelineRowView(row: row, day: day.date, now: now, labelWidth: labelWidth)
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityHint("Opens the interactive timeline for this day")
    }

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day.date) { return "Today" }
        if calendar.isDateInYesterday(day.date) { return "Yesterday" }
        return day.date.formatted(.dateTime.weekday(.wide))
    }
}

private struct TimelineRowView: View {
    let row: TimelineRow
    let day: Date
    let now: Date
    let labelWidth: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                AvatarView(alter: row.alter, size: 26)
                Text(row.alter.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .frame(width: labelWidth, alignment: .leading)

            GeometryReader { geometry in
                let width = geometry.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))

                    ForEach(1..<4, id: \.self) { index in
                        Rectangle()
                            .fill(Color.primary.opacity(0.07))
                            .frame(width: 1)
                            .offset(x: width * CGFloat(index) / 4)
                    }

                    ForEach(row.segments) { segment in
                        segmentBar(segment, width: width)
                    }

                    if Calendar.current.isDateInToday(day) {
                        nowLine(width: width)
                    }
                }
            }
            .frame(height: 26)
        }
    }

    private func segmentBar(_ segment: TimelineSegment, width: CGFloat) -> some View {
        let dayStart = Calendar.current.startOfDay(for: day)
        let dayDuration: TimeInterval = 24 * 60 * 60

        let startFraction = max(0, min(1, segment.start.timeIntervalSince(dayStart) / dayDuration))
        let endFraction = max(0, min(1, segment.end.timeIntervalSince(dayStart) / dayDuration))

        let x = width * startFraction
        let barWidth = max(3, width * (endFraction - startFraction))
        let color = Color(hex: row.alter.colorHex)
        let radius = min(7, barWidth / 2)

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(color.opacity(segment.mode == .full ? 0.95 : 0.55))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        color,
                        style: StrokeStyle(
                            lineWidth: 1,
                            dash: segment.mode == .partial ? [3, 2] : []
                        )
                    )
            )
            .frame(width: barWidth, height: 20)
            .offset(x: x)
    }

    private func nowLine(width: CGFloat) -> some View {
        let dayStart = Calendar.current.startOfDay(for: day)
        let fraction = max(0, min(1, now.timeIntervalSince(dayStart) / (24 * 60 * 60)))

        return Rectangle()
            .fill(Color.accentColor)
            .frame(width: 2, height: 26)
            .offset(x: width * fraction)
    }
}

struct TimelineDayDetailView: View {
    let dayID: Date

    @EnvironmentObject private var store: AppStore
    @State private var now = Date()
    @State private var selectedMinutes: Double?

    private let hourWidth: CGFloat = 54
    private let labelWidth: CGFloat = 104
    private let rowHeight: CGFloat = 36
    private let rowSpacing: CGFloat = 8
    private let axisHeight: CGFloat = 30

    private var calendar: Calendar { Calendar.current }
    private var dayStart: Date { calendar.startOfDay(for: dayID) }
    private var isToday: Bool { calendar.isDateInToday(dayID) }
    private var day: TimelineDay? {
        TimelineBuilder.buildDay(dayID, state: store.state, now: now)
    }
    private var contentWidth: CGFloat { hourWidth * 24 }
    private var laneAreaHeight: CGFloat {
        guard let day else { return 0 }
        let rows = CGFloat(day.rows.count)
        return rows * rowHeight + max(0, rows - 1) * rowSpacing
    }
    private var timelineHeight: CGFloat { axisHeight + laneAreaHeight }

    private var nowMinutes: Double {
        max(0, min(1440, now.timeIntervalSince(dayStart) / 60))
    }

    private var defaultSelectedMinutes: Double {
        if isToday { return nowMinutes }
        if let first = day?.rows.flatMap(\.segments).map(\.start).min() {
            return max(0, min(1440, first.timeIntervalSince(dayStart) / 60))
        }
        return 720
    }

    private var effectiveSelectedMinutes: Double {
        max(0, min(1440, selectedMinutes ?? defaultSelectedMinutes))
    }

    private var selectedTime: Date {
        dayStart.addingTimeInterval(effectiveSelectedMinutes * 60)
    }

    private var selectedBinding: Binding<Double> {
        Binding(
            get: { effectiveSelectedMinutes },
            set: { selectedMinutes = $0 }
        )
    }

    private var selectedHour: Int {
        min(23, Int(effectiveSelectedMinutes / 60))
    }

    private var frontersAtSelectedTime: [FronterAtTime] {
        guard let day else { return [] }
        return day.rows.compactMap { row in
            guard let segment = row.segments.first(where: { $0.start <= selectedTime && selectedTime < $0.end }) else {
                return nil
            }
            return FronterAtTime(alter: row.alter, segment: segment)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                timelineCard
                scrubberCard

                if let day {
                    alterLegend(day)
                }
            }
            .padding(20)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.10), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        )
        .navigationTitle(title)
        .task {
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private var title: String {
        if isToday { return "Today" }
        if calendar.isDateInYesterday(dayID) { return "Yesterday" }
        return dayID.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedTime, format: .dateTime.hour().minute())
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("Selected time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(dayID, format: .dateTime.weekday(.wide).month(.abbreviated).day().year())
                        .font(.subheadline.weight(.semibold))
                    if let day {
                        Text("\(day.rows.count) alter\(day.rows.count == 1 ? "" : "s") tracked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if frontersAtSelectedTime.isEmpty {
                Label("No one is fronting at this time", systemImage: "moon.zzz")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(frontersAtSelectedTime) { fronter in
                        FronterAtTimeRow(fronter: fronter)
                    }
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Day timeline")
                    .font(.headline)
                Spacer()
                Text("Scroll the day or drag the scrubber")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let day {
                HStack(alignment: .top, spacing: 10) {
                    labelColumn(day)
                    timeline(day)
                }
            } else {
                ContentUnavailableView {
                    Label("No sessions", systemImage: "moon.zzz")
                } description: {
                    Text("There were no fronting sessions recorded on this day.")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private func labelColumn(_ day: TimelineDay) -> some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            Color.clear
                .frame(height: axisHeight)

            ForEach(day.rows) { row in
                HStack(spacing: 8) {
                    AvatarView(alter: row.alter, size: 26)
                    Text(row.alter.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
                .frame(width: labelWidth, height: rowHeight, alignment: .leading)
            }
        }
        .frame(width: labelWidth, alignment: .leading)
    }

    private func timeline(_ day: TimelineDay) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: rowSpacing) {
                        axis

                        ForEach(day.rows) { row in
                            lane(row)
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)

                    if isToday {
                        nowLine
                    }

                    selectedLine
                }
                .frame(width: contentWidth, height: timelineHeight, alignment: .topLeading)
                .padding(.trailing, 18)
            }
            .onAppear {
                Task { @MainActor in
                    proxy.scrollTo("hour-\(selectedHour)", anchor: .center)
                }
            }
        }
    }

    private var axis: some View {
        HStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                ZStack(alignment: .leading) {
                    if hour % 2 == 0 {
                        Text(hourLabel(hour))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: hourWidth, height: axisHeight, alignment: .leading)
                .id("hour-\(hour)")
            }
        }
        .frame(width: contentWidth, height: axisHeight, alignment: .leading)
        .overlay(alignment: .trailing) {
            Text("12a")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func lane(_ row: TimelineRow) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.055))

            Canvas { context, size in
                for hour in 0...24 {
                    let x = size.width * CGFloat(hour) / 24
                    let isMajor = hour % 6 == 0
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(
                        path,
                        with: .color(Color.primary.opacity(isMajor ? 0.13 : 0.06)),
                        lineWidth: 1
                    )
                }
            }

            ForEach(row.segments) { segment in
                segmentBar(segment, alter: row.alter)
            }
        }
        .frame(width: contentWidth, height: rowHeight)
    }

    private func segmentBar(_ segment: TimelineSegment, alter: Alter) -> some View {
        let startFraction = max(0, min(1, segment.start.timeIntervalSince(dayStart) / (24 * 60 * 60)))
        let endFraction = max(0, min(1, segment.end.timeIntervalSince(dayStart) / (24 * 60 * 60)))
        let x = contentWidth * startFraction
        let barWidth = max(4, contentWidth * (endFraction - startFraction))
        let color = Color(hex: alter.colorHex)
        let radius = min(8, barWidth / 2)

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(segment.mode == .full ? 1 : 0.68),
                        color.opacity(segment.mode == .full ? 0.82 : 0.48)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        color.opacity(0.9),
                        style: StrokeStyle(
                            lineWidth: 1,
                            dash: segment.mode == .partial ? [4, 3] : []
                        )
                    )
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(0.22))
                    .frame(height: 1)
                    .padding(.horizontal, 2)
            }
            .frame(width: barWidth, height: 28)
            .offset(x: x)
            .accessibilityLabel(
                "\(alter.name), \(segment.mode.label), \(timeRange(for: segment))"
            )
    }

    private var nowLine: some View {
        let fraction = max(0, min(1, now.timeIntervalSince(dayStart) / (24 * 60 * 60)))

        return Rectangle()
            .fill(Color.accentColor)
            .frame(width: 2, height: laneAreaHeight)
            .offset(x: contentWidth * fraction - 1, y: axisHeight)
    }

    private var selectedLine: some View {
        let fraction = effectiveSelectedMinutes / 1440

        return ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.78))
                .frame(width: 2, height: laneAreaHeight)

            Circle()
                .fill(Color.primary)
                .frame(width: 10, height: 10)
                .offset(y: -5)
        }
        .offset(x: contentWidth * fraction - 1, y: axisHeight)
    }

    private var scrubberCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Scrub the day")
                    .font(.headline)
                Spacer()
                Text(selectedTime, format: .dateTime.hour().minute())
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            Slider(value: selectedBinding, in: 0...1440, step: 1)
                .tint(Color.accentColor)

            HStack {
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
            .font(.caption2)
            .foregroundStyle(.secondary)

            if isToday {
                HStack {
                    Spacer()
                    Button("Jump to now") {
                        selectedMinutes = nowMinutes
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private func alterLegend(_ day: TimelineDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alters")
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(day.rows) { row in
                    HStack(spacing: 8) {
                        AvatarView(alter: row.alter, size: 26)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.alter.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(shortDuration(row.totalDuration))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        Circle()
                            .fill(Color(hex: row.alter.colorHex))
                            .frame(width: 10, height: 10)
                    }
                    .padding(8)
                    .background(
                        Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private func hourLabel(_ hour: Int) -> String {
        let suffix = hour < 12 ? "a" : "p"
        let display = hour % 12 == 0 ? 12 : hour % 12
        return "\(display)\(suffix)"
    }

    private func timeRange(for segment: TimelineSegment) -> String {
        let start = segment.start.formatted(.dateTime.hour().minute())
        let end = segment.isOngoing
            ? "now"
            : segment.end.formatted(.dateTime.hour().minute())
        return "\(start) to \(end)"
    }
}

private struct FronterAtTime: Identifiable {
    var id: UUID { alter.id }
    let alter: Alter
    let segment: TimelineSegment
}

private struct FronterAtTimeRow: View {
    let fronter: FronterAtTime

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(alter: fronter.alter, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(fronter.alter.name)
                    .font(.subheadline.weight(.semibold))
                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            StatusBadge(mode: fronter.segment.mode, compact: true)
        }
        .padding(10)
        .background(
            Color(hex: fronter.alter.colorHex).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var timeRange: String {
        let start = fronter.segment.start.formatted(.dateTime.hour().minute())
        let end = fronter.segment.isOngoing
            ? "now"
            : fronter.segment.end.formatted(.dateTime.hour().minute())
        return "\(start) – \(end)"
    }
}
