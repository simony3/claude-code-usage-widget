import SwiftUI
import AppIntents

struct UsageView: View {
    let snapshot: UsageSnapshot?
    let tab: UsageTab
    let range: UsageRange

    private var stats: RangeStats { snapshot?.ranges[range] ?? RangeStats() }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                pill("概览", tab == .overview, SelectTabIntent(.overview))
                pill("模型", tab == .models, SelectTabIntent(.models))
                Spacer()
                ForEach(UsageRange.allCases, id: \.self) { r in
                    pill(r.label, range == r, SelectRangeIntent(r))
                }
            }
            if snapshot == nil {
                Spacer()
                Text("还没有数据：请先打开一次「Claude 用量」App").font(.callout).foregroundStyle(.secondary)
                Spacer()
            } else if tab == .overview {
                overview
            } else {
                models
            }
        }
    }

    private func pill(_ title: String, _ on: Bool, _ intent: some AppIntent) -> some View {
        Button(intent: intent) {
            Text(title)
                .font(.system(size: 12, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? .primary : .secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(on ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear)))
        }
        .buttonStyle(.plain)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    card("会话", stats.sessions.formatted())
                    card("消息", stats.messages.formatted())
                    card("Token（输入+输出）", Fmt.compact(stats.tokens.main))
                }
                GridRow {
                    card("活跃天数", stats.activeDays.formatted())
                    card("高峰时段", Fmt.hour(stats.peakHour))
                    card("最常用模型", stats.favoriteModel ?? "—")
                }
            }
            Heatmap(days: snapshot?.heatmap ?? [])
            footer("用掉的 token 约是《小王子》全书的 \(max(1, stats.tokens.main / 22_000)) 倍")
        }
    }

    private var models: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(stats.models.prefix(4)) { m in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(m.name).font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("\(m.replies.formatted()) 次回复").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        mini("输入", m.tokens.input)
                        mini("输出", m.tokens.output)
                        mini("缓存读", m.tokens.cacheRead)
                        mini("缓存写", m.tokens.cacheWrite)
                    }
                }
                .padding(7)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
            }
            if stats.models.isEmpty {
                Text("这段时间没有使用记录").font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            footer("含缓存合计 \(Fmt.compact(stats.tokens.all))")
        }
    }

    private func card(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            Text(value).font(.system(size: 16, weight: .semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }

    private func mini(_ title: String, _ n: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(Fmt.compact(n)).font(.system(size: 12, weight: .medium)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func footer(_ text: String) -> some View {
        HStack {
            Text(text)
            Spacer()
            if let t = snapshot?.generatedAt { Text("更新于 \(t.formatted(date: .omitted, time: .shortened))") }
        }
        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
    }
}

struct Heatmap: View {
    let days: [HeatDay]
    private let gap: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let cell = (geo.size.height - gap * 6) / 7
            let cols = max(1, Int((geo.size.width + gap) / (cell + gap)))
            let cellW = (geo.size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
            let grid = layout(cols: cols)
            let levels = thresholds()
            HStack(spacing: gap) {
                ForEach(0..<cols, id: \.self) { c in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { r in
                            let v = grid[c][r]
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(color(v, levels))
                                .frame(width: cellW, height: cell)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // 最后一列是本周，行按周日到周六；今天之后的格子留空（-1）
    private func layout(cols: Int) -> [[Int]] {
        guard let last = days.last, let lastDate = Self.fmt.date(from: last.date) else {
            return Array(repeating: Array(repeating: 0, count: 7), count: cols)
        }
        let todayRow = Calendar.current.component(.weekday, from: lastDate) - 1
        var g = Array(repeating: Array(repeating: -1, count: 7), count: cols)
        for c in 0..<cols {
            for r in 0..<7 {
                let back = (cols - 1 - c) * 7 + (todayRow - r)
                if back < 0 { continue }
                let i = days.count - 1 - back
                g[c][r] = i >= 0 ? days[i].messages : 0
            }
        }
        return g
    }

    private func thresholds() -> [Int] {
        let v = days.map(\.messages).filter { $0 > 0 }.sorted()
        guard !v.isEmpty else { return [1, 1, 1] }
        return [0.25, 0.5, 0.75].map { v[Int(Double(v.count - 1) * $0)] }
    }

    private func color(_ v: Int, _ t: [Int]) -> Color {
        if v < 0 { return .clear }
        if v == 0 { return Color.primary.opacity(0.08) }
        let level = t.filter { v > $0 }.count
        return Color.blue.opacity([0.35, 0.55, 0.78, 1.0][level])
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}
