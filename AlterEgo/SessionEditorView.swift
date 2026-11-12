import SwiftUI

struct SessionEditorView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.themePalette) private var palette
    @Environment(\.dismiss) private var dismiss

    let session: FrontingSession?

    @State private var alterID: UUID?
    @State private var mode: FrontingMode
    @State private var start: Date
    @State private var hasEnd: Bool
    @State private var end: Date
    @State private var showDeleteConfirmation = false

    init(session: FrontingSession?, defaultStart: Date) {
        self.session = session

        let now = Date()
        let initialStart = min(session?.start ?? defaultStart, now)

        _alterID = State(initialValue: session?.alterID)
        _mode = State(initialValue: session?.mode ?? .full)
        _start = State(initialValue: initialStart)
        _hasEnd = State(initialValue: session?.end != nil)

        let initialEnd = session?.end ?? min(now, initialStart.addingTimeInterval(3600))
        _end = State(initialValue: max(initialEnd, initialStart))
    }

    private var alters: [Alter] {
        store.state.alters.sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedAlter: Alter? {
        store.state.alter(withID: alterID)
    }

    private var validationMessage: String? {
        if alterID == nil { return "Choose an alter." }
        if start > Date() { return "The start time cannot be in the future." }
        if hasEnd {
            if end > Date() { return "The end time cannot be in the future." }
            if end <= start { return "The end time must be after the start time." }
        }
        return nil
    }

    private var canSave: Bool { validationMessage == nil }

    var body: some View {
        NavigationStack {
            Form {
                if alters.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No alters yet", systemImage: "person.2.badge.plus")
                        } description: {
                            Text("Add an alter before recording a fronting entry.")
                        }
                    }
                } else {
                    Section("Who") {
                        Picker("Alter", selection: $alterID) {
                            Text("Choose an alter").tag(UUID?.none)
                            ForEach(alters) { alter in
                                Text(alter.name).tag(UUID?.some(alter.id))
                            }
                        }

                        Picker("Fronting level", selection: $mode) {
                            ForEach(FrontingMode.allCases, id: \.self) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("When") {
                        DatePicker(
                            "Start",
                            selection: $start,
                            in: ...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )

                        Toggle("Has ended", isOn: $hasEnd)

                        if hasEnd {
                            DatePicker(
                                "End",
                                selection: $end,
                                in: ...Date(),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        } else {
                            Text("This entry is still active.")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText.color)
                        }
                    }

                    if let validationMessage {
                        Section {
                            Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(.red)
                        }
                    }

                    if session != nil {
                        Section {
                            Button("Delete Entry", role: .destructive) {
                                showDeleteConfirmation = true
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(ThemedBackground(fill: palette.background))
            .navigationTitle(session == nil ? "New Entry" : "Edit Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: hasEnd) { _, newValue in
                guard newValue else { return }
                if end <= start {
                    end = min(Date(), start.addingTimeInterval(3600))
                }
            }
            .onChange(of: start) { _, newValue in
                if hasEnd && end <= newValue {
                    end = min(Date(), newValue.addingTimeInterval(3600))
                }
            }
            .alert(
                "Delete this entry?",
                isPresented: $showDeleteConfirmation
            ) {
                Button("Delete", role: .destructive) {
                    if let session {
                        store.deleteSession(session)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This fronting entry will be removed from the timeline. This cannot be undone.")
            }
        }
    }

    private func save() {
        guard canSave, let alterID else { return }

        let finalEnd = hasEnd ? end : nil
        let updated = FrontingSession(
            id: session?.id ?? UUID(),
            alterID: alterID,
            start: start,
            end: finalEnd,
            mode: mode
        )

        if session == nil {
            store.addSession(updated)
        } else {
            store.updateSession(updated)
        }

        dismiss()
    }
}
