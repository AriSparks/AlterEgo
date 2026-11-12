import SwiftUI

enum TimelineRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case sixMonths

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .sixMonths: return "6 Months"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .day
        case .month: return .month
        case .sixMonths: return .month
        }
    }

    var step: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 1
        case .sixMonths: return 6
        }
    }
}

private struct TimelineBounds {
    let start: Date
    let end: Date
}

struct TimelineView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.themePalette) private var palette

    @State private var now = Date()
    @State private var range: TimelineRange = .day
    @State private var anchor = Calendar.current.startOfDay(for: Date())
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var selectedMinutes: Double?
    @State private var previousScrub: Double?
    @State private var isAddingEntry = false
    @State private var editingSession: FrontingSession?

    private var calendar: Calendar { theme.timelineCalendar }

    private var rangeBounds: TimelineBounds {
        bounds(for: range, anchor: anchor)
    }

    private var activeDay: Date {
        if range == .day {
            return calendar.startOfDay(for: anchor)
        }

        let bounds = rangeBounds
        let candidate = calendar.startOfDay(for: selectedDay)
        if candidate >= bounds.start && candidate < bounds.end {
            return candidate
        }
        if now >= bounds.start && now < bounds.end {
            return calendar.startOfDay(for: now)
        }
        return calendar.startOfDay(for: bounds.end.addingTimeInterval(-1))
    }

    private var activeDayStart: Date {
        calendar.startOfDay(for: activeDay)
    }

    private var dayData: TimelineDay? {
        TimelineBuilder.buildDay(
            activeDayStart,
            state: store.state,
            now: now,
            calendar: calendar
        )
    }

    private var summaries: [TimelineAlterSummary] {
        guard let dayData else { return [] }
        return TimelineBuilder.summaries(for: dayData)
    }

    private var effectiveSelectedMinutes: Double {
        min(1_439.5, max(0, selectedMinutes ?? defaultSelectedMinutes))
    }

    private var defaultSelectedMinutes: Double {
        if calendar.isDate(activeDay, inSameDayAs: now) {
            return min(1_439.5, max(0, now.timeIntervalSince(activeDayStart) / 60))
        }
        if let first = dayData?.rows.flatMap(\.segments).map(\.start).min() {
            return min(1_439.5, max(0, first.timeIntervalSince(activeDayStart) / 60))
        }
        return 12 * 60
    }

    private var selectedTime: Date {
        activeDayStart.addingTimeInterval(effectiveSelectedMinutes * 60)
    }

    private var frontersAtSelectedTime: [FronterAtTime] {
        guard let dayData else { return [] }
        return dayData.rows.compactMap { row in
            guard let segment = row.segments.first(where: {
                let endTolerance = $0.isOngoing ? 0.5 : 0
                return $0.start <= selectedTime && selectedTime < $0.end.addingTimeInterval(endTolerance)
            }) else {
                return nil
            }
            return FronterAtTime(alter: row.alter, segment: segment)
        }
    }

    private var boundaryMinutes: [Double] {
        guard let dayData else { return [] }
        return dayData.rows.flatMap { row in
            row.segments.flatMap { segment in
                [
                    segment.start.timeIntervalSince(activeDayStart) / 60,
                    segment.end.timeIntervalSince(activeDayStart) / 60
                ]
            }
        }
    }

    private var canGoForward: Bool {
        rangeBounds.end <= calendar.startOfDay(for: now)
    }

    private var isCurrentPeriod: Bool {
        let bounds = rangeBounds
        return now >= bounds.start && now < bounds.end
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    rangePicker
                    periodHeader
                    chartSection
                    readout
                    dailySummary
                    legend
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 900)
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
                SessionEditorView(session: nil, defaultStart: defaultStartForNewEntry)
            }
            .sheet(item: $editingSession) { session in
                SessionEditorView(session: session, defaultStart: selectedTime)
            }
            .task {
                while !Task.isCancelled {
                    now = Date()
                    try? await Task.sleep(for: .seconds(60))
                }
            }
            .onChange(of: range) { _, _ in
                let day = min(calendar.startOfDay(for: selectedDay), calendar.startOfDay(for: now))
                anchor = day
                selectedDay = day
                selectedMinutes = nil
                previousScrub = nil
            }
        }
    }

    private var rangePicker: some View {
        Picker("Timeline Range", selection: $range) {
            ForEach(TimelineRange.allCases) { timelineRange in
                Text(timelineRange.title).tag(timelineRange)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var periodHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(periodTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.primaryText.color)

                Text(periodSubtitle)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText.color)
            }

            Spacer(minLength: 0)

            if !isCurrentPeriod {
                Button("Today") {
                    anchor = calendar.startOfDay(for: now)
                    selectedDay = calendar.startOfDay(for: now)
                    selectedMinutes = nil
                    previousScrub = nil
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.accent.color)
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                periodButton(
                    systemImage: "chevron.left",
                    label: "Previous \(range.title)",
                    disabled: false
                ) {
                    shift(-1)
                }

                periodButton(
                    systemImage: "chevron.right",
                    label: "Next \(range.title)",
                    disabled: !canGoForward
                ) {
                    shift(1)
                }
            }
        }
    }

    private func periodButton(
        systemImage: String,
        label: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .frame(width: 28, height: 28)
                .background {
                    palette.surface.fill(Circle())
                }
                .foregroundStyle(
                    disabled
                    ? palette.secondaryText.color.opacity(0.35)
                    : palette.primaryText.color
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var chartSection: some View {
        switch range {
        case .day:
            if let dayData, !dayData.rows.isEmpty {
                dayChart(dayData)
            } else {
                emptyChart(
                    title: "No fronting on this day",
                    message: "Sessions recorded on this day will appear here."
                )
            }
        case .week:
            weekChart
        case .month:
            monthHeatmapCard(monthStart: rangeBounds.start, compact: false)
        case .sixMonths:
            sixMonthMaps
        }
    }

    private func dayChart(_ day: TimelineDay) -> some View {
        let rowSpacing: CGFloat = 6
        let laneHeight: CGFloat = 25
        let axisHeight: CGFloat = 18
        let rowsHeight = CGFloat(day.rows.count) * laneHeight
            + CGFloat(max(0, day.rows.count - 1)) * rowSpacing
        let contentHeight = axisHeight + 6 + rowsHeight

        return GeometryReader { geometry in
            let labelWidth = min(126, max(82, geometry.size.width * 0.23))
            let chartWidth = max(80, geometry.size.width - labelWidth)
            let nowFraction = nowMinutesFraction
            let selectedFraction = effectiveSelectedMinutes / 1_440

            VStack(alignment: .leading, spacing: 0) {
                hourAxis(labelWidth: labelWidth, chartWidth: chartWidth)
                    .frame(height: axisHeight)

                Spacer(minLength: 0)
                    .frame(height: 6)

                ZStack(alignment: .topLeading) {
                    VStack(spacing: rowSpacing) {
                        ForEach(day.rows) { row in
                            dayRow(
                                row,
                                labelWidth: labelWidth,
                                chartWidth: chartWidth,
                                laneHeight: laneHeight
                            )
                        }
                    }

                    if isSelectedDayToday {
                        verticalLine(
                            x: labelWidth + chartWidth * nowFraction,
                            height: rowsHeight,
                            color: palette.accent.color.opacity(0.75),
                            width: 1.5
                        )
                    }

                    selectedTimeLine(
                        x: labelWidth + chartWidth * selectedFraction,
                        height: rowsHeight
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(dayScrubGesture(labelWidth: labelWidth, chartWidth: chartWidth))
        }
        .frame(height: contentHeight)
        .padding(12)
        .background {
            ThemedCardBackground(fill: palette.surface, cornerRadius: 20)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(palette.primaryText.color.opacity(0.06), lineWidth: 1)
        }
    }

    private func hourAxis(labelWidth: CGFloat, chartWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: labelWidth)

            HStack(spacing: 0) {
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
            .frame(width: chartWidth)
        }
        .font(.caption2)
        .foregroundStyle(palette.secondaryText.color)
    }

    private func dayRow(
        _ row: TimelineRow,
        labelWidth: CGFloat,
        chartWidth: CGFloat,
        laneHeight: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                AvatarView(alter: row.alter, size: 24)

                Text(row.alter.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(palette.primaryText.color)
            }
            .frame(width: labelWidth, height: laneHeight, alignment: .leading)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.primaryText.color.opacity(0.055))

                hourGrid()

                ForEach(row.segments) { segment in
                    segmentBar(
                        segment,
                        alter: row.alter,
                        dayStart: activeDayStart,
                        chartWidth: chartWidth,
                        height: max(10, laneHeight - 8)
                    )
                }
            }
            .frame(width: chartWidth, height: laneHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var weekChart: some View {
        let days = TimelineBuilder.buildDays(
            from: rangeBounds.start,
            to: rangeBounds.end,
            state: store.state,
            now: now,
            calendar: calendar
        )
        let rowHeight: CGFloat = 30
        let rowSpacing: CGFloat = 4
        let axisHeight: CGFloat = 16
        let contentHeight = axisHeight
            + CGFloat(days.count) * (rowHeight + rowSpacing)

        return GeometryReader { geometry in
            let labelWidth = min(70, max(52, geometry.size.width * 0.16))
            let chartWidth = max(80, geometry.size.width - labelWidth)
            let selectedFraction = effectiveSelectedMinutes / 1_440

            VStack(spacing: rowSpacing) {
                weekAxis(labelWidth: labelWidth, chartWidth: chartWidth)
                    .frame(height: axisHeight)

                ForEach(days) { day in
                    weekRow(
                        day,
                        labelWidth: labelWidth,
                        chartWidth: chartWidth,
                        rowHeight: rowHeight
                    )
                }
            }
            .overlay(alignment: .topLeading) {
                selectedTimeLine(
                    x: labelWidth + chartWidth * selectedFraction,
                    height: max(0, geometry.size.height - axisHeight - rowSpacing)
                )
                .offset(y: axisHeight + rowSpacing)
            }
            .contentShape(Rectangle())
            .gesture(
                weekScrubGesture(
                    labelWidth: labelWidth,
                    chartWidth: chartWidth,
                    rowHeight: rowHeight,
                    rowSpacing: rowSpacing,
                    axisHeight: axisHeight,
                    days: days
                )
            )
        }
        .frame(height: contentHeight)
        .padding(12)
        .background {
            ThemedCardBackground(fill: palette.surface, cornerRadius: 20)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(palette.primaryText.color.opacity(0.06), lineWidth: 1)
        }
    }

    private func weekAxis(labelWidth: CGFloat, chartWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: labelWidth)

            HStack(spacing: 0) {
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
            .frame(width: chartWidth)
        }
        .font(.system(size: 8))
        .foregroundStyle(palette.secondaryText.color)
    }

    private func weekRow(
        _ day: TimelineDay,
        labelWidth: CGFloat,
        chartWidth: CGFloat,
        rowHeight: CGFloat
    ) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: activeDay)
        let isToday = calendar.isDateInToday(day.date)
        let visibleRows = Array(day.rows.prefix(5))
        let laneHeight = visibleRows.isEmpty
            ? 3
            : min(5, max(2, 24 / CGFloat(visibleRows.count)))
        let lanesHeight = CGFloat(visibleRows.count) * laneHeight
            + CGFloat(max(0, visibleRows.count - 1))
        let laneStart = max(0, (rowHeight - lanesHeight) / 2)

        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(palette.secondaryText.color)

                Text(day.date.formatted(.dateTime.day()))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(palette.primaryText.color)
            }
            .frame(width: labelWidth, height: rowHeight, alignment: .leading)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isSelected
                        ? palette.accent.color.opacity(0.12)
                        : palette.primaryText.color.opacity(0.045)
                    )

                hourGrid()

                ForEach(Array(visibleRows.enumerated()), id: \.element.id) { index, row in
                    ForEach(row.segments) { segment in
                        segmentBar(
                            segment,
                            alter: row.alter,
                            dayStart: day.date,
                            chartWidth: chartWidth,
                            height: laneHeight
                        )
                        .offset(y: laneStart + CGFloat(index) * (laneHeight + 1))
                    }
                }

                if isToday {
                    let fraction = min(
                        1,
                        max(0, now.timeIntervalSince(day.date) / 86_400)
                    )

                    verticalLine(
                        x: chartWidth * CGFloat(fraction),
                        height: rowHeight,
                        color: palette.accent.color.opacity(0.7),
                        width: 1
                    )
                }
            }
            .frame(width: chartWidth, height: rowHeight)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isSelected ? palette.accent.color.opacity(0.55) : .clear,
                        lineWidth: 1
                    )
            }
            .onTapGesture {
                selectedDay = day.date
            }
        }
    }

    private var sixMonthMaps: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 270), spacing: 12)],
            spacing: 12
        ) {
            ForEach(0..<6, id: \.self) { offset in
                if let monthStart = calendar.date(
                    byAdding: .month,
                    value: offset,
                    to: rangeBounds.start
                ) {
                    monthHeatmapCard(monthStart: monthStart, compact: true)
                }
            }
        }
    }

    private func monthHeatmapCard(monthStart: Date, compact: Bool) -> some View {
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)
            ?? monthStart.addingTimeInterval(2_678_400)
        let days = TimelineBuilder.buildDays(
            from: monthStart,
            to: monthEnd,
            state: store.state,
            now: now,
            calendar: calendar
        )
        let leading = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        let cells: [Date?] = Array(repeating: nil, count: leading) + days.map(\.date)
        let weekCount = max(1, Int(ceil(Double(cells.count) / 7)))
        let cellHeight: CGFloat = compact ? 18 : 24
        let dayMap = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
        let activeDays = days.filter { !$0.rows.isEmpty }.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(monthStart.formatted(.dateTime.month(.wide).year()))
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText.color)

                Spacer(minLength: 0)

                if activeDays > 0 {
                    Text("\(activeDays)d")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(palette.secondaryText.color)
                }
            }

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: compact ? 7 : 8, weight: .medium))
                        .foregroundStyle(palette.secondaryText.color)
                        .frame(maxWidth: .infinity)
                }
            }

            GeometryReader { geometry in
                let cellWidth = geometry.size.width / 7

                ZStack(alignment: .topLeading) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { index, date in
                        if let date,
                           let day = dayMap[calendar.startOfDay(for: date)] {
                            monthCell(
                                day,
                                cellWidth: cellWidth,
                                cellHeight: cellHeight,
                                compact: compact
                            )
                            .offset(
                                x: CGFloat(index % 7) * cellWidth,
                                y: CGFloat(index / 7) * cellHeight
                            )
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    monthScrubGesture(
                        days: days,
                        leading: leading,
                        cellWidth: cellWidth,
                        cellHeight: cellHeight
                    )
                )
            }
            .frame(height: CGFloat(weekCount) * cellHeight)
        }
        .padding(12)
        .background {
            ThemedCardBackground(fill: palette.surface, cornerRadius: 18)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(palette.primaryText.color.opacity(0.06), lineWidth: 1)
        }
    }

    private func monthCell(
        _ day: TimelineDay,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        compact: Bool
    ) -> some View {
        let total = day.rows.reduce(0) { $0 + $1.totalDuration }
        let coverage = min(1, total / 86_400)
        let isSelected = calendar.isDate(day.date, inSameDayAs: activeDay)
        let fillOpacity = day.rows.isEmpty ? 0.035 : 0.12 + coverage * 0.48

        return RoundedRectangle(cornerRadius: compact ? 3 : 4, style: .continuous)
            .fill(
                day.rows.isEmpty
                ? palette.primaryText.color.opacity(fillOpacity)
                : palette.accent.color.opacity(fillOpacity)
            )
            .frame(width: max(8, cellWidth - 3), height: max(8, cellHeight - 3))
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 3 : 4, style: .continuous)
                    .strokeBorder(
                        isSelected ? palette.accent.color : .clear,
                        lineWidth: isSelected ? 2 : 0
                    )
            }
            .overlay {
                Text(day.date.formatted(.dateTime.day()))
                    .font(.system(size: compact ? 7 : 9, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(
                        day.rows.isEmpty
                        ? palette.secondaryText.color
                        : palette.primaryText.color
                    )
            }
            .padding(1.5)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedDay = day.date
            }
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(theme.timeString(selectedTime))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(palette.primaryText.color)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(readoutDate)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText.color)
                    .multilineTextAlignment(.trailing)
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
                            .background {
                                palette.surface.fill(Capsule())
                            }
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        Color(hex: fronter.alter.colorHex).opacity(0.45),
                                        lineWidth: 1
                                    )
                            }
                        }
                    }
                }
            }

            if range == .month || range == .sixMonths {
                timeSlider
            }
        }
        .padding(14)
        .background {
            ThemedCardBackground(fill: palette.surface, cornerRadius: 20)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(palette.primaryText.color.opacity(0.06), lineWidth: 1)
        }
    }

    private var timeSlider: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundStyle(palette.secondaryText.color)

            Slider(
                value: Binding(
                    get: { effectiveSelectedMinutes },
                    set: { selectedMinutes = $0 }
                ),
                in: 0...1_439,
                step: 5
            )
            .tint(palette.accent.color)

            Text(theme.timeString(selectedTime))
                .font(.caption.monospacedDigit())
                .foregroundStyle(palette.secondaryText.color)
                .frame(width: 54, alignment: .trailing)
        }
    }

    private var dailySummary: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fronted on \(summaryDate)")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText.color)

                    Text("Full and partial time for this day")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText.color)
                }

                Spacer(minLength: 8)

                if !summaries.isEmpty {
                    Text("\(summaries.count) alter\(summaries.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText.color)
                }
            }

            if summaries.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "moon.zzz")
                        .foregroundStyle(palette.secondaryText.color)

                    Text("No alter fronted on this day.")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText.color)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                        summaryRow(summary)

                        if index < summaries.count - 1 {
                            Divider()
                                .overlay(palette.primaryText.color.opacity(0.06))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background {
                    ThemedCardBackground(fill: palette.surface, cornerRadius: 18)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(palette.primaryText.color.opacity(0.06), lineWidth: 1)
                }
            }
        }
    }

    private func summaryRow(_ summary: TimelineAlterSummary) -> some View {
        HStack(spacing: 10) {
            AvatarView(alter: summary.alter, size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(summary.alter.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(palette.primaryText.color)

                if let role = summary.alter.displayRole {
                    Text(role)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText.color)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if summary.fullDuration > 0 {
                    Text("Full  \(summary.fullDuration.timelineDuration)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(palette.primaryText.color)
                }

                if summary.partialDuration > 0 {
                    Text("Partial  \(summary.partialDuration.timelineDuration)")
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText.color)
                }
            }
            .monospacedDigit()
        }
        .padding(.vertical, 8)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            FrontingLegendItem(title: "Fully fronting", mode: .full)
            FrontingLegendItem(title: "Partially fronting", mode: .partial)
            Spacer(minLength: 0)
            Text(chartHint)
                .font(.caption2)
                .foregroundStyle(palette.secondaryText.color)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
        .foregroundStyle(palette.secondaryText.color)
        .padding(.top, 2)
    }

    private var chartHint: String {
        switch range {
        case .day, .week:
            return "Hold and drag the chart to scrub"
        case .month, .sixMonths:
            return "Hold and drag a day to inspect it"
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    private var nowMinutesFraction: CGFloat {
        guard calendar.isDate(activeDay, inSameDayAs: now) else { return 0 }
        return CGFloat(min(max(now.timeIntervalSince(activeDayStart) / 86_400, 0), 1))
    }

    private var isSelectedDayToday: Bool {
        calendar.isDate(activeDay, inSameDayAs: now)
    }

    private var readoutDate: String {
        activeDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var summaryDate: String {
        activeDay.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var periodTitle: String {
        switch range {
        case .day:
            if calendar.isDateInToday(anchor) { return "Today" }
            if calendar.isDateInYesterday(anchor) { return "Yesterday" }
            return anchor.formatted(.dateTime.weekday(.wide))
        case .week:
            let last = calendar.date(
                byAdding: .day,
                value: -1,
                to: rangeBounds.end
            ) ?? rangeBounds.end

            return "\(rangeBounds.start.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return rangeBounds.start.formatted(.dateTime.month(.wide).year())
        case .sixMonths:
            let last = rangeBounds.end.addingTimeInterval(-1)
            return "\(rangeBounds.start.formatted(.dateTime.month(.abbreviated))) – \(last.formatted(.dateTime.month(.abbreviated).year()))"
        }
    }

    private var periodSubtitle: String {
        switch range {
        case .day:
            return activeDay.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        case .week:
            return "Week overview"
        case .month:
            return "Month overview"
        case .sixMonths:
            return "6 month overview"
        }
    }

    private var defaultStartForNewEntry: Date {
        if calendar.isDateInToday(activeDay) {
            return min(Date(), selectedTime)
        }
        return min(Date(), activeDayStart.addingTimeInterval(12 * 60 * 60))
    }

    private func segmentBar(
        _ segment: TimelineSegment,
        alter: Alter,
        dayStart: Date,
        chartWidth: CGFloat,
        height: CGFloat
    ) -> some View {
        let startFraction = max(
            0,
            min(1, segment.start.timeIntervalSince(dayStart) / 86_400)
        )
        let endFraction = max(
            0,
            min(1, segment.end.timeIntervalSince(dayStart) / 86_400)
        )
        let x = chartWidth * startFraction
        let width = max(3, chartWidth * (endFraction - startFraction))

        return FrontingBar(
            color: Color(hex: alter.colorHex),
            mode: segment.mode,
            cornerRadius: min(7, width / 2),
            showStripes: !theme.settings.hidePartialStripes
        )
        .frame(width: width, height: height)
        .offset(x: x)
        .contentShape(Rectangle())
        .onTapGesture {
            editingSession = store.state.sessions.first { $0.id == segment.id }
        }
        .accessibilityLabel("\(alter.name), \(segment.mode.label)")
        .accessibilityHint("Opens this entry for editing")
    }

    private func hourGrid() -> some View {
        Canvas { context, size in
            for hour in 0...24 {
                let x = size.width * CGFloat(hour) / 24
                let isMajor = hour % 6 == 0
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(
                    path,
                    with: .color(palette.primaryText.color.opacity(isMajor ? 0.12 : 0.05)),
                    lineWidth: 1
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func verticalLine(
        x: CGFloat,
        height: CGFloat,
        color: Color,
        width: CGFloat
    ) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: height)
            .offset(x: x - width / 2)
            .allowsHitTesting(false)
    }

    private func selectedTimeLine(x: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(palette.primaryText.color.opacity(0.72))
                .frame(width: 2, height: height)

            Circle()
                .fill(palette.accent.color)
                .frame(width: 11, height: 11)
                .overlay {
                    Circle()
                        .strokeBorder(palette.primaryText.color.opacity(0.55), lineWidth: 1.5)
                }
                .offset(y: -5)
        }
        .offset(x: x - 1)
        .allowsHitTesting(false)
    }

    private func dayScrubGesture(labelWidth: CGFloat, chartWidth: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.12)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    guard let drag else { return }
                    updateTimeSelection(
                        x: drag.location.x - labelWidth,
                        chartWidth: chartWidth
                    )
                default:
                    break
                }
            }
            .onEnded { _ in
                previousScrub = nil
            }
    }

    private func weekScrubGesture(
        labelWidth: CGFloat,
        chartWidth: CGFloat,
        rowHeight: CGFloat,
        rowSpacing: CGFloat,
        axisHeight: CGFloat,
        days: [TimelineDay]
    ) -> some Gesture {
        LongPressGesture(minimumDuration: 0.12)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    guard let drag, !days.isEmpty else { return }

                    let y = drag.location.y - axisHeight
                    if y >= 0 {
                        let row = min(
                            days.count - 1,
                            max(0, Int(y / (rowHeight + rowSpacing)))
                        )
                        let day = days[row].date

                        if !calendar.isDate(day, inSameDayAs: selectedDay) {
                            selectedDay = day
                            Haptics.selection()
                        }
                    }

                    updateTimeSelection(
                        x: drag.location.x - labelWidth,
                        chartWidth: chartWidth
                    )
                default:
                    break
                }
            }
            .onEnded { _ in
                previousScrub = nil
            }
    }

    private func monthScrubGesture(
        days: [TimelineDay],
        leading: Int,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> some Gesture {
        LongPressGesture(minimumDuration: 0.12)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    guard let drag, !days.isEmpty, cellWidth > 0, cellHeight > 0 else { return }

                    let column = min(6, max(0, Int(drag.location.x / cellWidth)))
                    let row = max(0, Int(drag.location.y / cellHeight))
                    let index = row * 7 + column - leading

                    guard days.indices.contains(index) else { return }
                    let day = days[index].date

                    if !calendar.isDate(day, inSameDayAs: selectedDay) {
                        selectedDay = day
                        Haptics.selection()
                    }
                default:
                    break
                }
            }
    }

    private func updateTimeSelection(x: CGFloat, chartWidth: CGFloat) {
        guard chartWidth > 0 else { return }

        let fraction = min(1, max(0, x / chartWidth))
        let minutes = Double(fraction) * 1_440

        if let previousScrub {
            let lower = min(previousScrub, minutes)
            let upper = max(previousScrub, minutes)
            if boundaryMinutes.contains(where: { $0 > lower && $0 <= upper }) {
                Haptics.selection()
            }
        }

        previousScrub = minutes
        selectedMinutes = min(1_439.5, max(0, minutes))
    }

    private func shift(_ direction: Int) {
        if direction > 0 && !canGoForward { return }

        guard let newAnchor = calendar.date(
            byAdding: range.component,
            value: direction * range.step,
            to: anchor
        ) else {
            return
        }

        anchor = newAnchor
        let bounds = bounds(for: range, anchor: newAnchor)

        if now >= bounds.start && now < bounds.end {
            selectedDay = calendar.startOfDay(for: now)
        } else {
            selectedDay = calendar.startOfDay(for: bounds.end.addingTimeInterval(-1))
        }

        selectedMinutes = nil
        previousScrub = nil
    }

    private func bounds(for range: TimelineRange, anchor: Date) -> TimelineBounds {
        switch range {
        case .day:
            let start = calendar.startOfDay(for: anchor)
            let end = calendar.date(byAdding: .day, value: 1, to: start)
                ?? start.addingTimeInterval(86_400)
            return TimelineBounds(start: start, end: end)
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: anchor)
            let start = interval?.start ?? calendar.startOfDay(for: anchor)
            let end = interval?.end ?? start.addingTimeInterval(604_800)
            return TimelineBounds(start: start, end: end)
        case .month:
            let interval = calendar.dateInterval(of: .month, for: anchor)
            let start = interval?.start ?? calendar.startOfDay(for: anchor)
            let end = interval?.end ?? start.addingTimeInterval(2_678_400)
            return TimelineBounds(start: start, end: end)
        case .sixMonths:
            let monthStart = calendar.dateInterval(of: .month, for: anchor)?.start
                ?? calendar.startOfDay(for: anchor)
            let start = calendar.date(byAdding: .month, value: -5, to: monthStart)
                ?? monthStart
            let end = calendar.date(byAdding: .month, value: 1, to: monthStart)
                ?? monthStart.addingTimeInterval(2_678_400)
            return TimelineBounds(start: start, end: end)
        }
    }

    private func emptyChart(title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(palette.secondaryText.color)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText.color)

            Text(message)
                .font(.caption)
                .foregroundStyle(palette.secondaryText.color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .padding(12)
        .background {
            ThemedCardBackground(fill: palette.surface, cornerRadius: 20)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(palette.primaryText.color.opacity(0.06), lineWidth: 1)
        }
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

struct TimelineAlterSummary: Identifiable {
    var id: UUID { alter.id }
    let alter: Alter
    let fullDuration: TimeInterval
    let partialDuration: TimeInterval

    var totalDuration: TimeInterval {
        fullDuration + partialDuration
    }
}

enum TimelineBuilder {
    static func buildDays(
        from start: Date,
        to end: Date,
        state: AppState,
        now: Date,
        calendar: Calendar = .current
    ) -> [TimelineDay] {
        var days: [TimelineDay] = []
        var day = calendar.startOfDay(for: start)
        var count = 0

        while day < end && count < 400 {
            if let timelineDay = buildDay(day, state: state, now: now, calendar: calendar) {
                days.append(timelineDay)
            } else {
                days.append(TimelineDay(id: day, date: day, rows: []))
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            count += 1
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
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

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

    static func summaries(for day: TimelineDay) -> [TimelineAlterSummary] {
        day.rows.compactMap { row in
            let full = row.segments
                .filter { $0.mode == .full }
                .reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
            let partial = row.segments
                .filter { $0.mode == .partial }
                .reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }

            guard full + partial > 0 else { return nil }

            return TimelineAlterSummary(
                alter: row.alter,
                fullDuration: full,
                partialDuration: partial
            )
        }
        .sorted { $0.totalDuration > $1.totalDuration }
    }
}

private struct FronterAtTime: Identifiable {
    var id: UUID { alter.id }
    let alter: Alter
    let segment: TimelineSegment
}

private extension TimeInterval {
    var timelineDuration: String {
        let totalMinutes = Int((self / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(max(1, minutes))m"
    }
}
