import Foundation

enum Shared {
    static let appGroup = "7C52KNT3ZW.com.lisixuan.ClaudeUsage"
    static var container: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)!
    }
    static var snapshotURL: URL { container.appendingPathComponent("snapshot.json") }
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup)! }
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
}

struct UsageSnapshot: Codable, Sendable {
    var generatedAt: Date
    var ranges: [UsageRange: RangeStats]
    var heatmap: [HeatDay]

    static func load() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: Shared.snapshotURL) else { return nil }
        return try? JSONDecoder.iso.decode(UsageSnapshot.self, from: data)
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
