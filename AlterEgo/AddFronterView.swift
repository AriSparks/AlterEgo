import SwiftUI

struct AddFronterView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var pendingAlter: Alter?
    @State private var showModeChoice = false
    @State private var isAddingAlter = false

    private var activeAlters: [Alter] {
        store.state.activeAlters
    }

    private var availableAlters: [Alter] {
        store.state.alters
            .filter { store.activeSession(for: $0.id) == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !activeAlters.isEmpty {
                        currentlyFrontingSection
                    }

                    if availableAlters.isEmpty {
                        emptyState
                    } else {
                        alterPicker
                    }
                }
                .padding(20)
            }
            .navigationTitle("Add Fronter")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

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
            }
            .confirmationDialog(
                "How is \(pendingAlter?.name ?? "this alter") fronting?",
                isPresented: $showModeChoice,
                titleVisibility: .visible,
                presenting: pendingAlter
            ) { alter in
                Button("Alongside others (partially fronting)") {
                    store.front(alter, mode: .partial)
                    pendingAlter = nil
                    dismiss()
                }
                Button("Take over entirely (fully fronting)") {
                    store.front(alter, mode: .full)
                    pendingAlter = nil
                    dismiss()
                }
                Button("Cancel", role: .cancel) {
                    pendingAlter = nil
                }
            } message: { _ in
                Text("Alongside keeps everyone who is currently fronting. Taking over ends their sessions and marks this alter as fully fronting.")
            }
        }
    }

    private var currentlyFrontingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Currently fronting")
                .font(.headline)

            ForEach(activeAlters) { alter in
                HStack(spacing: 10) {
                    AvatarView(alter: alter, size: 30)

                    Text(alter.name)
                        .font(.subheadline.weight(.semibold))

                    Spacer(minLength: 0)

                    if let session = store.activeSession(for: alter.id) {
                        StatusBadge(mode: session.mode, compact: true)
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var alterPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Who is fronting?")
                .font(.headline)

            ForEach(availableAlters) { alter in
                Button {
                    pendingAlter = alter
                    showModeChoice = true
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(alter: alter, size: 38)

                        Text(alter.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(hex: alter.colorHex).opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No alters to add", systemImage: "person.2.badge.plus")
        } description: {
            Text(store.state.alters.isEmpty
                 ? "Add an alter first, then you can start a fronting session."
                 : "Everyone is already fronting. Stop a session or add a new alter.")
        } actions: {
            Button("Add Alter") {
                isAddingAlter = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
