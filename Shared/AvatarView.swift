import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }

        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)

        let red, green, blue, alpha: Double
        switch value.count {
        case 8:
            red = Double((number >> 24) & 0xFF) / 255
            green = Double((number >> 16) & 0xFF) / 255
            blue = Double((number >> 8) & 0xFF) / 255
            alpha = Double(number & 0xFF) / 255
        case 6:
            red = Double((number >> 16) & 0xFF) / 255
            green = Double((number >> 8) & 0xFF) / 255
            blue = Double(number & 0xFF) / 255
            alpha = 1
        default:
            red = 0.5
            green = 0.5
            blue = 0.5
            alpha = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

func platformImage(from data: Data) -> Image? {
    #if os(macOS)
    guard let image = NSImage(data: data) else { return nil }
    return Image(nsImage: image)
    #else
    guard let image = UIImage(data: data) else { return nil }
    return Image(uiImage: image)
    #endif
}

struct AvatarView: View {
    let alter: Alter
    var size: CGFloat = 56

    private var tint: Color { Color(hex: alter.colorHex) }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.gradient)

            if let data = alter.imageData, let image = platformImage(from: data) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Text(alter.emoji.isEmpty ? "🙂" : alter.emoji)
                    .font(.system(size: size * 0.5))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: max(1, size * 0.025))
        )
        .accessibilityLabel(alter.name)
    }
}

struct DiagonalStripes: View {
    let color: Color
    var spacing: CGFloat = 7

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x = -size.height
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            context.stroke(
                path,
                with: .color(color.opacity(0.9)),
                lineWidth: max(1.5, spacing * 0.34)
            )
        }
        .allowsHitTesting(false)
    }
}

struct FrontingBar: View {
    let color: Color
    let mode: FrontingMode
    var cornerRadius: CGFloat = 6
    var showStripes: Bool = true

    var body: some View {
        GeometryReader { geometry in
            let radius = min(cornerRadius, geometry.size.height / 2)
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

            ZStack {
                if mode == .full {
                    shape.fill(color)
                } else {
                    shape.fill(color.opacity(0.4))

                    if showStripes {
                        DiagonalStripes(color: color)
                            .clipShape(shape)
                    }

                    shape.strokeBorder(
                        color,
                        style: StrokeStyle(
                            lineWidth: 1.3,
                            dash: showStripes ? [4, 3] : [3, 2.5]
                        )
                    )
                }
            }
            .shadow(color: Color.black.opacity(0.10), radius: 1, y: 0.5)
        }
        .accessibilityHidden(true)
    }
}

struct StatusBadge: View {
    let mode: FrontingMode
    var compact: Bool = false

    private var color: Color {
        mode == .full ? Color.accentColor : Color.orange
    }

    var body: some View {
        Text(compact ? mode.shortLabel : mode.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.16), in: Capsule())
    }
}
