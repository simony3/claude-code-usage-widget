import AppIntents
import WidgetKit

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

struct SelectDayIntent: AppIntent {
    static var title: LocalizedStringResource = "查看某天用量"
    @Parameter(title: "日期") var day: String
    init() {}
    init(_ d: String) { day = d }
    // 再点同一天就收起
    func perform() async throws -> some IntentResult {
        Shared.defaults.set(Shared.selectedDay == day ? nil : day, forKey: "day")
        return .result()
    }
}

// 箭头和关闭按钮用：直接设定选中日期，空字符串表示收起
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
    static var tab: UsageTab { UsageTab(rawValue: defaults.string(forKey: "tab") ?? "") ?? .overview }
    static var range: UsageRange { UsageRange(rawValue: defaults.string(forKey: "range") ?? "") ?? .all }
}
