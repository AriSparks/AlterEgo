import SwiftUI

struct AltersView: View {
    @EnvironmentObject private var store: AppStore

    @State private var isAddingAlter = false
    @State private var editingAlter: Alter?
    @State private var alterToDelete: Alter?

    private var alters: [Alter] {
        store.state.alters.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if alters.isEmpty {
                    ContentUnavailableView {
                        Label("No alters yet", systemImage: "person.2.badge.plus")
                    } description: {
                        Text("Add the people who share your headspace. Give each one a name, a color, and an emoji or photo.")
                    } actions: {
                        Button("Add Alter") {
                            isAddingAlter = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 165, maximum: 240), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(alters) { alter in
                            Button {
                                editingAlter = alter
                            } label: {
                                AlterGridCard(
                                    alter: alter,
                                    session: store.activeSession(for: alter.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    editingAlter = alter
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                if store.activeSession(for: alter.id) != nil {
                                    Button {
                                        store.stop(alter)
                                    } label: {
                                        Label("Stop Fronting", systemImage: "stop.circle")
                                    }
                                }

                                Divider()

                                Button(role: .destructive) {
                                    alterToDelete = alter
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }

                        Button {
                            isAddingAlter = true
                        } label: {
                            AddAlterCard()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .frame(maxWidth: 980)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.08), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Alters")
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
            .sheet(item: $editingAlter) { alter in
                AlterEditorView(alter: alter)
            }
            .confirmationDialog(
                "Delete \(alterToDelete?.name ?? "this alter")?",
                isPresented: Binding(
                    get: { alterToDelete != nil },
                    set: { if !$0 { alterToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: alterToDelete
            ) { alter in
                Button("Delete", role: .destructive) {
                    store.deleteAlter(alter)
                    alterToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    alterToDelete = nil
                }
            } message: { _ in
                Text("This also removes their fronting history.")
            }
        }
    }
}

private struct AlterGridCard: View {
    let alter: Alter
    let session: FrontingSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                AvatarView(alter: alter, size: 62)
                Spacer()
                if let session {
                    StatusBadge(mode: session.mode, compact: true)
                }
            }

            Text(alter.name)
                .font(.headline)
                .lineLimit(1)

            Text(session == nil ? "Not fronting" : session!.mode.label)
                .font(.caption)
                .foregroundStyle(session == nil ? Color.secondary : Color(hex: alter.colorHex))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(hex: alter.colorHex).opacity(session == nil ? 0.25 : 0.7), lineWidth: 1)
        )
    }
}

private struct AddAlterCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.accentColor)
            Text("Add Alter")
                .font(.headline)
            Text("Name, emoji, or photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.accentColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
    }
}
