import Foundation
import Observation

@MainActor
@Observable
final class DebugLogger {
    static let shared = DebugLogger()

    private(set) var lines: [String] = []

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    var logURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("RJ-ZeitZentrale-Debug.log")
    }

    func load() {
        guard let text = try? String(contentsOf: logURL, encoding: .utf8) else { return }
        lines = text.split(separator: "\n").suffix(800).map(String.init)
    }

    func log(_ message: String) {
        let line = "[\(formatter.string(from: .now))] \(message)"
        lines.append(line)
        if lines.count > 800 {
            lines.removeFirst(lines.count - 800)
        }
        print("[RJZeitZentrale] \(message)")
        append(line + "\n")
    }

    func clear() {
        lines.removeAll()
        try? FileManager.default.removeItem(at: logURL)
    }

    private func append(_ text: String) {
        let data = Data(text.utf8)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: data)
            return
        }

        do {
            let handle = try FileHandle(forWritingTo: logURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            print("Debug log write failed: \(error)")
        }
    }
}
