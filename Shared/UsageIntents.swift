import AppIntents
import WidgetKit

struct SelectSourceIntent: AppIntent {
    static var title: LocalizedStringResource = "切换来源"
    @Parameter(title: "来源") var source: String
    init() {}
    init(_ s: UsageSource) { source = s.rawValue }
    func perform() async throws -> some IntentResult {
        Shared.defaults.set(source, forKey: "source")
        return .result()
    }
}

struct SelectTabIntent: AppIntent {
    static var title: LocalizedStringResource = "切换页面"
    @Parameter(title: "页面") var tab: String
    init() {}
    init(_ t: UsageTab) { tab = t.rawValue }
    func perform() async throws -> some IntentResult {
        Shared.defaults.set(tab, forKey: "tab")
        return .result()
    }
}

struct SelectRangeIntent: AppIntent {
    static var title: LocalizedStringResource = "切换时间范围"
    @Parameter(title: "范围") var range: String
    init() {}
    init(_ r: UsageRange) { range = r.rawValue }
    func perform() async throws -> some IntentResult {
        Shared.defaults.set(range, forKey: "range")
        return .result()
    }
}

// 点格子、箭头和返回按钮用：设定查看日期，空字符串表示回到主界面
struct SetDayIntent: AppIntent {
    static var title: LocalizedStringResource = "设定查看日期"
    @Parameter(title: "日期") var day: String
    init() {}
    init(_ d: String) { day = d }
    func perform() async throws -> some IntentResult {
        Shared.defaults.set(day.isEmpty ? nil : day, forKey: "day")
        return .result()
    }
}

extension Shared {
    static var selectedDay: String? { defaults.string(forKey: "day") }
    static var source: UsageSource { UsageSource(rawValue: defaults.string(forKey: "source") ?? "") ?? .cli }
    static var tab: UsageTab { UsageTab(rawValue: defaults.string(forKey: "tab") ?? "") ?? .overview }
    static var range: UsageRange { UsageRange(rawValue: defaults.string(forKey: "range") ?? "") ?? .all }
}
