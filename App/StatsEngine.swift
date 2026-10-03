import Foundation

struct ModelDay: Codable {
    var replies = 0
    var tokens = TokenCounts()
}

struct DayAgg: Codable {
    var prompts = 0
    var hours = [Int](repeating: 0, count: 24)
    var models: [String: ModelDay] = [:]
    var replies: Int { models.values.reduce(0) { $0 + $1.replies } }
}

struct FileAgg: Codable {
    var size: Int
    var mtime: Double
    var isSubagent: Bool
    var days: [String: DayAgg]
}

enum StatsEngine {
    static let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
    // 统计口径改了就换文件名，旧缓存自动作废
    static let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaudeUsage")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cache-v1.json")
    }()

    static func loadCache() -> [String: FileAgg] {
        guard let d = try? Data(contentsOf: cacheURL) else { return [:] }
        return (try? JSONDecoder().decode([String: FileAgg].self, from: d)) ?? [:]
    }

    static func saveCache(_ c: [String: FileAgg]) {
        try? JSONEncoder().encode(c).write(to: cacheURL, options: .atomic)
    }

    static func scan(_ cache: inout [String: FileAgg]) {
        var alive = Set<String>()
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys)
        while let url = e?.nextObject() as? URL {
            guard url.pathExtension == "jsonl",
                  let v = try? url.resourceValues(forKeys: Set(keys)),
                  let size = v.fileSize, let mtime = v.contentModificationDate?.timeIntervalSince1970 else { continue }
            let path = url.path
            alive.insert(path)
            if let c = cache[path], c.size == size, c.mtime == mtime { continue }
            let sub = url.pathComponents.contains("subagents")
            cache[path] = FileAgg(size: size, mtime: mtime, isSubagent: sub, days: parse(url, isSubagent: sub))
        }
        for k in cache.keys where !alive.contains(k) { cache[k] = nil }
    }

    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let iso = ISO8601DateFormatter()
    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    static func dayKey(_ d: Date) -> String { dayFmt.string(from: d) }

    static func parse(_ url: URL, isSubagent: Bool) -> [String: DayAgg] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        var days: [String: DayAgg] = [:]
        var seen = Set<String>()
        let userTag = Data(#""type":"user""#.utf8), asstTag = Data(#""type":"assistant""#.utf8)
        for line in data.split(separator: 0x0A) {
            let isAsst = line.range(of: asstTag) != nil
            guard isAsst || line.range(of: userTag) != nil,
                  let o = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let type = o["type"] as? String, type == "user" || type == "assistant",
                  let ts = o["timestamp"] as? String,
                  let date = isoFrac.date(from: ts) ?? iso.date(from: ts),
                  let msg = o["message"] as? [String: Any] else { continue }
            let key = dayKey(date)
            let hour = Calendar.current.component(.hour, from: date)
            if type == "assistant" {
                // 同一次回复会按内容块拆成多行写，每行带同一份 usage，按 message.id 去重
                guard let id = msg["id"] as? String, seen.insert(id).inserted,
                      let model = msg["model"] as? String, model != "<synthetic>",
                      let u = msg["usage"] as? [String: Any] else { continue }
                var t = TokenCounts()
                t.input = u["input_tokens"] as? Int ?? 0
                t.output = u["output_tokens"] as? Int ?? 0
                t.cacheRead = u["cache_read_input_tokens"] as? Int ?? 0
                t.cacheWrite = u["cache_creation_input_tokens"] as? Int ?? 0
                days[key, default: DayAgg()].models[model, default: ModelDay()].replies += 1
                days[key]!.models[model]!.tokens.add(t)
                days[key]!.hours[hour] += 1
            } else {
                guard !isSubagent, o["isMeta"] as? Bool != true, o["isSidechain"] as? Bool != true,
                      isRealPrompt(msg["content"]) else { continue }
                days[key, default: DayAgg()].prompts += 1
                days[key]!.hours[hour] += 1
            }
        }
        return days
    }

    // 只算用户亲手发的话：排除工具结果、斜杠命令、系统注入、中断标记
    static func isRealPrompt(_ content: Any?) -> Bool {
        var text = ""
        if let s = content as? String { text = s }
        else if let blocks = content as? [[String: Any]] {
            if blocks.contains(where: { $0["type"] as? String == "tool_result" }) { return false }
            text = blocks.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined()
            if text.isEmpty && blocks.contains(where: { $0["type"] as? String == "image" }) { return true }
        }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && !t.hasPrefix("<") && !t.hasPrefix("[Request interrupted")
    }

    static func prettyModel(_ id: String) -> String {
        var parts = id.split(separator: "-").map(String.init)
        if parts.first == "claude" { parts.removeFirst() }
        parts.removeAll { $0.count == 8 && Int($0) != nil }
        guard let family = parts.first else { return id }
        let version = parts.dropFirst().joined(separator: ".")
        return family.prefix(1).uppercased() + family.dropFirst() + (version.isEmpty ? "" : " " + version)
    }

    static func snapshot(from cache: [String: FileAgg], now: Date = Date()) -> UsageSnapshot {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var ranges: [UsageRange: RangeStats] = [:]
        for r in UsageRange.allCases {
            let cutoff = r.days.map { dayKey(cal.date(byAdding: .day, value: -($0 - 1), to: today)!) } ?? ""
            var s = RangeStats()
            var hours = [Int](repeating: 0, count: 24)
            var activeDays = Set<String>()
            var models: [String: ModelStats] = [:]
            for f in cache.values {
                var active = false
                for (day, a) in f.days where day >= cutoff {
                    let n = a.prompts + a.replies
                    guard n > 0 else { continue }
                    active = true
                    activeDays.insert(day)
                    s.messages += n
                    for h in 0..<24 { hours[h] += a.hours[h] }
                    for (m, md) in a.models {
                        let name = prettyModel(m)
                        models[name, default: ModelStats(name: name, replies: 0, tokens: TokenCounts())].replies += md.replies
                        models[name]!.tokens.add(md.tokens)
                        s.tokens.add(md.tokens)
                    }
                }
                if active && !f.isSubagent { s.sessions += 1 }
            }
            s.activeDays = activeDays.count
            if let mx = hours.max(), mx > 0 { s.peakHour = hours.firstIndex(of: mx) }
            s.models = models.values.sorted { $0.tokens.all > $1.tokens.all }
            s.favoriteModel = models.values.max { $0.replies < $1.replies }?.name
            ranges[r] = s
        }
        var perDay: [String: Int] = [:]
        for f in cache.values { for (d, a) in f.days { perDay[d, default: 0] += a.prompts + a.replies } }
        let heat = (0..<371).reversed().map { back -> HeatDay in
            let k = dayKey(cal.date(byAdding: .day, value: -back, to: today)!)
            return HeatDay(date: k, messages: perDay[k] ?? 0)
        }
        return UsageSnapshot(generatedAt: now, ranges: ranges, heatmap: heat)
    }
}
