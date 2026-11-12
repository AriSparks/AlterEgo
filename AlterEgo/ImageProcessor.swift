import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ImageProcessor {
    static let maxDimension: CGFloat = 512

    static func imageSize(from data: Data) -> CGSize? {
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        return image.size
        #else
        guard let image = UIImage(data: data) else { return nil }
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        return image.size
        #endif
    }

    static func prepare(_ data: Data, maxDimension: CGFloat = maxDimension) -> Data? {
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        let original = image.size
        guard original.width > 0, original.height > 0 else { return nil }

        let scale = min(1, maxDimension / max(original.width, original.height))
        let target = CGSize(width: original.width * scale, height: original.height * scale)

        let resized = NSImage(size: target)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: CGRect(origin: .zero, size: target),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }

        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        #else
        guard let image = UIImage(data: data) else { return nil }
        let original = image.size
        guard original.width > 0, original.height > 0 else { return nil }

        let scale = min(1, maxDimension / max(original.width, original.height))
        let target = CGSize(width: original.width * scale, height: original.height * scale)

        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }

        return resized.jpegData(compressionQuality: 0.85)
        #endif
    }

    static func crop(
        _ data: Data,
        zoom: CGFloat,
        offset: CGSize,
        viewport: CGFloat,
        maxDimension: CGFloat = maxDimension
    ) -> Data? {
        guard viewport > 0 else { return nil }

        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let rect = cropRect(
            imageSize: size,
            zoom: zoom,
            offset: offset,
            viewport: viewport
        )

        let unitRect = CGRect(
            x: rect.minX / size.width,
            y: rect.minY / size.height,
            width: rect.width / size.width,
            height: rect.height / size.height
        )

        let pixelRect = CGRect(
            x: unitRect.minX * CGFloat(cgImage.width),
            y: unitRect.minY * CGFloat(cgImage.height),
            width: unitRect.width * CGFloat(cgImage.width),
            height: unitRect.height * CGFloat(cgImage.height)
        ).integral

        guard let cropped = cgImage.cropping(to: pixelRect) else { return nil }

        let target = NSSize(width: maxDimension, height: maxDimension)
        let output = NSImage(size: target)
        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: cropped, size: NSSize(width: pixelRect.width, height: pixelRect.height))
            .draw(
                in: CGRect(origin: .zero, size: CGSize(width: maxDimension, height: maxDimension)),
                from: .zero,
                operation: .copy,
                fraction: 1
            )
        output.unlockFocus()

        guard let tiff = output.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        #else
        guard let source = UIImage(data: data) else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let normalized = UIGraphicsImageRenderer(size: source.size, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: source.size))
        }

        guard let cgImage = normalized.cgImage else { return nil }
        let size = normalized.size

        let rect = cropRect(
            imageSize: size,
            zoom: zoom,
            offset: offset,
            viewport: viewport
        )

        let unitRect = CGRect(
            x: rect.minX / size.width,
            y: rect.minY / size.height,
            width: rect.width / size.width,
            height: rect.height / size.height
        )

        let pixelRect = CGRect(
            x: unitRect.minX * CGFloat(cgImage.width),
            y: unitRect.minY * CGFloat(cgImage.height),
            width: unitRect.width * CGFloat(cgImage.width),
            height: unitRect.height * CGFloat(cgImage.height)
        ).integral

        guard let cropped = cgImage.cropping(to: pixelRect) else { return nil }

        let outputFormat = UIGraphicsImageRendererFormat.default()
        outputFormat.scale = 1
        let output = UIGraphicsImageRenderer(
            size: CGSize(width: maxDimension, height: maxDimension),
            format: outputFormat
        ).image { _ in
            UIImage(cgImage: cropped).draw(
                in: CGRect(x: 0, y: 0, width: maxDimension, height: maxDimension)
            )
        }

        return output.jpegData(compressionQuality: 0.9)
        #endif
    }

    private static func cropRect(
        imageSize: CGSize,
        zoom: CGFloat,
        offset: CGSize,
        viewport: CGFloat
    ) -> CGRect {
        let safeZoom = max(1, zoom)
        let fillScale = max(viewport / imageSize.width, viewport / imageSize.height)
        let displayScale = fillScale * safeZoom
        let displayed = CGSize(
            width: imageSize.width * displayScale,
            height: imageSize.height * displayScale
        )

        let cropWidth = min(imageSize.width, viewport / displayScale)
        let cropHeight = min(imageSize.height, viewport / displayScale)

        let originX = (displayed.width / 2 - viewport / 2 - offset.width) / displayScale
        let originY = (displayed.height / 2 - viewport / 2 - offset.height) / displayScale

        return CGRect(
            x: max(0, min(imageSize.width - cropWidth, originX)),
            y: max(0, min(imageSize.height - cropHeight, originY)),
            width: cropWidth,
            height: cropHeight
        )
    }
}
