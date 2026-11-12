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
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.themePalette) private var palette
    @Environment(\.dismiss) private var dismiss

    let alter: Alter?

    @State private var name: String
    @State private var emoji: String
    @State private var colorHex: String
    @State private var imageData: Data?
    @State private var originalImageData: Data?
    @State private var avatarKind: AvatarKind
    @State private var photoItem: PhotosPickerItem?
    @State private var isProcessingPhoto = false
    @State private var showCropper = false
    @State private var showDeleteConfirmation = false
    @State private var descriptionText: String
    @State private var pronouns: String
    @State private var role: String
    @State private var characteristicsText: String
    @State private var bannerColorHex: String

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
        _originalImageData = State(initialValue: alter?.originalImageData)
        _avatarKind = State(initialValue: alter?.imageData == nil ? .emoji : .photo)
        _descriptionText = State(initialValue: alter?.descriptionText ?? "")
        _pronouns = State(initialValue: alter?.pronouns ?? "")
        _role = State(initialValue: alter?.role ?? "")
        _characteristicsText = State(initialValue: (alter?.characteristics ?? []).joined(separator: ", "))
        _bannerColorHex = State(initialValue: alter?.bannerColorHex ?? alter?.colorHex ?? Alter.palette[0])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $name)

                    TextField("Role", text: $role)

                    TextField("Pronouns", text: $pronouns)
                }

                Section("Description") {
                    TextField(
                        "How would you describe this alter?",
                        text: $descriptionText,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                }

                Section("Characteristics") {
                    TextField(
                        "Protective, creative, quiet…",
                        text: $characteristicsText,
                        axis: .vertical
                    )
                    .lineLimit(1...4)

                    if !parsedCharacteristics.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(parsedCharacteristics, id: \.self) { characteristic in
                                Text(characteristic)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(Color(hex: colorHex).opacity(0.18), in: Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Text("Separate characteristics with commas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                                            emoji == choice ? palette.accent.color.opacity(0.22) : Color.clear,
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

                        if cropSource != nil {
                            Button {
                                showCropper = true
                            } label: {
                                Label("Crop Photo", systemImage: "crop")
                            }
                        }

                        if imageData != nil {
                            Button("Remove Photo", role: .destructive) {
                                imageData = nil
                                originalImageData = nil
                                avatarKind = .emoji
                            }
                        }
                    }
                }

                Section("Banner") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                        spacing: 10
                    ) {
                        ForEach(Alter.palette, id: \.self) { hex in
                            Button {
                                bannerColorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(height: 30)
                                    .overlay {
                                        if bannerColorHex == hex {
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

                    Text("The banner uses this color. It defaults to the alter's main color.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            .scrollContentBackground(.hidden)
            .background(ThemedBackground(fill: palette.background))
            .tint(palette.accent.color)
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
            .sheet(isPresented: $showCropper) {
                if let cropSource {
                    PhotoCropperView(originalData: cropSource) { cropped in
                        imageData = cropped
                        avatarKind = .photo
                    }
                }
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

    private var cropSource: Data? {
        originalImageData ?? imageData
    }

    private var parsedCharacteristics: [String] {
        var seen = Set<String>()
        return characteristicsText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    private var previewAlter: Alter {
        Alter(
            id: alter?.id ?? UUID(),
            name: name.isEmpty ? "New Alter" : name,
            emoji: emoji.isEmpty ? "🙂" : emoji,
            imageData: avatarKind == .photo ? imageData : nil,
            colorHex: colorHex,
            createdAt: alter?.createdAt ?? Date(),
            descriptionText: nilIfEmpty(descriptionText),
            pronouns: nilIfEmpty(pronouns),
            role: nilIfEmpty(role),
            characteristics: parsedCharacteristics.isEmpty ? nil : parsedCharacteristics,
            originalImageData: avatarKind == .photo ? originalImageData : nil,
            bannerColorHex: bannerColorHex
        )
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let finalEmoji = emoji.isEmpty ? "🙂" : emoji
        let finalImage = avatarKind == .photo ? imageData : nil
        let finalOriginal = avatarKind == .photo ? originalImageData : nil
        let characteristics = parsedCharacteristics.isEmpty ? nil : parsedCharacteristics

        if var existing = alter {
            existing.name = trimmedName
            existing.emoji = finalEmoji
            existing.imageData = finalImage
            existing.colorHex = colorHex
            existing.descriptionText = nilIfEmpty(descriptionText)
            existing.pronouns = nilIfEmpty(pronouns)
            existing.role = nilIfEmpty(role)
            existing.characteristics = characteristics
            existing.originalImageData = finalOriginal
            existing.bannerColorHex = bannerColorHex
            store.updateAlter(existing)
        } else {
            store.addAlter(
                Alter(
                    name: trimmedName,
                    emoji: finalEmoji,
                    imageData: finalImage,
                    colorHex: colorHex,
                    descriptionText: nilIfEmpty(descriptionText),
                    pronouns: nilIfEmpty(pronouns),
                    role: nilIfEmpty(role),
                    characteristics: characteristics,
                    originalImageData: finalOriginal,
                    bannerColorHex: bannerColorHex
                )
            )
        }

        dismiss()
    }

    private func nilIfEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        isProcessingPhoto = true
        Task { @MainActor in
            defer { isProcessingPhoto = false }

            guard let data = try? await item.loadTransferable(type: Data.self),
                  let original = ImageProcessor.prepare(data, maxDimension: 2048) else {
                return
            }

            originalImageData = original
            imageData = ImageProcessor.prepare(original)
            avatarKind = .photo
            showCropper = true
        }
    }
}
