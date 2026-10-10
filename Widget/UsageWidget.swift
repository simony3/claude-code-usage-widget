import WidgetKit
import SwiftUI

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot?
    let source: UsageSource
    let tab: UsageTab
    let range: UsageRange
    let selectedDay: String?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry { entry() }
    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
    private func entry() -> UsageEntry {
        UsageEntry(date: Date(), snapshot: UsageSnapshot.load(), source: Shared.source, tab: Shared.tab, range: Shared.range, selectedDay: Shared.selectedDay)
    }
}

struct UsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClaudeUsage", provider: Provider()) { e in
            FamilyView(entry: e).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Claude Code 用量小组件")
        .description("CLI 和桌面端分开统计：会话、消息、token 用量和每日活跃热力图")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

struct FamilyView: View {
    let entry: UsageEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        let size: UsageSize = family == .systemSmall ? .small : family == .systemMedium ? .medium : .large
        UsageView(snapshot: entry.snapshot, source: entry.source, tab: entry.tab, range: entry.range, size: size, selectedDay: entry.selectedDay)
    }
}

@main
struct UsageWidgetBundle: WidgetBundle {
    var body: some Widget { UsageWidget() }
}
