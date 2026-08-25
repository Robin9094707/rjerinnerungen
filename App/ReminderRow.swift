import SwiftUI

struct ReminderRow: View {
    let reminder: RJReminder

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : reminder.priority.symbolName)
                .font(.title3)
                .frame(width: 30)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 5) {
                Text(reminder.title)
                    .font(.headline)
                    .strikethrough(reminder.isCompleted)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if reminder.hasDueDate {
                        Label(reminder.dueDate.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    } else {
                        Label("Ohne Termin", systemImage: "calendar.badge.minus")
                    }
                    if reminder.recurrence != .none {
                        Label(reminder.recurrence.title, systemImage: "repeat")
                    }
                }
                .font(.caption)
                .foregroundStyle(reminder.isOverdue ? .red : .secondary)

                HStack {
                    Label(reminder.category.title, systemImage: reminder.category.symbolName)
                    Spacer()
                    PriorityBadge(priority: reminder.priority)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
