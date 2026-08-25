import Charts
import SwiftUI

struct HistoryView: View {
    @Environment(TimerStore.self) private var store
    @State private var showClearConfirmation = false
    @State private var pendingDeleteOffsets: IndexSet?

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()

                if store.history.isEmpty {
                    ScrollView {
                        EmptyCard(
                            title: "Noch kein Verlauf",
                            message: "Beendete Timer und deine Statistik erscheinen hier.",
                            systemImage: "chart.bar.xaxis"
                        )
                        .padding()
                    }
                } else {
                    List {
                        Section {
                            statsCard
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }

                        Section("Letzte Timer") {
                            ForEach(store.history) { item in
                                HStack {
                                    Circle()
                                        .fill(item.accent.color)
                                        .frame(width: 10, height: 10)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(.headline)
                                        Text(item.finishedAt, format: .dateTime.day().month().hour().minute())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing) {
                                        Text(DurationFormat.compact(item.actualDuration))
                                            .font(.subheadline.bold())
                                        Text(item.outcome == .completed ? "Fertig" : "Gestoppt")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .onDelete { pendingDeleteOffsets = $0 }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Verlauf")
            .toolbar {
                if !store.history.isEmpty {
                    Menu {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label("Verlauf löschen", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Gesamten Verlauf löschen?", isPresented: $showClearConfirmation) {
                Button("Abbrechen", role: .cancel) {}
                Button("Alles löschen", role: .destructive) { store.clearHistory() }
            } message: {
                Text("Alle Timer-Statistiken und Verlaufseinträge werden unwiderruflich entfernt.")
            }
            .alert("Verlaufseintrag löschen?", isPresented: Binding(
                get: { pendingDeleteOffsets != nil },
                set: { if !$0 { pendingDeleteOffsets = nil } }
            )) {
                Button("Abbrechen", role: .cancel) { pendingDeleteOffsets = nil }
                Button("Löschen", role: .destructive) {
                    if let offsets = pendingDeleteOffsets { store.deleteHistory(at: offsets) }
                    pendingDeleteOffsets = nil
                }
            }
        }
    }

    private var statsCard: some View {
        let points = lastSevenDays()

        return UltraGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Letzte 7 Tage")
                            .font(.headline)
                        Text("\(Int(points.reduce(0) { $0 + $1.minutes })) Minuten")
                            .font(.title2.bold())
                    }
                    Spacer()
                    Image(systemName: "chart.bar.fill")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                }

                Chart(points) { point in
                    BarMark(
                        x: .value("Tag", point.day, unit: .day),
                        y: .value("Minuten", point.minutes)
                    )
                    .foregroundStyle(.cyan.gradient)
                    .cornerRadius(5)
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    private struct DayPoint: Identifiable {
        let id = UUID()
        let day: Date
        let minutes: Double
    }

    private func lastSevenDays() -> [DayPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let next = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }

            let seconds = store.history
                .filter { $0.finishedAt >= day && $0.finishedAt < next && $0.outcome == .completed }
                .reduce(0) { $0 + $1.actualDuration }

            return DayPoint(day: day, minutes: seconds / 60)
        }
    }
}
