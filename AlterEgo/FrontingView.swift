import SwiftUI

struct FrontingView: View {
    @EnvironmentObject private var store: AppStore

    @State private var pendingAlter: Alter?
    @State private var showFrontingChoice = false
    @State private var showFrontingActions = false
    @State private var isAddingAlter = false

    private var alters: [Alter] {
        store.state.alters.sorted { $0.createdAt < $1.createdAt }
    }

    private var activeAlters: [Alter] {
        store.state.activeAlters
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    nowFrontingSection
                    altersSection
                }
                .padding(20)
                .frame(maxWidth: 940)
                .frame(maxWidth: .infinity)
            }
            .background(background)
            .navigationTitle("Fronting")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingAlter = true
                    } label: {
                        Label("Add Alter", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingAlter) {
                AlterEditorView(alter: nil)
            }
            .confirmationDialog(
                "How is \(pendingAlter?.name ?? "this alter") fronting?",
                isPresented: $showFrontingChoice,
                titleVisibility: .visible,
                presenting: pendingAlter
            ) { alter in
                Button("Alongside others (partially fronting)") {
                    store.front(alter, mode: .partial)
                    pendingAlter = nil
                }
                Button("Take over entirely (fully fronting)") {
                    store.front(alter, mode: .full)
                    pendingAlter = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingAlter = nil
                }
            } message: { _ in
                Text("Alongside keeps everyone who is currently fronting. Taking over ends their sessions and marks this alter as fully fronting.")
            }
            .confirmationDialog(
                "\(pendingAlter?.name ?? "This alter") is already fronting",
                isPresented: $showFrontingActions,
                titleVisibility: .visible,
                presenting: pendingAlter
            ) { alter in
                if let session = store.activeSession(for: alter.id), session.mode == .partial {
                    Button("Switch to fully fronting") {
                        store.front(alter, mode: .full)
                        pendingAlter = nil
                    }
                }
                Button("Stop fronting", role: .destructive) {
                    store.stop(alter)
                    pendingAlter = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingAlter = nil
                }
            } message: { alter in
                if let session = store.activeSession(for: alter.id) {
                    Text(session.mode == .full
                         ? "\(alter.name) is currently fully fronting."
                         : "\(alter.name) is currently partially fronting alongside others.")
                }
            }
        }
    }

    private var nowFrontingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Now Fronting")
                    .font(.title2.bold())
                Spacer()
                if !activeAlters.isEmpty {
                    Button("End All", role: .destructive) {
                        store.stopAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if activeAlters.isEmpty {
                EmptyNowCard()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(activeAlters) { alter in
                            ActiveAlterCard(
                                alter: alter,
                                session: store.activeSession(for: alter.id)
                            ) {
                                store.stop(alter)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var altersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Alters")
                    .font(.title2.bold())
                Spacer()
                Text("Tap an alter to update who is fronting")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            if alters.isEmpty {
                ContentUnavailableView {
                    Label("No alters yet", systemImage: "person.2.badge.plus")
                } description: {
                    Text("Add an alter to start tracking who is fronting.")
                } actions: {
                    Button("Add Alter") {
                        isAddingAlter = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 155, maximum: 230), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(alters) { alter in
                        AlterTapCard(
                            alter: alter,
                            session: store.activeSession(for: alter.id)
                        )
                        .onTapGesture {
                            handleTap(alter)
                        }
                    }
                }
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.10), Color.clear],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }

    private func handleTap(_ alter: Alter) {
        pendingAlter = alter

        if store.activeSession(for: alter.id) != nil {
            showFrontingActions = true
        } else if store.state.isAnyoneFronting {
            showFrontingChoice = true
        } else {
            store.front(alter, mode: .full)
            pendingAlter = nil
        }
    }
}

private struct EmptyNowCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "moon.zzz.fill")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("No one is fronting")
                    .font(.headline)
                Text("Tap an alter below to start a session.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ActiveAlterCard: View {
    let alter: Alter
    let session: FrontingSession?
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarView(alter: alter, size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(alter.name)
                        .font(.headline)
                        .lineLimit(1)
                    if let session {
                        StatusBadge(mode: session.mode)
                    }
                }

                Spacer(minLength: 0)
            }

            if let session {
                SwiftUI.TimelineView(.periodic(from: .now, by: 30)) { context in
                    Label(shortDuration(session.duration(at: context.date)), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(role: .destructive, action: onStop) {
                Label("Stop fronting", systemImage: "stop.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 225, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(hex: alter.colorHex).opacity(0.45), lineWidth: 1)
        )
    }
}

private struct AlterTapCard: View {
    let alter: Alter
    let session: FrontingSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                AvatarView(alter: alter, size: 46)
                Spacer()
                if let session {
                    Circle()
                        .fill(session.mode == .full ? Color.accentColor : Color.orange)
                        .frame(width: 10, height: 10)
                        .padding(.top, 4)
                }
            }

            Text(alter.name)
                .font(.headline)
                .lineLimit(1)

            if let session {
                Text(session.mode.label)
                    .font(.caption)
                    .foregroundStyle(session.mode == .full ? Color.accentColor : Color.orange)
            } else {
                Text("Not fronting")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(hex: alter.colorHex).opacity(session == nil ? 0.25 : 0.65), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityAddTraits(.isButton)
    }
}
