import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.themePalette) private var palette

    @State private var now = Date()
    @State private var isAddingEntry = false

    private var days: [TimelineDay] {
        TimelineBuilder.build(state: store.state, now: now, calendar: theme.timelineCalendar)
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
            .background(ThemedBackground(fill: palette.background))
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingEntry = true
                    } label: {
                        Label("Add Entry", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingEntry) {
                SessionEditorView(session: nil, defaultStart: Date())
            }
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
            FrontingLegendItem(title: "Fully fronting", mode: .full)
            FrontingLegendItem(title: "Partially fronting", mode: .partial)
            Spacer()
            Text("Tap a day to explore")
                .font(.caption)
                .foregroundStyle(palette.secondaryText.color)
        }
        .font(.caption)
        .foregroundStyle(palette.secondaryText.color)
    }
}

struct FrontingLegendItem: View {
    let title: String
    let mode: FrontingMode

    @Environment(\.themePalette) private var palette

    var body: some View {
        HStack(spacing: 6) {
            FrontingBar(
                color: palette.accent.color,
                mode: mode,
                cornerRadius: 4,
                showStripes: mode == .partial
            )
            .frame(width: 26, height: 11)
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
    static func build(
        state: AppState,
        now: Date,
        calendar: Calendar = .current
    ) -> [TimelineDay] {
        guard !state.sessions.isEmpty else { return [] }

        let earliest = state.sessions.map(\.start).min() ?? now
        var day = calendar.startOfDay(for: now)
        let firstDay = calendar.startOfDay(for: earliest)

        var days: [TimelineDay] = []
        var dayCount = 0

        while day >= firstDay && dayCount < 366 {
            if let timelineDay = buildDay(day, state: state, now: now, calendar: calendar) {
                days.append(timelineDay)
            }

            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
            dayCount += 1
        }

        return days
    }

    static func buildDay(
        _ day: Date,
        state: AppState,
        now: Date,
        calendar: Calendar = .current
    ) -> TimelineDay? {
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

    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.themePalette) private var palette

    private let labelWidth: CGFloat = 118

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText.color)
                Spacer()
                Text(day.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText.color)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText.color.opacity(0.6))
            }

            HStack(spacing: 10) {
                Color.clear
                    .frame(width: labelWidth, height: 1)

                HStack {
                    Text(theme.hourLabel(0))
                    Spacer()
                    Text(theme.hourLabel(6))
                    Spacer()
                    Text(theme.hourLabel(12))
                    Spacer()
                    Text(theme.hourLabel(18))
                    Spacer()
                    Text(theme.hourLabel(24))
                }
                .font(.caption2)
                .foregroundStyle(palette.secondaryText.color)
            }

            VStack(spacing: 9) {
                ForEach(day.rows) { row in
                    TimelineRowView(row: row, day: day.date, now: now, labelWidth: labelWidth)
                }
            }
        }
        .padding(18)
        .background(ThemedCardBackground(fill: palette.surface, cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(palette.primaryText.color.opacity(0.07), lineWidth: 1)
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

    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.themePalette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                AvatarView(alter: row.alter, size: 26)
                Text(row.alter.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(palette.primaryText.color)
            }
            .frame(width: labelWidth, alignment: .leading)

            GeometryReader { geometry in
                let width = geometry.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.primaryText.color.opacity(0.06))

                    ForEach(1..<4, id: \.self) { index in
                        Rectangle()
                            .fill(palette.primaryText.color.opacity(0.07))
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

        return FrontingBar(
            color: Color(hex: row.alter.colorHex),
            mode: segment.mode,
            cornerRadius: min(7, barWidth / 2),
            showStripes: !theme.settings.hidePartialStripes
        )
        .frame(width: barWidth, height: 20)
        .offset(x: x)
    }

    private func nowLine(width: CGFloat) -> some View {
        let dayStart = Calendar.current.startOfDay(for: day)
        let fraction = max(0, min(1, now.timeIntervalSince(dayStart) / (24 * 60 * 60)))

        return Rectangle()
            .fill(palette.accent.color)
            .frame(width: 2, height: 26)
            .offset(x: width * fraction)
    }
}

struct TimelineDayDetailView: View {
    let dayID: Date

    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.themePalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentDay: Date
    @State private var now = Date()
    @State private var selectedMinutes: Double?
    @State private var previousScrub: Double?
    @State private var editingSession: FrontingSession?
    @State private var isAddingEntry = false

    init(dayID: Date) {
        self.dayID = dayID
        _currentDay = State(initialValue: Calendar.current.startOfDay(for: dayID))
    }

    private var calendar: Calendar { theme.timelineCalendar }
    private var dayStart: Date { calendar.startOfDay(for: currentDay) }
    private var isToday: Bool { calendar.isDateInToday(currentDay) }

    private var day: TimelineDay? {
        TimelineBuilder.buildDay(currentDay, state: store.state, now: now, calendar: calendar)
    }

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

    private var frontersAtSelectedTime: [FronterAtTime] {
        guard let day else { return [] }
        return day.rows.compactMap { row in
            guard let segment = row.segments.first(where: {
                $0.start <= selectedTime && selectedTime < $0.end
            }) else {
                return nil
            }
            return FronterAtTime(alter: row.alter, segment: segment)
        }
    }

    private var boundaryMinutes: [Double] {
        guard let day else { return [] }
        return day.rows.flatMap { row in
            row.segments.flatMap { segment in
                [
                    segment.start.timeIntervalSince(dayStart) / 60,
                    segment.end.timeIntervalSince(dayStart) / 60
                ]
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                readout

                timelineSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                legend
            }
            .padding(.horizontal, geometry.size.width > 800 ? 28 : 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(ThemedBackground(fill: palette.background))
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    moveDay(-1)
                } label: {
                    Label("Previous Day", systemImage: "chevron.left")
                }

                Button {
                    moveDay(1)
                } label: {
                    Label("Next Day", systemImage: "chevron.right")
                }
                .disabled(isToday)

                Button {
                    isAddingEntry = true
                } label: {
                    Label("Add Entry", systemImage: "plus")
                }
            }
        }
        .task {
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .sheet(item: $editingSession) { session in
            SessionEditorView(session: session, defaultStart: selectedTime)
        }
        .sheet(isPresented: $isAddingEntry) {
            SessionEditorView(session: nil, defaultStart: defaultStartForNewEntry)
        }
        .onChange(of: currentDay) { _, _ in
            selectedMinutes = nil
            previousScrub = nil
        }
    }

    private var title: String {
        if isToday { return "Today" }
        if calendar.isDateInYesterday(currentDay) { return "Yesterday" }
        return currentDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var defaultStartForNewEntry: Date {
        if isToday { return min(Date(), selectedTime) }
        return min(Date(), dayStart.addingTimeInterval(12 * 60 * 60))
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(theme.timeString(selectedTime))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(palette.primaryText.color)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(currentDay, format: .dateTime.weekday(.wide).month(.abbreviated).day().year())
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText.color)
                }

                Spacer(minLength: 12)

                if let day {
                    Text("\(day.rows.count) alter\(day.rows.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText.color)
                }
            }

            if frontersAtSelectedTime.isEmpty {
                Label("No one is fronting at this time", systemImage: "moon.zzz")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText.color)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(frontersAtSelectedTime) { fronter in
                            HStack(spacing: 7) {
                                AvatarView(alter: fronter.alter, size: 24)
                                Text(fronter.alter.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(palette.primaryText.color)
                                StatusBadge(mode: fronter.segment.mode, compact: true)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                palette.surface.fill(Capsule())
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color(hex: fronter.alter.colorHex).opacity(0.45), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var timelineSection: some View {
        if let day {
            GeometryReader { geometry in
                let labelWidth = min(104, max(64, geometry.size.width * 0.18))
                let chartWidth = max(120, geometry.size.width - labelWidth)
                let axisHeight: CGFloat = 26
                let rowSpacing: CGFloat = 7
                let rowCount = max(1, day.rows.count)
                let available = max(70, geometry.size.height - axisHeight - 8)
                let laneHeight = min(
                    48,
                    max(20, (available - rowSpacing * CGFloat(rowCount - 1)) / CGFloat(rowCount))
                )

                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Color.clear
                                .frame(width: labelWidth, height: axisHeight)

                            axisView(width: chartWidth)
                        }

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: rowSpacing) {
                                ForEach(day.rows) { row in
                                    HStack(spacing: 0) {
                                        rowLabel(row)
                                            .frame(width: labelWidth, height: laneHeight, alignment: .leading)

                                        laneView(
                                            row,
                                            chartWidth: chartWidth,
                                            laneHeight: laneHeight
                                        )
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: .infinity)
                    }

                    if isToday {
                        verticalLine(
                            x: labelWidth + chartWidth * CGFloat(nowMinutes / 1440),
                            top: axisHeight,
                            height: max(0, geometry.size.height - axisHeight),
                            color: palette.accent.color,
                            width: 2
                        )
                    }

                    selectedLine(
                        x: labelWidth + chartWidth * CGFloat(effectiveSelectedMinutes / 1440),
                        top: axisHeight,
                        height: max(0, geometry.size.height - axisHeight)
                    )
                }
                .contentShape(Rectangle())
                .gesture(scrubGesture(labelWidth: labelWidth, chartWidth: chartWidth))
            }
        } else {
            ContentUnavailableView {
                Label("No sessions", systemImage: "moon.zzz")
            } description: {
                Text("There were no fronting sessions recorded on this day.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func axisView(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0...4, id: \.self) { index in
                if index > 0 { Spacer(minLength: 0) }
                Text(theme.hourLabel(index * 6))
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryText.color)
            }
        }
        .frame(width: width, height: 26, alignment: .leading)
    }

    private func rowLabel(_ row: TimelineRow) -> some View {
        HStack(spacing: 6) {
            AvatarView(alter: row.alter, size: 24)
            Text(row.alter.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(palette.primaryText.color)
        }
        .padding(.trailing, 6)
    }

    private func laneView(
        _ row: TimelineRow,
        chartWidth: CGFloat,
        laneHeight: CGFloat
    ) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(palette.primaryText.color.opacity(0.055))

            Canvas { context, size in
                for hour in 0...24 {
                    let x = size.width * CGFloat(hour) / 24
                    let isMajor = hour % 6 == 0
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(
                        path,
                        with: .color(palette.primaryText.color.opacity(isMajor ? 0.13 : 0.06)),
                        lineWidth: 1
                    )
                }
            }

            ForEach(row.segments) { segment in
                segmentBar(segment, alter: row.alter, chartWidth: chartWidth, laneHeight: laneHeight)
            }
        }
        .frame(width: chartWidth, height: laneHeight)
    }

    private func segmentBar(
        _ segment: TimelineSegment,
        alter: Alter,
        chartWidth: CGFloat,
        laneHeight: CGFloat
    ) -> some View {
        let startFraction = max(0, min(1, segment.start.timeIntervalSince(dayStart) / (24 * 60 * 60)))
        let endFraction = max(0, min(1, segment.end.timeIntervalSince(dayStart) / (24 * 60 * 60)))
        let x = chartWidth * startFraction
        let barWidth = max(4, chartWidth * (endFraction - startFraction))

        return FrontingBar(
            color: Color(hex: alter.colorHex),
            mode: segment.mode,
            cornerRadius: min(8, barWidth / 2),
            showStripes: !theme.settings.hidePartialStripes
        )
        .frame(width: barWidth, height: max(10, laneHeight - 8))
        .offset(x: x, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            editingSession = store.state.sessions.first { $0.id == segment.id }
        }
        .accessibilityLabel("\(alter.name), \(segment.mode.label)")
        .accessibilityHint("Opens this entry for editing")
    }

    private func verticalLine(
        x: CGFloat,
        top: CGFloat,
        height: CGFloat,
        color: Color,
        width: CGFloat
    ) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: height)
            .offset(x: x - width / 2, y: top)
            .allowsHitTesting(false)
    }

    private func selectedLine(x: CGFloat, top: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(palette.primaryText.color.opacity(0.72))
                .frame(width: 2, height: height)

            Circle()
                .fill(palette.accent.color)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(palette.primaryText.color.opacity(0.65), lineWidth: 1.5))
                .offset(y: -6)
        }
        .offset(x: x - 1, y: top)
        .allowsHitTesting(false)
    }

    private func scrubGesture(labelWidth: CGFloat, chartWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let x = value.location.x - labelWidth
                let fraction = max(0, min(1, x / chartWidth))
                let minutes = Double(fraction) * 1440

                if let previousScrub {
                    let lower = min(previousScrub, minutes)
                    let upper = max(previousScrub, minutes)
                    if boundaryMinutes.contains(where: { $0 > lower && $0 <= upper }) {
                        Haptics.selection()
                    }
                }

                previousScrub = minutes
                selectedMinutes = minutes
            }
            .onEnded { _ in
                previousScrub = nil
            }
    }

    private func moveDay(_ offset: Int) {
        guard let next = calendar.date(byAdding: .day, value: offset, to: currentDay) else { return }
        let today = calendar.startOfDay(for: Date())
        currentDay = min(next, today)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            FrontingLegendItem(title: "Full", mode: .full)
            FrontingLegendItem(title: "Partial", mode: .partial)
            Spacer()
            Text("Drag across the timeline to scrub")
                .font(.caption2)
                .foregroundStyle(palette.secondaryText.color)
        }
        .font(.caption)
        .padding(.top, 6)
    }
}

private struct FronterAtTime: Identifiable {
    var id: UUID { alter.id }
    let alter: Alter
    let segment: TimelineSegment
}
