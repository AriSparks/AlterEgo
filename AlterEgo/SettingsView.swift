import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.themePalette) private var palette

    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $theme.settings.appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(theme.settings.appearanceMode.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if theme.settings.appearanceMode == .daytime {
                        DatePicker(
                            "Light appearance",
                            selection: minutesBinding(\.daytimeLightMinutes),
                            displayedComponents: .hourAndMinute
                        )

                        DatePicker(
                            "Dark appearance",
                            selection: minutesBinding(\.daytimeDarkMinutes),
                            displayedComponents: .hourAndMinute
                        )

                        Text("Daytime uses the light palette during the light hours and the dark palette otherwise.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Display") {
                    Toggle("Use 24-hour time", isOn: $theme.settings.use24HourTime)

                    Picker("Week starts on", selection: $theme.settings.weekStartDay) {
                        ForEach(1...7, id: \.self) { day in
                            Text(weekdayName(day)).tag(day)
                        }
                    }

                    Toggle("Hide partial-fronting stripes", isOn: $theme.settings.hidePartialStripes)
                }

                Section("Accent") {
                    ColorPicker("Accent color", selection: accentBinding, supportsOpacity: false)

                    HStack(spacing: 8) {
                        ForEach(Alter.palette, id: \.self) { hex in
                            Button {
                                theme.setAccent(Color(hex: hex))
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(height: 24)
                                    .overlay {
                                        if theme.settings.accentHex.uppercased() == hex.uppercased() {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Advanced Colors") {
                    NavigationLink {
                        PaletteEditorView(
                            title: "Light Palette",
                            palette: $theme.settings.light,
                            resetValue: .lightDefault
                        )
                    } label: {
                        paletteRow(title: "Light", settings: theme.settings.light)
                    }

                    NavigationLink {
                        PaletteEditorView(
                            title: "Dark Palette",
                            palette: $theme.settings.dark,
                            resetValue: .darkDefault
                        )
                    } label: {
                        paletteRow(title: "Dark", settings: theme.settings.dark)
                    }
                }

                Section("Data") {
                    NavigationLink {
                        ExportImportSettingsView()
                    } label: {
                        Label("Export & Import", systemImage: "square.and.arrow.up.on.square")
                    }
                }

                Section("Sync") {
                    NavigationLink {
                        CloudSyncSettingsView()
                    } label: {
                        Label("iCloud Sync", systemImage: "icloud")
                    }
                }

                Section {
                    Button("Reset Appearance & Colors", role: .destructive) {
                        showResetConfirmation = true
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(ThemedBackground(fill: palette.background))
            .tint(palette.accent.color)
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset appearance and colors?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    let reset = ThemeSettings()
                    theme.settings = reset
                    theme.refreshDaytime()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This restores the default palettes, schedule, accent color, and display settings. It does not change your alters or timeline.")
            }
            .onChange(of: theme.settings.appearanceMode) { _, _ in
                theme.refreshDaytime()
            }
            .onChange(of: theme.settings.daytimeLightMinutes) { _, _ in
                theme.refreshDaytime()
            }
            .onChange(of: theme.settings.daytimeDarkMinutes) { _, _ in
                theme.refreshDaytime()
            }
        }
    }

    private var accentBinding: Binding<Color> {
        Binding(
            get: { Color(hex: theme.settings.accentHex) },
            set: { theme.setAccent($0) }
        )
    }

    private func minutesBinding(_ keyPath: WritableKeyPath<ThemeSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                let start = calendar.startOfDay(for: Date())
                return calendar.date(
                    byAdding: .minute,
                    value: theme.settings[keyPath: keyPath],
                    to: start
                ) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                theme.settings[keyPath: keyPath] = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                theme.refreshDaytime()
            }
        )
    }

    private func weekdayName(_ index: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let safe = min(symbols.count - 1, max(0, index - 1))
        return symbols[safe]
    }

    private func paletteRow(title: String, settings: PaletteSettings) -> some View {
        HStack(spacing: 10) {
            Text(title)

            Spacer()

            HStack(spacing: 4) {
                ForEach([settings.background, settings.surface, settings.accent, settings.primaryText], id: \.self) { fill in
                    Circle()
                        .fill(fill.color)
                        .frame(width: 15, height: 15)
                        .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
                }
            }
        }
    }
}

struct PaletteEditorView: View {
    let title: String
    @Binding var palette: PaletteSettings
    let resetValue: PaletteSettings

    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section("Preview") {
                palettePreview
            }

            Section("Background") {
                FillEditor(title: "Background", fill: $palette.background)
            }

            Section("Surface") {
                FillEditor(title: "Surface", fill: $palette.surface)
            }

            Section("Accent") {
                FillEditor(title: "Accent", fill: $palette.accent)
            }

            Section("Primary Text") {
                FillEditor(title: "Primary Text", fill: $palette.primaryText)
            }

            Section("Secondary Text") {
                FillEditor(title: "Secondary Text", fill: $palette.secondaryText)
            }

            Section("Contrast") {
                let ratio = hexContrastRatio(palette.primaryText.averageHex, palette.background.averageHex)
                Label(
                    String(format: "Primary text: %.1f:1", ratio),
                    systemImage: ratio >= 4.5 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(ratio >= 4.5 ? .green : .orange)

                Text("WCAG AA recommends at least 4.5:1 for body text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset \(title)", role: .destructive) {
                    showResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(title)
        .confirmationDialog(
            "Reset \(title)?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                palette = resetValue
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var palettePreview: some View {
        ZStack {
            palette.background.fill(Rectangle())

            VStack(alignment: .leading, spacing: 8) {
                Text("Primary Text")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText.color)

                Text("Secondary text and supporting details")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText.color)

                HStack(spacing: 8) {
                    Circle()
                        .fill(palette.accent.color)
                        .frame(width: 18, height: 18)

                    Text("Accent")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.primaryText.color)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                palette.surface.fill(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct FillEditor: View {
    let title: String
    @Binding var fill: FillSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Style", selection: $fill.kind) {
                ForEach(FillKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: fill.kind) { _, kind in
                if kind == .gradient {
                    ensureGradientStops()
                } else if let first = fill.stops.first?.hex {
                    fill.solidHex = first
                }
            }

            if fill.kind == .solid {
                ColorPicker(
                    "Color",
                    selection: solidBinding,
                    supportsOpacity: false
                )
            } else {
                ForEach(Array(fill.stops.enumerated()), id: \.element.id) { index, stop in
                    HStack {
                        ColorPicker(
                            "Color \(index + 1)",
                            selection: stopColorBinding(id: stop.id),
                            supportsOpacity: false
                        )

                        if fill.stops.count > 2 {
                            Button {
                                removeStop(id: stop.id)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if fill.stops.count < 4 {
                    Button {
                        addStop()
                    } label: {
                        Label("Add Color", systemImage: "plus.circle")
                    }
                }

                VStack(alignment: .leading) {
                    Text("Angle: \(Int(fill.angle.rounded()))°")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(value: $fill.angle, in: 0...360, step: 1)
                }
            }

            fill.fill(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .frame(height: 34)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                )
        }
    }

    private var solidBinding: Binding<Color> {
        Binding(
            get: { Color(hex: fill.solidHex) },
            set: { fill.solidHex = $0.toHex() }
        )
    }

    private func stopColorBinding(id: UUID) -> Binding<Color> {
        Binding(
            get: {
                Color(hex: fill.stops.first(where: { $0.id == id })?.hex ?? fill.solidHex)
            },
            set: { newValue in
                guard let index = fill.stops.firstIndex(where: { $0.id == id }) else { return }
                fill.stops[index].hex = newValue.toHex()
            }
        )
    }

    private func ensureGradientStops() {
        guard fill.stops.count < 2 else { return }
        let base = fill.stops.first?.hex ?? fill.solidHex
        fill.stops = [
            GradientStopSettings(hex: base, location: 0),
            GradientStopSettings(hex: base, location: 1)
        ]
    }

    private func addStop() {
        guard fill.stops.count < 4 else { return }
        let base = fill.stops.last?.hex ?? fill.solidHex
        fill.stops.append(GradientStopSettings(hex: base, location: 1))
        normalizeStops()
    }

    private func removeStop(id: UUID) {
        guard fill.stops.count > 2 else { return }
        fill.stops.removeAll { $0.id == id }
        normalizeStops()
    }

    private func normalizeStops() {
        let count = fill.stops.count
        guard count > 0 else { return }

        for index in fill.stops.indices {
            fill.stops[index].location = count > 1
                ? Double(index) / Double(count - 1)
                : 0
        }
    }
}
