import SwiftUI
import WidgetKit

struct QuickCaptureEntry: TimelineEntry {
    let date: Date
}

struct QuickCaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickCaptureEntry { .init(date: .now) }

    func getSnapshot(
        in context: Context,
        completion: @escaping (QuickCaptureEntry) -> Void
    ) {
        completion(.init(date: .now))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<QuickCaptureEntry>) -> Void
    ) {
        completion(
            Timeline(
                entries: [.init(date: .now)],
                policy: .after(.now.addingTimeInterval(60 * 60))
            )
        )
    }
}

struct QuickCaptureWidget: Widget {
    let kind = "eu.rjuhas.zeitzentrale.capture"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCaptureProvider()) { _ in
            QuickCaptureWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("RJ Schnell erfassen")
        .description("Neue Erinnerung, Notiz oder Wecker direkt öffnen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickCaptureWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("ZeitZentrale", systemImage: "sparkles.rectangle.stack.fill")
                    .font(.headline)
                Spacer()
                Text(Date.now, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if family == .systemMedium {
                HStack(spacing: 8) {
                    captureLink("Erinnern", symbol: "checklist", url: "rjzentrale://new-reminder")
                    captureLink("Notieren", symbol: "note.text.badge.plus", url: "rjzentrale://new-note")
                    captureLink("Wecken", symbol: "alarm", url: "rjzentrale://new-alarm")
                }
            } else {
                VStack(spacing: 7) {
                    captureLink("Erinnerung", symbol: "checklist", url: "rjzentrale://new-reminder")
                    captureLink("Notiz", symbol: "note.text.badge.plus", url: "rjzentrale://new-note")
                }
            }
        }
    }

    private func captureLink(_ title: String, symbol: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Label(title, systemImage: symbol)
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
