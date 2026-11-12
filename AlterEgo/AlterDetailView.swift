import SwiftUI

struct AlterDetailView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.themePalette) private var palette
    @Environment(\.dismiss) private var dismiss

    let alterID: UUID

    @State private var isEditing = false

    private var alter: Alter? {
        store.state.alters.first { $0.id == alterID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let alter {
                    content(for: alter)
                } else {
                    ContentUnavailableView {
                        Label("Alter not found", systemImage: "person.crop.circle.badge.questionmark")
                    } description: {
                        Text("This alter may have been removed.")
                    }
                }
            }
            .background(ThemedBackground(fill: palette.background))
            .navigationTitle(alter?.name ?? "Alter")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .disabled(alter == nil)
                }
            }
            .sheet(isPresented: $isEditing) {
                if let alter {
                    AlterEditorView(alter: alter)
                        .environmentObject(store)
                        .environmentObject(theme)
                }
            }
        }
    }

    private func content(for alter: Alter) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                banner(alter)
                identity(alter)

                if let description = alter.displayDescription {
                    sectionCard(title: "Description") {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(palette.primaryText.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !alter.displayCharacteristics.isEmpty {
                    sectionCard(title: "Characteristics") {
                        FlowLayout(spacing: 8) {
                            ForEach(alter.displayCharacteristics, id: \.self) { characteristic in
                                Text(characteristic)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .foregroundStyle(palette.primaryText.color)
                                    .background(
                                        Color(hex: alter.colorHex).opacity(0.18),
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color(hex: alter.colorHex).opacity(0.5), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private func banner(_ alter: Alter) -> some View {
        let base = Color(hex: alter.bannerColorHex ?? alter.colorHex)
        return ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [base.opacity(0.9), base.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(alignment: .bottom, spacing: 14) {
                AvatarView(alter: alter, size: 78)

                VStack(alignment: .leading, spacing: 4) {
                    Text(alter.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        if let role = alter.displayRole {
                            Label(role, systemImage: "person.text.rectangle")
                        }
                        if let pronouns = alter.displayPronouns {
                            Text(pronouns)
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                }

                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func identity(_ alter: Alter) -> some View {
        HStack(spacing: 20) {
            if let session = store.activeSession(for: alter.id) {
                Label("Currently \(session.mode.label.lowercased())", systemImage: "dot.radiowaves.left.and.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accent.color)
            } else {
                Label("Not currently fronting", systemImage: "moon.zzz")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText.color)
            }

            Spacer()

            if let role = alter.displayRole {
                Text(role)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: alter.colorHex).opacity(0.16), in: Capsule())
                    .foregroundStyle(palette.primaryText.color)
            }
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.primaryText.color)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ThemedCardBackground(fill: palette.surface, cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(palette.primaryText.color.opacity(0.07), lineWidth: 1)
        )
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: width == .infinity ? x : width, height: y + lineHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
