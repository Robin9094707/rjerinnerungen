import SwiftUI

struct PresetsView: View {
    @Environment(TimerStore.self) private var store
    @State private var showAdd = false
    @State private var soundStore = CustomSoundStore.shared
    @State private var pendingDelete: TimerPreset?

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 155), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(store.presets) { preset in
                            presetCard(preset)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Presets")
            .toolbar {
                Button {
                    showAdd = true
                } label: {
                    Label("Preset", systemImage: "plus")
                }
                .ultraProminentButton()
            }
            .sheet(isPresented: $showAdd) {
                NewPresetView()
            }
            .alert("Preset löschen?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("Abbrechen", role: .cancel) { pendingDelete = nil }
                Button("Löschen", role: .destructive) {
                    if let preset = pendingDelete { store.deletePreset(preset.id) }
                    pendingDelete = nil
                }
            } message: {
                Text("Das Timer-Preset wird endgültig entfernt.")
            }
        }
    }

    private func presetCard(_ preset: TimerPreset) -> some View {
        Button {
            Task { await store.startPreset(preset) }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: preset.symbol)
                        .font(.title2)
                        .foregroundStyle(preset.accent.color)
                    Spacer()
                    Image(systemName: preset.favorite ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(preset.favorite ? .yellow : .secondary)
                }

                Spacer(minLength: 8)

                Text(preset.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(DurationFormat.compact(preset.duration))
                    .font(.title3.bold())
                    .monospacedDigit()
                    .foregroundStyle(preset.accent.color)

                Text(soundStore.title(for: preset.soundFile))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                store.togglePresetFavorite(preset.id)
            } label: {
                Label(
                    preset.favorite ? "Favorit entfernen" : "Als Favorit",
                    systemImage: preset.favorite ? "star.slash" : "star"
                )
            }
            Button("Löschen", systemImage: "trash", role: .destructive) {
                pendingDelete = preset
            }
        }
    }
}

struct NewPresetView: View {
    @Environment(TimerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = "Mein Timer"
    @State private var hours = 0
    @State private var minutes = 10
    @State private var seconds = 0
    @State private var symbol = "timer"
    @State private var accent: TimerAccentToken = .cyan
    @State private var soundFile = "glass_chime.wav"
    @State private var favorite = false
    @State private var soundStore = CustomSoundStore.shared
    @State private var showCancelConfirmation = false

    private var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset") {
                    TextField("Name", text: $title)
                    DurationPicker(hours: $hours, minutes: $minutes, seconds: $seconds)
                }

                Section("Darstellung") {
                    Picker("Akzent", selection: $accent) {
                        ForEach(TimerAccentToken.allCases) { token in
                            Text(token.title).tag(token)
                        }
                    }
                    Toggle("Quick-Start-Favorit", isOn: $favorite)
                }

                Section("Ton") {
                    Picker("Alarmton", selection: $soundFile) {
                        ForEach(soundStore.catalogItems) { sound in
                            Text(sound.title).tag(sound.fileName)
                        }
                    }
                }
            }
            .navigationTitle("Neues Preset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { showCancelConfirmation = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        store.addPreset(
                            TimerPreset(
                                title: title,
                                duration: duration,
                                symbol: symbol,
                                accent: accent,
                                soundFile: soundFile,
                                favorite: favorite
                            )
                        )
                        dismiss()
                    }
                    .disabled(duration < 1)
                }
            }
            .interactiveDismissDisabled()
            .alert("Preset verwerfen?", isPresented: $showCancelConfirmation) {
                Button("Weiter bearbeiten", role: .cancel) {}
                Button("Verwerfen", role: .destructive) { dismiss() }
            } message: {
                Text("Das noch nicht gespeicherte Timer-Preset geht verloren.")
            }
        }
    }
}
