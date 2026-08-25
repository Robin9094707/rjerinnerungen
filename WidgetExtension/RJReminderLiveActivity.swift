import ActivityKit
import SwiftUI
import WidgetKit

struct RJReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: context.attributes.symbolName)
                    .font(.title2)
                    .frame(width: 38, height: 38)
                    .background(.thinMaterial, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.state.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.dueDate, style: .timer)
                        .font(.headline.monospacedDigit())
                    Text(context.attributes.priorityName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .activityBackgroundTint(.clear)
            .activitySystemActionForegroundColor(.primary)
            .widgetURL(URL(string: "rjultrareminders://reminder/\(context.attributes.reminderID.uuidString)"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.priorityName, systemImage: context.attributes.symbolName)
                        .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.dueDate, style: .timer)
                        .font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.title).font(.headline).lineLimit(1)
                        Text(context.state.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbolName)
            } compactTrailing: {
                Text(context.state.dueDate, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "bell.fill")
            }
            .widgetURL(URL(string: "rjultrareminders://reminder/\(context.attributes.reminderID.uuidString)"))
            .keylineTint(.accentColor)
        }
    }
}
