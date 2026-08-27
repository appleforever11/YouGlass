import AppKit
import Foundation

struct AmbientSample {
    let color: VideoAmbientColor
    let saturation: Double
    let luminance: Double
    let weight: Double
    let horizontalPosition: Double
}

extension VideoAmbientPalette {
    static func from(imageData: Data) -> VideoAmbientPalette? {
        guard let image = NSImage(data: imageData) else { return nil }
        return from(image: image)
    }

    static func from(image: NSImage) -> VideoAmbientPalette? {
        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        ) else { return nil }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        guard width > 0, height > 0 else { return nil }

        var samples: [AmbientSample] = []
        let columns = 12
        let rows = 8

        for row in 0..<rows {
            let y = min(height - 1, max(0, Int((Double(row) + 0.5) / Double(rows) * Double(height))))
            for column in 0..<columns {
                let x = min(width - 1, max(0, Int((Double(column) + 0.5) / Double(columns) * Double(width))))
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }

                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

                let components = [Double(red), Double(green), Double(blue)]
                let brightest = components.max() ?? 0
                let darkest = components.min() ?? 0
                guard brightest > 0.035, alpha > 0.01 else { continue }

                let saturation = brightest == 0 ? 0 : (brightest - darkest) / brightest
                let luminance = 0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
                let weight = (0.35 + saturation * 1.8) * (0.55 + min(luminance, 0.9))
                samples.append(
                    AmbientSample(
                        color: VideoAmbientColor(red: Double(red), green: Double(green), blue: Double(blue)),
                        saturation: saturation,
                        luminance: luminance,
                        weight: weight,
                        horizontalPosition: Double(column) / Double(max(columns - 1, 1))
                    )
                )
            }
        }

        guard !samples.isEmpty else { return nil }

        let primary = boosted(average(samples), saturation: 1.08)
        let rightSamples = samples.filter { $0.horizontalPosition > 0.42 }
        let secondary = boosted(average(rightSamples.isEmpty ? samples : rightSamples), saturation: 1.14)
        let accentSamples = Array(samples.sorted { $0.saturation > $1.saturation }.prefix(max(4, samples.count / 5)))
        let accent = boosted(average(accentSamples), saturation: 1.28)
        let averageSaturation = samples.reduce(0.0) { $0 + $1.saturation } / Double(samples.count)
        let averageContrast = samples.reduce(0.0) { $0 + abs($1.luminance - 0.5) } / Double(samples.count)

        return VideoAmbientPalette(
            primary: primary,
            secondary: secondary,
            accent: accent,
            energy: min(1, max(0, averageSaturation * 0.72 + averageContrast * 0.48))
        )
    }

    private static func average(_ samples: [AmbientSample]) -> VideoAmbientColor {
        guard !samples.isEmpty else { return neutral.primary }
        let totalWeight = max(samples.reduce(0.0) { $0 + $1.weight }, 0.001)
        return VideoAmbientColor(
            red: samples.reduce(0.0) { $0 + $1.color.red * $1.weight } / totalWeight,
            green: samples.reduce(0.0) { $0 + $1.color.green * $1.weight } / totalWeight,
            blue: samples.reduce(0.0) { $0 + $1.color.blue * $1.weight } / totalWeight
        )
    }

    private static func boosted(_ color: VideoAmbientColor, saturation: Double) -> VideoAmbientColor {
        let luminance = color.red * 0.2126 + color.green * 0.7152 + color.blue * 0.0722
        return VideoAmbientColor(
            red: min(1, max(0, luminance + (color.red - luminance) * saturation)),
            green: min(1, max(0, luminance + (color.green - luminance) * saturation)),
            blue: min(1, max(0, luminance + (color.blue - luminance) * saturation))
        )
    }
}
