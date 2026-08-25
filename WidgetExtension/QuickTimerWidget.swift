import AppIntents
import SwiftUI
import WidgetKit

struct QuickTimerEntry: TimelineEntry {
    let date: Date
}

struct QuickTimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickTimerEntry {
        QuickTimerEntry(date: .now)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (QuickTimerEntry) -> Void
    ) {
        completion(QuickTimerEntry(date: .now))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<QuickTimerEntry>) -> Void
    ) {
        completion(
            Timeline(
                entries: [QuickTimerEntry(date: .now)],
                policy: .after(.now.addingTimeInterval(60 * 60))
            )
        )
    }
}

struct QuickTimerWidget: Widget {
    let kind = "eu.rjuhas.zeitzentrale.quick"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickTimerProvider()) { _ in
            QuickTimerWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Timer")
        .description("Starte Timer direkt vom Home- oder Lock-Screen.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular
        ])
    }
}

struct QuickTimerWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            medium
        case .accessoryRectangular:
            accessory
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("ZeitZentrale", systemImage: "timer")
                .font(.headline)

            Button(intent: StartFiveMinuteTimerIntent()) {
                Label("5 Minuten", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Text("AlarmKit")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("RJ ZeitZentrale", systemImage: "timer")
                    .font(.headline)
                Spacer()
                Text("Quick Start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                quickButton(1)
                quickButton(5)
                quickButton(10)

                Button(intent: StartPomodoroTimerIntent()) {
                    VStack {
                        Image(systemName: "brain.head.profile.fill")
                        Text("25m")
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var accessory: some View {
        HStack {
            Label("5-Min-Timer", systemImage: "timer")
            Spacer()
            Button(intent: StartFiveMinuteTimerIntent()) {
                Image(systemName: "play.fill")
            }
        }
    }

    private func quickButton(_ minutes: Int) -> some View {
        Button(
            intent: StartQuickTimerIntent(
                minutes: minutes,
                label: "\(minutes) Minuten"
            )
        ) {
            Text("\(minutes)m")
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}
