import SwiftUI

struct NewTimerView: View {
    @Environment(TimerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("defaultSound") private var defaultSound = "glass_chime.wav"

    @State private var title = "Timer"
    @State private var hours = 0
    @State private var minutes = 5
    @State private var seconds = 0
    @State private var symbol = "timer"
    @State private var accent: TimerAccentToken = .cyan
    @State private var soundFile = "glass_chime.wav"
    @State private var soundStore = CustomSoundStore.shared
    @State private var showCancelConfirmation = false

    private let symbols = [
        "timer", "cup.and.saucer.fill", "mug.fill", "brain.head.profile.fill",
        "figure.run", "figure.strengthtraining.traditional", "gamecontroller.fill",
        "book.fill", "bed.double.fill", "flame.fill", "fork.knife", "bolt.fill"
    ]

    private var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()

                Form {
                    Section("Dauer") {
                        DurationPicker(
                            hours: $hours,
                            minutes: $minutes,
                            seconds: $seconds
                        )
                        .listRowBackground(Color.clear)
                    }

                    Section("Name") {
                        TextField("Timer-Name", text: $title)
                    }

                    Section("Symbol") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                            ForEach(symbols, id: \.self) { item in
                                Button {
                                    symbol = item
                                    Haptics.selection()
                                } label: {
                                    Image(systemName: item)
                                        .font(.title3)
                                        .frame(width: 38, height: 38)
                                        .background(
                                            item == symbol ? accent.color.opacity(0.18) : Color.clear,
                                            in: Circle()
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Section("Akzent") {
                        HStack {
                            ForEach(TimerAccentToken.allCases) { token in
                                Button {
                                    accent = token
                                    Haptics.selection()
                                } label: {
                                    AccentDot(accent: token, selected: accent == token)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Section("Ton") {
                        Picker("Alarmton", selection: $soundFile) {
                            ForEach(soundStore.catalogItems) { sound in
                                Label(sound.title, systemImage: sound.symbol)
                                    .tag(sound.fileName)
                            }
                        }

                        Button {
                            SoundPlayer.shared.preview(soundFile)
                        } label: {
                            Label("Ton anhören", systemImage: "speaker.wave.2.fill")
                        }
                    }

                    Section {
                        Label(
                            "AlarmKit zeigt den Timer systemweit auf Lock Screen, Dynamic Island und StandBy und kann nach deiner Freigabe auch bei Stummmodus/Focus alarmieren.",
                            systemImage: "bell.and.waves.left.and.right.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Neuer Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { showCancelConfirmation = true }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        Task {
                            await store.startTimer(
                                title: title,
                                duration: duration,
                                symbol: symbol,
                                accent: accent,
                                soundFile: soundFile
                            )
                            if store.lastError == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(duration < 1)
                    .ultraProminentButton()
                }
            }
            .onAppear {
                soundFile = defaultSound
            }
            .interactiveDismissDisabled()
            .alert("Timer nicht starten?", isPresented: $showCancelConfirmation) {
                Button("Weiter einstellen", role: .cancel) {}
                Button("Entwurf verwerfen", role: .destructive) { dismiss() }
            } message: {
                Text("Die eingestellte Dauer und alle Optionen gehen verloren.")
            }
        }
    }
}
