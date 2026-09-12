// Генератор іконки застосунку. Запускається через `make icon`.
//
// Малює все кодом, щоб у репозиторії не лежали бінарні PNG, які невідомо ким
// і як зроблені: вигляд іконки видно прямо тут і правиться цифрами нижче.
//
//   swift Tools/make-icon.swift <тека-призначення>
// створює <тека>/icon_16x16.png … icon_512x512@2x.png для iconutil.

import AppKit

// Символьні зображення потребують ініціалізованого NSApplication.
_ = NSApplication.shared

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
let outputURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

// MARK: - Параметри вигляду

let topColor = NSColor(srgbRed: 0.24, green: 0.72, blue: 0.53, alpha: 1)   // м'ятний
let bottomColor = NSColor(srgbRed: 0.09, green: 0.31, blue: 0.35, alpha: 1) // темна бірюза
let glyphName = "gamecontroller.fill"

/// Скільки полотна лишити порожнім по краях — так іконка стає в один ряд
/// з рештою в Dock, а не виглядає більшою за сусідні.
let marginRatio: CGFloat = 0.085
/// Радіус скруглення відносно сторони плитки — приблизно як у системних іконок.
let cornerRatio: CGFloat = 0.2237
/// Розмір гліфа відносно сторони плитки.
let glyphRatio: CGFloat = 0.58

// MARK: - Малювання

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let result = NSImage(size: image.size)
    result.lockFocus()
    image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    color.set()
    // Полотно прозоре, тож sourceAtop зачепить лише пікселі самого гліфа.
    NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
    result.unlockFocus()
    return result
}

func render(side: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let size = CGFloat(side)
    let margin = size * marginRatio
    let tile = NSRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
    let radius = tile.width * cornerRatio

    let shape = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
    shape.addClip()
    NSGradient(starting: topColor, ending: bottomColor)?.draw(in: tile, angle: -90)

    let glyphSide = tile.width * glyphRatio
    let config = NSImage.SymbolConfiguration(pointSize: glyphSide, weight: .medium)
    if let symbol = NSImage(systemSymbolName: glyphName, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let white = tinted(symbol, .white)
        let box = NSRect(
            x: tile.midX - white.size.width / 2,
            y: tile.midY - white.size.height / 2,
            width: white.size.width,
            height: white.size.height
        )
        white.draw(in: box)
    }

    return rep.representation(using: .png, properties: [:])
}

// MARK: - Запис набору

/// Пари «логічний розмір, множник» — саме ті, які очікує iconutil.
let variants: [(base: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1),
    (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]

for (base, scale) in variants {
    let suffix = scale == 1 ? "" : "@2x"
    let name = "icon_\(base)x\(base)\(suffix).png"
    guard let data = render(side: base * scale) else {
        FileHandle.standardError.write(Data("не вдалось намалювати \(name)\n".utf8))
        exit(1)
    }
    try data.write(to: outputURL.appendingPathComponent(name))
}

print("намальовано \(variants.count) розмірів у \(outputURL.path)")
