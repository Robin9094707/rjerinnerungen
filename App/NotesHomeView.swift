import SwiftUI

struct NotesHomeView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var query = ""
    @State private var editingNote: NoteItem?
    @State private var showNewNote = false

    private var filtered: [NoteItem] {
        let values = store.notes.sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            return $0.updatedAt > $1.updatedAt
        }
        guard !query.isEmpty else { return values }
        return values.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()
                if filtered.isEmpty {
                    ContentUnavailableView(
                        query.isEmpty ? "Noch keine Notizen" : "Nichts gefunden",
                        systemImage: query.isEmpty ? "note.text.badge.plus" : "magnifyingglass",
                        description: Text(query.isEmpty ? "Halte Ideen, Listen und Gedanken an einem Ort fest." : "Versuche einen anderen Suchbegriff.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(filtered) { note in
                                noteCard(note)
                            }
                        }
                        .padding()
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Notizen")
            .searchable(text: $query, prompt: "Notizen durchsuchen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewNote = true
                    } label: {
                        Label("Neue Notiz", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .sheet(isPresented: $showNewNote) { NoteEditorView() }
            .sheet(item: $editingNote) { NoteEditorView(note: $0) }
            .onChange(of: router.showNewNote) { _, requested in
                if requested {
                    showNewNote = true
                    router.showNewNote = false
                }
            }
            .onChange(of: router.requestedNoteID) { _, id in
                guard let id, let note = store.notes.first(where: { $0.id == id }) else { return }
                editingNote = note
                router.requestedNoteID = nil
            }
        }
    }

    private func noteCard(_ note: NoteItem) -> some View {
        Button {
            editingNote = note
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: note.pinned ? "pin.fill" : "note.text")
                        .foregroundStyle(note.color.color)
                    Spacer()
                    Menu {
                        Button(note.pinned ? "Loslösen" : "Anheften", systemImage: "pin") {
                            var value = note
                            value.pinned.toggle()
                            store.upsertNote(value)
                        }
                        Button("Löschen", systemImage: "trash", role: .destructive) {
                            store.deleteNote(note.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                Text(note.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(note.preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
                Spacer(minLength: 3)
                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Öffnet die Notiz zum Bearbeiten")
    }
}

struct NoteEditorView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var note: NoteItem

    init(note: NoteItem? = nil) {
        _note = State(initialValue: note ?? NoteItem(title: ""))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()
                VStack(spacing: 12) {
                    TextField("Titel", text: $note.title, axis: .vertical)
                        .font(.title.bold())
                        .textFieldStyle(.plain)
                    TextEditor(text: $note.body)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(12)
                        .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    HStack {
                        Toggle(isOn: $note.pinned) {
                            Label("Anheften", systemImage: "pin.fill")
                        }
                        .toggleStyle(.button)
                        Spacer()
                        ForEach(NoteColorToken.allCases) { token in
                            Button {
                                note.color = token
                            } label: {
                                Circle()
                                    .fill(token.color)
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        if note.color == token {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(token.rawValue)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(note.title.isEmpty ? "Neue Notiz" : "Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        store.upsertNote(note)
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }
}
