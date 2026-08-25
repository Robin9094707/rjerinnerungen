import SwiftUI

struct TimerCardView: View {
    @Environment(TimerStore.self) private var store
    @State private var showStopConfirmation = false
    @State private var showDeleteConfirmation = false
    let timerID: UUID

    private var timer: TimerRecord? {
        store.timers.first(where: { $0.id == timerID })
    }

    var body: some View {
        if let timer {
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                let remaining = timer.remaining(at: context.date)
                let progress = timer.progress(at: context.date)

                UltraGlassCard {
                    VStack(spacing: 16) {
                        HStack {
                            Label(timer.title, systemImage: timer.symbol)
                                .font(.headline)
                                .foregroundStyle(timer.accent.color)

                            Spacer()

                            stateBadge(timer)
                        }

                        HStack(spacing: 18) {
                            progressRing(
                                progress: progress,
                                remaining: remaining,
                                timer: timer
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text(DurationFormat.clock(remaining))
                                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())

                                Text(timer.state == .paused ? "Pausiert" : "Verbleibend")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if timer.state == .running {
                                    Text("AlarmKit läuft im System")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()
                        }

                        controls(timer)
                    }
                }
            }
            .alert("Timer stoppen?", isPresented: $showStopConfirmation) {
                Button("Weiterlaufen lassen", role: .cancel) {}
                Button("Stoppen", role: .destructive) { store.stop(timer.id) }
            } message: {
                Text("Der laufende AlarmKit-Timer wird beendet und im Verlauf gespeichert.")
            }
            .alert("Timer löschen?", isPresented: $showDeleteConfirmation) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) { store.deleteTimer(timer.id) }
            } message: {
                Text("Der Timer wird aus der App und aus AlarmKit entfernt.")
            }
        }
    }

    private func progressRing(
        progress: Double,
        remaining: TimeInterval,
        timer: TimerRecord
    ) -> some View {
        ZStack {
            Circle()
                .stroke(timer.accent.color.opacity(0.16), lineWidth: 9)

            Circle()
                .trim(from: 0, to: max(0.002, 1 - progress))
                .stroke(
                    timer.accent.color.gradient,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.25), value: progress)

            Image(systemName: timer.symbol)
                .font(.title2)
                .foregroundStyle(timer.accent.color)
        }
        .frame(width: 94, height: 94)
        .accessibilityLabel("Timer-Fortschritt")
        .accessibilityValue("\(Int((1 - progress) * 100)) Prozent verbleibend")
    }

    private func stateBadge(_ timer: TimerRecord) -> some View {
        let descriptor: (text: String, symbol: String) = switch timer.state {
        case .running:
            ("Läuft", "play.fill")
        case .paused:
            ("Pause", "pause.fill")
        case .alerting:
            ("Fertig", "bell.fill")
        case .completed:
            ("Beendet", "checkmark")
        case .stopped:
            ("Gestoppt", "stop.fill")
        }

        return Label(descriptor.text, systemImage: descriptor.symbol)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(timer.accent.color.opacity(0.14), in: Capsule())
            .foregroundStyle(timer.accent.color)
    }

    private func controls(_ timer: TimerRecord) -> some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                if timer.state == .running {
                    Button {
                        store.pause(timer.id)
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .ultraGlassButton()
                } else if timer.state == .paused {
                    Button {
                        store.resume(timer.id)
                    } label: {
                        Label("Weiter", systemImage: "play.fill")
                    }
                    .ultraProminentButton()
                }

                Button {
                    Task { await store.addTime(timer.id, seconds: 60) }
                } label: {
                    Label("+1 min", systemImage: "plus.circle")
                }
                .ultraGlassButton()
                .disabled(timer.state == .alerting)

                Menu {
                    Button {
                        Task { await store.restart(timer.id) }
                    } label: {
                        Label("Neu starten", systemImage: "arrow.counterclockwise")
                    }

                    Button(role: .destructive) {
                        showStopConfirmation = true
                    } label: {
                        Label("Stoppen", systemImage: "stop.fill")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(minWidth: 34)
                }
                .ultraGlassButton()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
