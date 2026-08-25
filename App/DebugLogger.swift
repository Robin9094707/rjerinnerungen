import Foundation
import Observation

@MainActor
@Observable
final class DebugLogger {
    static let shared = DebugLogger()

    private(set) var entries: [String] = []
    private let maxEntries = 500

    private init() {
        entries = UserDefaults.standard.stringArray(forKey: "RJDebugEntries") ?? []
    }

    func log(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: .now)
        entries.append("[\(stamp)] \(message)")
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        UserDefaults.standard.set(entries, forKey: "RJDebugEntries")
    }

    func clear() {
        entries.removeAll()
        UserDefaults.standard.removeObject(forKey: "RJDebugEntries")
    }

    var exportText: String { entries.joined(separator: "\n") }
}
