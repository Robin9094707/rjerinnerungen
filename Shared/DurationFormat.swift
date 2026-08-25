import Foundation

enum DurationFormat {
    static func clock(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded(.down)))
        let h = value / 3600
        let m = (value % 3600) / 60
        let s = value % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    static func compact(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded()))
        if value >= 3600 {
            let h = value / 3600
            let m = (value % 3600) / 60
            return m == 0 ? "\(h) h" : "\(h) h \(m) min"
        }
        if value >= 60 {
            let m = value / 60
            let s = value % 60
            return s == 0 ? "\(m) min" : "\(m) min \(s) s"
        }
        return "\(value) s"
    }
}
