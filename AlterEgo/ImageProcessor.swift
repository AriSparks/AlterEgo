import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ImageProcessor {
    static let maxDimension: CGFloat = 512

    static func prepare(_ data: Data) -> Data? {
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

        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
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

        return resized.jpegData(compressionQuality: 0.82)
        #endif
    }
}
