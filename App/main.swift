import AppKit
import SwiftUI
import WidgetKit
import ServiceManagement

enum Refresher {
    static let queue = DispatchQueue(label: "refresh")

    static func run() {
        var cache = StatsEngine.loadCache()
        StatsEngine.scan(&cache)
        StatsEngine.saveCache(cache)
        let snap = StatsEngine.snapshot(from: cache)
        try? JSONEncoder.iso.encode(snap).write(to: Shared.snapshotURL, options: .atomic)
        WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsage")
    }
}

// 调试用：--once 刷新一次后退出；--dump 打印快照 JSON；--render <目录> 把各尺寸界面渲染成截图
let args = CommandLine.arguments
if args.contains("--once") || args.contains("--dump") || args.contains("--render") {
    Refresher.run()
    if args.contains("--dump"), let d = try? Data(contentsOf: Shared.snapshotURL) {
        print(String(decoding: d, as: UTF8.self))
    }
    if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
        MainActor.assumeIsolated {
            let snap = UsageSnapshot.load()
            let today = StatsEngine.dayKey(Date())
            let shots: [(UsageTab, CGSize, UsageSize, String?, String)] = [
                (.overview, CGSize(width: 715, height: 345), .large, nil, "extra-large"),
                (.overview, CGSize(width: 715, height: 345), .large, today, "extra-large-day"),
                (.overview, CGSize(width: 345, height: 345), .large, nil, "large"),
                (.overview, CGSize(width: 345, height: 345), .large, today, "large-day"),
                (.models, CGSize(width: 345, height: 345), .large, nil, "large-models"),
                (.overview, CGSize(width: 345, height: 165), .medium, nil, "medium"),
                (.overview, CGSize(width: 345, height: 165), .medium, today, "medium-day"),
                (.overview, CGSize(width: 165, height: 165), .small, nil, "small"),
                (.overview, CGSize(width: 165, height: 165), .small, today, "small-day")]
            for (tab, size, kind, day, suffix) in shots {
                // 截图用实色卡片，不要桌面上的玻璃透明效果
                let view = UsageView(snapshot: snap, tab: tab, range: .all, size: kind, selectedDay: day)
                    .padding(16).frame(width: size.width, height: size.height)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.965))
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 3))
                    .padding(20)
                    .environment(\.colorScheme, .light)
                let r = ImageRenderer(content: view); r.scale = 2
                let url = URL(fileURLWithPath: args[i + 1]).appendingPathComponent("\(suffix).png")
                if let tiff = r.nsImage?.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    try? png.write(to: url)
                }
            }
        }
    }
    exit(0)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var timer: Timer?
    func applicationDidFinishLaunching(_ n: Notification) {
        try? SMAppService.mainApp.register()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func refresh() { Refresher.queue.async { Refresher.run() } }
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
