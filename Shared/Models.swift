import Foundation

import Darwin

// 没有描述文件就用不了 App Group：App 写到真实家目录下，小组件靠沙盒只读例外读取
enum Shared {
    static var realHome: String { String(cString: getpwuid(getuid())!.pointee.pw_dir) }
    static var dataDir: URL { URL(fileURLWithPath: realHome + "/Library/Application Support/ClaudeUsage") }
    static var snapshotURL: URL { dataDir.appendingPathComponent("snapshot.json") }
    // 切换页面的按钮和小组件跑在同一个扩展进程里，用扩展自己的偏好设置即可
    static var defaults: UserDefaults { .standard }
}

enum UsageTab: String, CaseIterable, Codable, Sendable { case overview, models }
enum UsageRange: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case all, d30, d7
    var label: String { switch self { case .all: "全部"; case .d30: "30天"; case .d7: "7天" } }
    var days: Int? { switch self { case .all: nil; case .d30: 30; case .d7: 7 } }
}

struct TokenCounts: Codable, Sendable {
    var input = 0, output = 0, cacheRead = 0, cacheWrite = 0
    var main: Int { input + output }
    var all: Int { input + output + cacheRead + cacheWrite }
    mutating func add(_ o: TokenCounts) {
        input += o.input; output += o.output; cacheRead += o.cacheRead; cacheWrite += o.cacheWrite
    }
}

struct ModelStats: Codable, Sendable, Identifiable {
    var name: String
    var replies: Int
    var tokens: TokenCounts
    var id: String { name }
}

struct RangeStats: Codable, Sendable {
    var sessions = 0
    var messages = 0
    var tokens = TokenCounts()
    var activeDays = 0
    var peakHour: Int?
    var favoriteModel: String?
    var models: [ModelStats] = []
}

struct HeatDay: Codable, Sendable {
    var date: String
    var messages: Int
    var tokens: Int  // 输入+输出
}

struct UsageSnapshot: Codable, Sendable {
    var generatedAt: Date
    var ranges: [UsageRange: RangeStats]
    var heatmap: [HeatDay]

    static var lastError = ""
    static func load() -> UsageSnapshot? {
        do {
            return try JSONDecoder.iso.decode(UsageSnapshot.self, from: Data(contentsOf: Shared.snapshotURL))
        } catch {
            lastError = "\(Shared.snapshotURL.path)\n\(error.localizedDescription)"
            return nil
        }
    }
}

extension JSONDecoder {
    static var iso: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
extension JSONEncoder {
    static var iso: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }
}

enum Fmt {
    static func compact(_ n: Int) -> String {
        let d = Double(n)
        switch d {
        case 1e9...: return String(format: "%.1fB", d / 1e9)
        case 1e6...: return String(format: "%.1fM", d / 1e6)
        case 1e4...: return String(format: "%.1fK", d / 1e3)
        default: return n.formatted()
        }
    }
    static func hour(_ h: Int?) -> String {
        guard let h else { return "—" }
        return "\(h):00"
    }
}
