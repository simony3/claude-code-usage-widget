// 生成 App 图标：swift scripts/make-icon.swift && iconutil -c icns build/AppIcon.iconset -o App/AppIcon.icns
import AppKit

func draw(_ px: Int) -> Data {
    let s = CGFloat(px), k = s / 1024
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS 图标网格：824 的圆角方形居中，留出投影空间
    let body = NSRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185 * k, yRadius: 185 * k)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 24 * k
    shadow.shadowOffset = NSSize(width: 0, height: -10 * k)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.white.setFill(); squircle.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(red: 0.91, green: 0.53, blue: 0.38, alpha: 1),
               ending: NSColor(red: 0.74, green: 0.34, blue: 0.20, alpha: 1))!.draw(in: squircle, angle: -90)

    // 4×4 热力图方格，越靠右下越亮，像最近用量在上升
    let alphas: [[CGFloat]] = [[0.22, 0.35, 0.22, 0.55],
                               [0.35, 0.22, 0.60, 0.80],
                               [0.22, 0.55, 0.80, 1.00],
                               [0.45, 0.80, 1.00, 1.00]]
    let cell: CGFloat = 132 * k, gap: CGFloat = 30 * k
    let grid = cell * 4 + gap * 3
    let origin = NSPoint(x: body.midX - grid / 2, y: body.midY - grid / 2)
    for r in 0..<4 {
        for c in 0..<4 {
            let rect = NSRect(x: origin.x + CGFloat(c) * (cell + gap),
                              y: origin.y + CGFloat(3 - r) * (cell + gap), width: cell, height: cell)
            NSColor.white.withAlphaComponent(alphas[r][c]).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 30 * k, yRadius: 30 * k).fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = URL(fileURLWithPath: "build/AppIcon.iconset")
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! draw(base).write(to: dir.appendingPathComponent("icon_\(base)x\(base).png"))
    try! draw(base * 2).write(to: dir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try! draw(1024).write(to: URL(fileURLWithPath: "docs/icon.png"))
