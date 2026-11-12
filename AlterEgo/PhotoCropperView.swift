import SwiftUI

struct PhotoCropperView: View {
    @Environment(\.dismiss) private var dismiss

    let originalData: Data
    let onCrop: (Data) -> Void

    @State private var zoom: CGFloat = 1
    @State private var committedZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero
    @State private var viewport: CGFloat = 320
    @State private var isSaving = false

    private var image: Image? {
        platformImage(from: originalData)
    }

    private var imageSize: CGSize? {
        ImageProcessor.imageSize(from: originalData)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    let side = min(geometry.size.width, geometry.size.height)

                    ZStack {
                        Color.black

                        if let image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: side, height: side)
                                .scaleEffect(zoom)
                                .offset(offset)
                                .frame(width: side, height: side)
                                .clipped()
                        } else {
                            ContentUnavailableView {
                                Label("Photo unavailable", systemImage: "photo.badge.exclamationmark")
                            } description: {
                                Text("This image could not be loaded.")
                            }
                        }

                        circularMask(side: side)

                        Circle()
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                            .frame(width: side * 0.9, height: side * 0.9)
                            .allowsHitTesting(false)
                    }
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(side: side))
                    .simultaneousGesture(magnificationGesture(side: side))
                    .onAppear {
                        viewport = side
                    }
                    .onChange(of: side) { _, newValue in
                        viewport = newValue
                        offset = clampedOffset(offset, side: newValue, zoom: zoom)
                        committedOffset = offset
                    }
                }

                controls
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Crop Photo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo") {
                        saveCrop()
                    }
                    .disabled(image == nil || isSaving)
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundStyle(.white.opacity(0.7))

                Slider(
                    value: Binding(
                        get: { Double(zoom) },
                        set: { newValue in
                            zoom = min(4, max(1, CGFloat(newValue)))
                            offset = clampedOffset(offset, side: viewport, zoom: zoom)
                            committedZoom = zoom
                            committedOffset = offset
                        }
                    ),
                    in: 1...4
                )
                .tint(.white)

                Image(systemName: "plus.magnifyingglass")
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text("Drag to reposition. Pinch or use the slider to zoom.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(18)
        .background(Color.black)
    }

    private func circularMask(side: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.55)
            Circle()
                .frame(width: side * 0.9, height: side * 0.9)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }

    private func dragGesture(side: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = clampedOffset(
                    CGSize(
                        width: committedOffset.width + value.translation.width,
                        height: committedOffset.height + value.translation.height
                    ),
                    side: side,
                    zoom: zoom
                )
            }
            .onEnded { _ in
                committedOffset = offset
            }
    }

    private func magnificationGesture(side: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = min(4, max(1, committedZoom * value))
                offset = clampedOffset(offset, side: side, zoom: zoom)
            }
            .onEnded { _ in
                committedZoom = zoom
                committedOffset = offset
            }
    }

    private func clampedOffset(_ offset: CGSize, side: CGFloat, zoom: CGFloat) -> CGSize {
        guard let imageSize, imageSize.width > 0, imageSize.height > 0 else { return offset }

        let fillScale = max(side / imageSize.width, side / imageSize.height)
        let displayScale = fillScale * max(1, zoom)
        let displayed = CGSize(
            width: imageSize.width * displayScale,
            height: imageSize.height * displayScale
        )

        let maxX = max(0, (displayed.width - side) / 2)
        let maxY = max(0, (displayed.height - side) / 2)

        return CGSize(
            width: min(maxX, max(-maxX, offset.width)),
            height: min(maxY, max(-maxY, offset.height))
        )
    }

    private func saveCrop() {
        isSaving = true
        let cropped = ImageProcessor.crop(
            originalData,
            zoom: zoom,
            offset: offset,
            viewport: viewport
        )
        isSaving = false

        guard let cropped else { return }
        onCrop(cropped)
        dismiss()
    }
}
