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

    // Claude 风格星芒：12 道里细外粗的圆头放射线，长短、粗细、角度略有参差，显得手绘而非机械
    let center = NSPoint(x: body.midX, y: 590 * k)
    let lengths: [CGFloat] = [1.0, 0.80, 0.93, 0.76, 0.98, 0.84, 0.90, 0.78, 1.0, 0.82, 0.92, 0.80]
    let widths: [CGFloat] = [56, 48, 52, 46, 54, 50, 52, 46, 56, 48, 52, 48]
    let jitter: [CGFloat] = [0, 4, -3, 5, -2, 3, -4, 2, 1, -5, 3, -2]
    NSColor.white.setFill()
    for i in 0..<12 {
        let a = (CGFloat(i) * 30 + 90 + jitter[i]) * .pi / 180
        let len = 235 * k * lengths[i], w = widths[i] * k / 2, w0 = 9 * k
        let dir = NSPoint(x: cos(a), y: sin(a)), perp = NSPoint(x: -sin(a), y: cos(a))
        let tip = NSPoint(x: center.x + dir.x * (len - w), y: center.y + dir.y * (len - w))
        let ray = NSBezierPath()
        ray.move(to: NSPoint(x: center.x + perp.x * w0, y: center.y + perp.y * w0))
        ray.line(to: NSPoint(x: tip.x + perp.x * w, y: tip.y + perp.y * w))
        ray.line(to: NSPoint(x: tip.x - perp.x * w, y: tip.y - perp.y * w))
        ray.line(to: NSPoint(x: center.x - perp.x * w0, y: center.y - perp.y * w0))
        ray.close()
        ray.fill()
        NSBezierPath(ovalIn: NSRect(x: tip.x - w, y: tip.y - w, width: w * 2, height: w * 2)).fill()
    }

    // 底部一排热力图方格，越往右越亮，点明是用量统计
    let alphas: [CGFloat] = [0.25, 0.4, 0.3, 0.55, 0.7, 0.85, 1.0]
    let cell: CGFloat = 74 * k, gap: CGFloat = 18 * k
    let row = cell * 7 + gap * 6
    for (c, alpha) in alphas.enumerated() {
        let rect = NSRect(x: body.midX - row / 2 + CGFloat(c) * (cell + gap), y: 205 * k, width: cell, height: cell)
        NSColor.white.withAlphaComponent(alpha).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 18 * k, yRadius: 18 * k).fill()
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
