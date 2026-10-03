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

// 调试用：--once 刷新一次后退出；--dump 打印快照 JSON；--render <png> 把小组件界面渲染成图片
let args = CommandLine.arguments
if args.contains("--once") || args.contains("--dump") || args.contains("--render") {
    Refresher.run()
    if args.contains("--dump"), let d = try? Data(contentsOf: Shared.snapshotURL) {
        print(String(decoding: d, as: UTF8.self))
    }
    if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
        MainActor.assumeIsolated {
            let snap = UsageSnapshot.load()
            for (tab, size, kind, suffix) in [(UsageTab.overview, CGSize(width: 715, height: 345), UsageSize.large, "xl"),
                                              (.overview, CGSize(width: 345, height: 345), .large, "l"),
                                              (.overview, CGSize(width: 345, height: 165), .medium, "m"),
                                              (.models, CGSize(width: 345, height: 165), .medium, "m-models"),
                                              (.overview, CGSize(width: 165, height: 165), .small, "s")] {
                let view = UsageView(snapshot: snap, tab: tab, range: .all, size: kind, selectedDay: StatsEngine.dayKey(Date()))
                    .padding(16).frame(width: size.width, height: size.height)
                    .background(Color(white: 0.93)).environment(\.colorScheme, .light)
                let r = ImageRenderer(content: view); r.scale = 2
                let url = URL(fileURLWithPath: args[i + 1].replacingOccurrences(of: ".png", with: "-\(suffix).png"))
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
