import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit

struct RJAlarmLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<RJTimerAlarmMetadata>.self) { context in
            lockScreenView(context)
                .activityBackgroundTint(.black.opacity(0.76))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(
                    URL(string: "rjzentrale://alarm/\(context.state.alarmID.uuidString)")
                )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: metadata(context).symbol)
                            .font(.title2)
                            .foregroundStyle(metadata(context).accent.color)
                        Text(metadata(context).title)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    timerText(context)
                        .font(.title3.bold())
                        .monospacedDigit()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        progress(context)
                        actionRow(context)
                    }
                }
            } compactLeading: {
                Image(systemName: metadata(context).symbol)
                    .foregroundStyle(metadata(context).accent.color)
            } compactTrailing: {
                timerText(context)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .frame(maxWidth: 54)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(metadata(context).accent.color)
            }
            .widgetURL(
                URL(string: "rjzentrale://alarm/\(context.state.alarmID.uuidString)")
            )
            .keylineTint(metadata(context).accent.color)
        }
    }

    private func lockScreenView(
        _ context: ActivityViewContext<AlarmAttributes<RJTimerAlarmMetadata>>
    ) -> some View {
        VStack(spacing: 13) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(metadata(context).accent.color.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: metadata(context).symbol)
                        .foregroundStyle(metadata(context).accent.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(metadata(context).title)
                        .font(.headline)
                        .lineLimit(1)
                    stateLabel(context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                timerText(context)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            progress(context)
            actionRow(context)
        }
        .padding(16)
    }

    @ViewBuilder
    private func timerText(
        _ context: ActivityViewContext<AlarmAttributes<RJTimerAlarmMetadata>>
    ) -> some View {
        switch context.state.mode {
        case .countdown(let countdown):
            let end = max(countdown.fireDate, Date.now)
            Text(
                timerInterval: Date.now...end,
                countsDown: true,
                showsHours: true
            )

        case .paused(let paused):
            Text(
                DurationFormat.clock(
                    max(0, paused.totalCountdownDuration - paused.previouslyElapsedDuration)
                )
            )

        case .alert:
            Text("00:00")

        @unknown default:
            Text("--:--")
        }
    }

    @ViewBuilder
    private func stateLabel(
        _ context: ActivityViewContext<AlarmAttributes<RJTimerAlarmMetadata>>
    ) -> some View {
        switch context.state.mode {
        case .countdown:
            Label(
                metadata(context).kind == .scheduledAlarm ? "Snooze läuft" : "Läuft",
                systemImage: "play.fill"
            )
        case .paused:
            Label("Pausiert", systemImage: "pause.fill")
        case .alert:
            Label(
                metadata(context).kind == .scheduledAlarm ? "Wecker" : "Fertig",
                systemImage: "bell.fill"
            )
        @unknown default:
            Text("Timer")
        }
    }

    @ViewBuilder
    private func progress(
        _ context: ActivityViewContext<AlarmAttributes<RJTimerAlarmMetadata>>
    ) -> some View {
        switch context.state.mode {
        case .countdown(let countdown):
            let start = countdown.startDate.addingTimeInterval(-countdown.previouslyElapsedDuration)
            let end = max(countdown.fireDate, start.addingTimeInterval(1))
            ProgressView(timerInterval: start...end, countsDown: true)
                .tint(metadata(context).accent.color)

        case .paused(let paused):
            let total = max(paused.totalCountdownDuration, 1)
            let remaining = max(0, total - paused.previouslyElapsedDuration)
            ProgressView(value: remaining, total: total)
                .tint(metadata(context).accent.color)

        case .alert:
            ProgressView(value: 0, total: 1)
                .tint(metadata(context).accent.color)

        @unknown default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func actionRow(
        _ context: ActivityViewContext<AlarmAttributes<RJTimerAlarmMetadata>>
    ) -> some View {
        HStack(spacing: 10) {
            switch context.state.mode {
            case .countdown:
                Button(
                    intent: PauseRJAlarmIntent(
                        alarmID: context.state.alarmID.uuidString
                    )
                ) {
                    Label("Pause", systemImage: "pause.fill")
                }
                .buttonStyle(.bordered)

                Button(
                    intent: StopRJAlarmIntent(
                        alarmID: context.state.alarmID.uuidString
                    )
                ) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)

            case .paused:
                Button(
                    intent: ResumeRJAlarmIntent(
                        alarmID: context.state.alarmID.uuidString
                    )
                ) {
                    Label("Weiter", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button(
                    intent: StopRJAlarmIntent(
                        alarmID: context.state.alarmID.uuidString
                    )
                ) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)

            case .alert:
                Button(
                    intent: RepeatRJAlarmIntent(
                        alarmID: context.state.alarmID.uuidString
                    )
                ) {
                    Label("Nochmal", systemImage: "repeat")
                }
                .buttonStyle(.borderedProminent)

                Button(
                    intent: StopRJAlarmIntent(
                        alarmID: context.state.alarmID.uuidString
                    )
                ) {
                    Label("Fertig", systemImage: "checkmark")
                }
                .buttonStyle(.bordered)

            @unknown default:
                EmptyView()
            }
        }
        .tint(metadata(context).accent.color)
    }

    private func metadata(
        _ context: ActivityViewContext<AlarmAttributes<RJTimerAlarmMetadata>>
    ) -> RJTimerAlarmMetadata {
        context.attributes.metadata ?? RJTimerAlarmMetadata(
            timerID: context.state.alarmID.uuidString,
            title: "RJ ZeitZentrale",
            symbol: "timer",
            accent: .cyan,
            originalDuration: 60,
            soundFile: "default"
        )
    }
}
