import SwiftUI

struct AltersView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.themePalette) private var palette

    @State private var isAddingAlter = false
    @State private var editingAlter: Alter?
    @State private var detailAlter: Alter?
    @State private var alterToDelete: Alter?

    private var alters: [Alter] {
        store.state.alters.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            List {
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(alters) { alter in
                        Button {
                            detailAlter = alter
                        } label: {
                            AlterListRow(
                                alter: alter,
                                session: store.activeSession(for: alter.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                alterToDelete = alter
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                editingAlter = alter
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button {
                                detailAlter = alter
                            } label: {
                                Label("View Details", systemImage: "person.text.rectangle")
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
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(ThemedBackground(fill: palette.background))
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
                    .environmentObject(store)
                    .environmentObject(theme)
            }
            .sheet(item: $editingAlter) { alter in
                AlterEditorView(alter: alter)
                    .environmentObject(store)
                    .environmentObject(theme)
            }
            .sheet(item: $detailAlter) { alter in
                AlterDetailView(alterID: alter.id)
                    .environmentObject(store)
                    .environmentObject(theme)
            }
            .alert(
                "Remove \(alterToDelete?.name ?? "this alter")?",
                isPresented: Binding(
                    get: { alterToDelete != nil },
                    set: { if !$0 { alterToDelete = nil } }
                ),
                presenting: alterToDelete
            ) { alter in
                Button("Remove", role: .destructive) {
                    store.deleteAlter(alter)
                    alterToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    alterToDelete = nil
                }
            } message: { alter in
                Text("This permanently deletes \(alter.name) and their entire timeline history. This cannot be undone.")
            }
        }
    }
}

private struct AlterListRow: View {
    let alter: Alter
    let session: FrontingSession?

    @Environment(\.themePalette) private var palette

    var body: some View {
        HStack(spacing: 13) {
            AvatarView(alter: alter, size: 52)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(alter.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(palette.primaryText.color)

                    if let session {
                        StatusBadge(mode: session.mode, compact: true)
                    }
                }

                Text(alter.displayDescription ?? "No description yet")
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(
                        alter.displayDescription == nil
                            ? palette.secondaryText.color.opacity(0.7)
                            : palette.secondaryText.color
                    )
                    .italic(alter.displayDescription == nil)

                HStack(spacing: 6) {
                    if let role = alter.displayRole {
                        Label(role, systemImage: "person.text.rectangle")
                    }
                    if let pronouns = alter.displayPronouns {
                        Text(pronouns)
                    }
                }
                .font(.caption2)
                .foregroundStyle(palette.secondaryText.color)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText.color.opacity(0.6))
        }
        .padding(13)
        .background(ThemedCardBackground(fill: palette.surface, cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(hex: alter.colorHex).opacity(session == nil ? 0.22 : 0.65), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
