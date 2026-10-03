import WidgetKit
import SwiftUI

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot?
    let tab: UsageTab
    let range: UsageRange
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry { entry() }
    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
    private func entry() -> UsageEntry {
        UsageEntry(date: Date(), snapshot: UsageSnapshot.load(), tab: Shared.tab, range: Shared.range)
    }
}

struct UsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClaudeUsage", provider: Provider()) { e in
            UsageView(snapshot: e.snapshot, tab: e.tab, range: e.range)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Claude Code 用量")
        .description("会话、消息、token 用量和每日活跃热力图")
        .supportedFamilies([.systemLarge, .systemExtraLarge])
    }
}

@main
struct UsageWidgetBundle: WidgetBundle {
    var body: some Widget { UsageWidget() }
}
