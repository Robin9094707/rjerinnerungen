import Charts
import SwiftData
import SwiftUI

private struct PriorityMetric: Identifiable {
    let priority: ReminderPriority
    let count: Int
    var id: String { priority.rawValue }
}

struct InsightsView: View {
    @Query private var reminders: [RJReminder]

    private var open: [RJReminder] { reminders.filter { !$0.isCompleted } }
    private var completed: [RJReminder] { reminders.filter(\.isCompleted) }
    private var overdue: [RJReminder] { open.filter(\.isOverdue) }
    private var completionRate: Int {
        guard !reminders.isEmpty else { return 0 }
        return Int((Double(completed.count) / Double(reminders.count) * 100).rounded())
    }
    private var metrics: [PriorityMetric] {
        ReminderPriority.allCases.map { priority in
            PriorityMetric(priority: priority, count: open.filter { $0.priority == priority }.count)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            stat("Offen", value: "\(open.count)", symbol: "bell")
                            stat("Überfällig", value: "\(overdue.count)", symbol: "exclamationmark.triangle")
                        }
                        HStack(spacing: 12) {
                            stat("Erledigt", value: "\(completed.count)", symbol: "checkmark.circle")
                            stat("Quote", value: "\(completionRate)%", symbol: "chart.line.uptrend.xyaxis")
                        }

                        UltraCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Offene nach Priorität").font(.headline)
                                Chart(metrics) { metric in
                                    BarMark(
                                        x: .value("Priorität", metric.priority.title),
                                        y: .value("Anzahl", metric.count)
                                    )
                                    .annotation(position: .top) {
                                        if metric.count > 0 { Text("\(metric.count)").font(.caption2) }
                                    }
                                }
                                .frame(height: 230)
                                .chartYAxis { AxisMarks(position: .leading) }
                            }
                        }

                        UltraCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Ultra Focus", systemImage: "bolt.shield.fill").font(.headline)
                                let ultra = open.filter { $0.priority == .ultra || $0.priority == .urgent }
                                if ultra.isEmpty {
                                    Text("Aktuell gibt es keine dringenden oder Ultra-Erinnerungen.").foregroundStyle(.secondary)
                                } else {
                                    ForEach(ultra.prefix(5)) { item in
                                        HStack {
                                            Text(item.title).lineLimit(1)
                                            Spacer()
                                            Text(item.hasDueDate ? item.dueDate.formatted(date: .omitted, time: .shortened) : "—")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Insights")
        }
    }

    private func stat(_ title: String, value: String, symbol: String) -> some View {
        UltraCard {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.title.bold()).contentTransition(.numericText())
            }
        }
    }
}
