import SwiftUI
import PhotosUI

private enum AvatarKind: String, CaseIterable, Identifiable {
    case emoji
    case photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emoji: return "Emoji"
        case .photo: return "Photo"
        }
    }
}

struct AlterEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let alter: Alter?

    @State private var name: String
    @State private var emoji: String
    @State private var colorHex: String
    @State private var imageData: Data?
    @State private var avatarKind: AvatarKind
    @State private var photoItem: PhotosPickerItem?
    @State private var isProcessingPhoto = false
    @State private var showDeleteConfirmation = false

    private let emojiChoices = [
        "🙂", "😀", "😎", "🌙", "☀️", "🌸", "🔥", "🌊",
        "⭐️", "🦋", "🐺", "🦊", "🐱", "🐶", "🌿", "🍀",
        "🎨", "🎧", "🕯️", "💎", "🪐", "🌌", "🧸", "🍓",
        "🫧", "🪷", "🐉", "🦉", "🍄", "🌈", "🖤", "🤍"
    ]

    init(alter: Alter?) {
        self.alter = alter
        _name = State(initialValue: alter?.name ?? "")
        _emoji = State(initialValue: alter?.emoji ?? "🙂")
        _colorHex = State(initialValue: alter?.colorHex ?? (Alter.palette.randomElement() ?? Alter.palette[0]))
        _imageData = State(initialValue: alter?.imageData)
        _avatarKind = State(initialValue: alter?.imageData == nil ? .emoji : .photo)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $name)
                }

                Section("Avatar") {
                    HStack {
                        Spacer()
                        AvatarView(alter: previewAlter, size: 96)
                        Spacer()
                    }
                    .padding(.vertical, 6)

                    Picker("Avatar style", selection: $avatarKind) {
                        ForEach(AvatarKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    if avatarKind == .emoji {
                        TextField("Emoji", text: $emoji)
                            .onChange(of: emoji) { _, newValue in
                                if newValue.count > 4 {
                                    emoji = String(newValue.prefix(4))
                                }
                            }

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8),
                            spacing: 6
                        ) {
                            ForEach(emojiChoices, id: \.self) { choice in
                                Button {
                                    emoji = choice
                                } label: {
                                    Text(choice)
                                        .font(.title3)
                                        .frame(maxWidth: .infinity, minHeight: 34)
                                        .background(
                                            emoji == choice ? Color.accentColor.opacity(0.22) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(imageData == nil ? "Choose Photo" : "Change Photo", systemImage: "photo.on.rectangle")
                        }

                        if isProcessingPhoto {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Preparing photo…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if imageData != nil {
                            Button("Remove Photo", role: .destructive) {
                                imageData = nil
                                avatarKind = .emoji
                            }
                        }
                    }
                }

                Section("Color") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                        spacing: 10
                    ) {
                        ForEach(Alter.palette, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(height: 34)
                                    .overlay {
                                        if colorHex == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if alter != nil {
                    Section {
                        Button("Delete Alter", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(alter == nil ? "New Alter" : "Edit Alter")
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: photoItem) { _, item in
                loadPhoto(item)
            }
            .confirmationDialog(
                "Delete \(alter?.name ?? "this alter")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let alter {
                        store.deleteAlter(alter)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This also removes their fronting history.")
            }
        }
    }

    private var previewAlter: Alter {
        Alter(
            id: alter?.id ?? UUID(),
            name: name.isEmpty ? "New Alter" : name,
            emoji: emoji.isEmpty ? "🙂" : emoji,
            imageData: avatarKind == .photo ? imageData : nil,
            colorHex: colorHex
        )
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let finalEmoji = emoji.isEmpty ? "🙂" : emoji
        let finalImage = avatarKind == .photo ? imageData : nil

        if var existing = alter {
            existing.name = trimmedName
            existing.emoji = finalEmoji
            existing.imageData = finalImage
            existing.colorHex = colorHex
            store.updateAlter(existing)
        } else {
            store.addAlter(
                Alter(
                    name: trimmedName,
                    emoji: finalEmoji,
                    imageData: finalImage,
                    colorHex: colorHex
                )
            )
        }

        dismiss()
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        isProcessingPhoto = true
        Task {
            defer { isProcessingPhoto = false }

            guard let data = try? await item.loadTransferable(type: Data.self),
                  let processed = ImageProcessor.prepare(data) else {
                return
            }

            imageData = processed
            avatarKind = .photo
        }
    }
}
