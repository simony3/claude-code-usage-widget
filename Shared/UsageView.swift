import SwiftUI
import AppIntents

enum UsageSize { case small, medium, large }

struct UsageView: View {
    let snapshot: UsageSnapshot?
    let tab: UsageTab
    let range: UsageRange
    var size: UsageSize = .large
    var selectedDay: String? = nil

    private var picked: HeatDay? { snapshot?.heatmap.first { $0.date == selectedDay } }
    private var heatmap: Heatmap { Heatmap(days: snapshot?.heatmap ?? [], selected: selectedDay) }
    private var today: String { snapshot?.heatmap.last?.date ?? "" }

    private func neighbor(_ d: HeatDay, _ step: Int) -> HeatDay? {
        guard let days = snapshot?.heatmap, let i = days.firstIndex(where: { $0.date == d.date }),
              days.indices.contains(i + step) else { return nil }
        return days[i + step]
    }

    private func dayBar(_ d: HeatDay, font: CGFloat, short: Bool = false) -> some View {
        HStack(spacing: 4) {
            arrow("chevron.left", neighbor(d, -1), font)
            Text(short ? "\(dayLabel(d)) \(Fmt.compact(d.tokens))"
                       : "\(dayLabel(d))：输入+输出 \(Fmt.compact(d.tokens)) token · 消息 \(d.messages.formatted())")
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            arrow("chevron.right", neighbor(d, 1), font)
            Spacer(minLength: 0)
            Button(intent: SetDayIntent("")) {
                Image(systemName: "xmark").font(.system(size: font - 1, weight: .semibold))
                    .frame(width: font + 8, height: font + 8)
                    .background(Circle().fill(.quaternary))
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: font)).foregroundStyle(.secondary)
    }

    private func arrow(_ icon: String, _ target: HeatDay?, _ font: CGFloat) -> some View {
        Button(intent: SetDayIntent(target?.date ?? "")) {
            Image(systemName: icon).font(.system(size: font, weight: .semibold))
                .frame(width: font + 10, height: font + 8)
                .background(RoundedRectangle(cornerRadius: 5).fill(.quaternary))
        }
        .buttonStyle(.plain)
        .disabled(target == nil)
        .opacity(target == nil ? 0.3 : 1)
    }

    private func dayLabel(_ d: HeatDay) -> String {
        let p = d.date.split(separator: "-").compactMap { Int($0) }
        return p.count == 3 ? "\(p[1])月\(p[2])日" : d.date
    }

    private var stats: RangeStats { snapshot?.ranges[size == .small ? .all : range] ?? RangeStats() }

    var body: some View {
        if snapshot == nil {
            Text("读不到数据：\(UsageSnapshot.lastError)").font(.system(size: 10)).foregroundStyle(.secondary)
        } else if size == .small {
            small
        } else if size == .medium {
            medium
        } else {
            full
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Claude Code · 全部").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Text(Fmt.compact(stats.tokens.main)).font(.system(size: 28, weight: .bold)).monospacedDigit()
                .minimumScaleFactor(0.6).lineLimit(1)
            Text("Token（输入+输出）").font(.system(size: 10)).foregroundStyle(.secondary)
            if let d = picked {
                dayBar(d, font: 10, short: true)
                heatmap
            } else {
                HStack(spacing: 10) {
                    Text("消息 \(stats.messages.formatted())")
                    Text("会话 \(stats.sessions)")
                }
                .font(.system(size: 11)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                // 格子太小点不准：整块热力图点一下先选中今天，之后用箭头切换
                Button(intent: SetDayIntent(today)) { heatmap.disabled(true) }.buttonStyle(.plain)
            }
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            header(font: 11)
            if tab == .overview {
                HStack(spacing: 8) {
                    VStack(spacing: 4) {
                        card("Token（输入+输出）", Fmt.compact(stats.tokens.main), compact: true)
                        card("消息", stats.messages.formatted(), compact: true)
                        if picked == nil { card("活跃天数", stats.activeDays.formatted(), compact: true) }
                    }
                    .frame(width: 112)
                    heatmap
                }
                if let d = picked { dayBar(d, font: 10) }
            } else {
                ForEach(stats.models.prefix(2)) { m in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.name).font(.system(size: 11, weight: .semibold))
                        HStack(spacing: 4) {
                            mini("输入", m.tokens.input); mini("输出", m.tokens.output)
                            mini("缓存读", m.tokens.cacheRead); mini("缓存写", m.tokens.cacheWrite)
                        }
                    }
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(.quaternary))
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func header(font: CGFloat) -> some View {
        HStack(spacing: 2) {
            pill("概览", tab == .overview, SelectTabIntent(.overview), font)
            pill("模型", tab == .models, SelectTabIntent(.models), font)
            Spacer()
            ForEach(UsageRange.allCases, id: \.self) { r in
                pill(r.label, range == r, SelectRangeIntent(r), font)
            }
        }
    }

    private var full: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(font: 12)
            if tab == .overview {
                overview
            } else {
                models
            }
        }
    }

    private func pill(_ title: String, _ on: Bool, _ intent: some AppIntent, _ size: CGFloat) -> some View {
        Button(intent: intent) {
            Text(title)
                .font(.system(size: size, weight: on ? .semibold : .regular))
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
            heatmap
            HStack {
                if let d = picked { dayBar(d, font: 11) }
                Spacer()
                updated
            }
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

    private func card(_ title: String, _ value: String, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 2) {
            Text(title).font(.system(size: compact ? 9 : 11)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            Text(value).font(.system(size: compact ? 14 : 16, weight: .semibold)).monospacedDigit()
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

    private var updated: some View {
        Group {
            if let t = snapshot?.generatedAt { Text("更新于 \(t.formatted(date: .omitted, time: .shortened))") }
        }
        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
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
    var selected: String? = nil
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
                            let i = grid[c][r]
                            let shape = RoundedRectangle(cornerRadius: 2.5)
                            if i < 0 {
                                Color.clear.frame(width: cellW, height: cell)
                            } else {
                                Button(intent: SelectDayIntent(days[i].date)) {
                                    shape.fill(color(days[i].messages, levels))
                                        .overlay(shape.stroke(Color.primary, lineWidth: days[i].date == selected ? 1.5 : 0))
                                        .frame(width: cellW, height: cell)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // 返回每格对应 days 的下标；最后一列是本周，行按周日到周六；今天之后或超出数据范围的格子为 -1
    private func layout(cols: Int) -> [[Int]] {
        guard let last = days.last, let lastDate = Self.fmt.date(from: last.date) else {
            return Array(repeating: Array(repeating: -1, count: 7), count: cols)
        }
        let todayRow = Calendar.current.component(.weekday, from: lastDate) - 1
        var g = Array(repeating: Array(repeating: -1, count: 7), count: cols)
        for c in 0..<cols {
            for r in 0..<7 {
                let back = (cols - 1 - c) * 7 + (todayRow - r)
                if back < 0 { continue }
                let i = days.count - 1 - back
                g[c][r] = i
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
        if v == 0 { return Color.primary.opacity(0.08) }
        let level = t.filter { v > $0 }.count
        return Color.blue.opacity([0.35, 0.55, 0.78, 1.0][level])
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}
