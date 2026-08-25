import SwiftUI

struct TimerHomeView: View {
    @Environment(TimerStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showNewTimer = false

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        header

                        if store.activeTimers.isEmpty {
                            EmptyCard(
                                title: "Keine laufenden Timer",
                                message: "Starte einen eigenen Timer oder nutze einen Quick Preset.",
                                systemImage: "timer"
                            )
                        } else {
                            ForEach(store.activeTimers) { timer in
                                TimerCardView(timerID: timer.id)
                            }
                        }

                        quickPresets
                    }
                    .padding()
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Timer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewTimer = true
                        Haptics.impact(.light)
                    } label: {
                        Label("Neuer Timer", systemImage: "plus")
                    }
                    .ultraProminentButton()
                }
            }
            .sheet(isPresented: $showNewTimer) {
                NewTimerView()
            }
            .onChange(of: router.showNewTimer) { _, requested in
                if requested {
                    showNewTimer = true
                    router.showNewTimer = false
                }
            }
        }
    }

    private var header: some View {
        UltraGlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.cyan.opacity(0.18))
                        .frame(width: 58, height: 58)
                    Image(systemName: "timer.circle.fill")
                        .font(.system(size: 31))
                        .foregroundStyle(.cyan)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.activeTimers.isEmpty ? "Bereit" : "\(store.activeTimers.count) aktiv")
                        .font(.title2.bold())
                    Text("AlarmKit • Dynamic Island • Live Activity")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var quickPresets: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Start")
                .font(.headline)
                .padding(.horizontal, 4)

            GlassEffectContainer(spacing: 10) {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(store.presets.filter(\.favorite).prefix(4)) { preset in
                        Button {
                            Task { await store.startPreset(preset) }
                        } label: {
                            HStack {
                                Image(systemName: preset.symbol)
                                    .foregroundStyle(preset.accent.color)
                                VStack(alignment: .leading) {
                                    Text(preset.title)
                                        .font(.subheadline.bold())
                                    Text(DurationFormat.compact(preset.duration))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .glassEffect(
                                .regular.interactive(),
                                in: .rect(cornerRadius: 20)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
