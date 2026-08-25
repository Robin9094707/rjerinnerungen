import PhotosUI
import SwiftUI

struct NotesHomeView: View {
    private enum Scope: String, CaseIterable, Identifiable {
        case all = "Alle"
        case pinned = "Angeheftet"
        case audio = "Audio"
        case images = "Bilder"
        case archived = "Archiv"
        case trash = "Papierkorb"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .all: "note.text"
            case .pinned: "pin.fill"
            case .audio: "waveform"
            case .images: "photo.on.rectangle"
            case .archived: "archivebox.fill"
            case .trash: "trash.fill"
            }
        }
    }

    @Environment(AppDataStore.self) private var store
    @Environment(AppRouter.self) private var router
    @AppStorage("notesGalleryMode") private var galleryMode = true

    @State private var query = ""
    @State private var editingNote: NoteItem?
    @State private var showNewNote = false
    @State private var showFolders = false
    @State private var scope: Scope = .all
    @State private var selectedFolderID: UUID?
    @State private var selectedTag: String?
    @State private var pendingTrash: NoteItem?
    @State private var pendingPermanentDelete: NoteItem?
    @State private var showEmptyTrashConfirmation = false

    private var filtered: [NoteItem] {
        let base: [NoteItem]
        switch scope {
        case .all: base = store.activeNotes
        case .pinned: base = store.activeNotes.filter(\.pinned)
        case .audio: base = store.activeNotes.filter { !$0.recordings.isEmpty }
        case .images: base = store.activeNotes.filter { !$0.attachments.isEmpty }
        case .archived: base = store.notes.filter { $0.archived && !$0.isTrashed }
        case .trash: base = store.trashedNotes
        }
        return base.filter { note in
            let folderMatches = selectedFolderID == nil || note.folderID == selectedFolderID
            let tagMatches = selectedTag == nil || note.normalizedTags.contains(selectedTag ?? "")
            let queryMatches = query.isEmpty
                || note.title.localizedCaseInsensitiveContains(query)
                || note.body.localizedCaseInsensitiveContains(query)
                || note.normalizedTags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            return folderMatches && tagMatches && queryMatches
        }.sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()
                ScrollView {
                    LazyVStack(spacing: 14) {
                        filters
                        if filtered.isEmpty {
                            ContentUnavailableView(
                                emptyTitle,
                                systemImage: scope == .trash ? "trash" : "note.text.badge.plus",
                                description: Text(emptyDescription)
                            )
                            .padding(.top, 50)
                        } else if galleryMode {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
                                spacing: 12
                            ) {
                                ForEach(filtered) { note in noteCard(note, gallery: true) }
                            }
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(filtered) { note in noteCard(note, gallery: false) }
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Notizen")
            .searchable(text: $query, prompt: "Text, Ordner oder Tags")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Ordner verwalten", systemImage: "folder.badge.gearshape") { showFolders = true }
                        Button(galleryMode ? "Als Liste" : "Als Galerie", systemImage: galleryMode ? "list.bullet" : "square.grid.2x2") {
                            galleryMode.toggle()
                        }
                        if scope == .trash, !store.trashedNotes.isEmpty {
                            Button("Papierkorb leeren", systemImage: "trash.slash", role: .destructive) {
                                showEmptyTrashConfirmation = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
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
            .sheet(isPresented: $showFolders) { NoteFolderManagerView() }
            .alert("Notiz in den Papierkorb?", isPresented: Binding(
                get: { pendingTrash != nil },
                set: { if !$0 { pendingTrash = nil } }
            )) {
                Button("Abbrechen", role: .cancel) { pendingTrash = nil }
                Button("Verschieben", role: .destructive) {
                    if let note = pendingTrash { store.moveNoteToTrash(note.id) }
                    pendingTrash = nil
                }
            } message: {
                Text("Die Notiz kann im Papierkorb wiederhergestellt werden.")
            }
            .alert("Endgültig löschen?", isPresented: Binding(
                get: { pendingPermanentDelete != nil },
                set: { if !$0 { pendingPermanentDelete = nil } }
            )) {
                Button("Abbrechen", role: .cancel) { pendingPermanentDelete = nil }
                Button("Endgültig löschen", role: .destructive) {
                    if let note = pendingPermanentDelete { store.permanentlyDeleteNote(note.id) }
                    pendingPermanentDelete = nil
                }
            } message: {
                Text("Text, Bilder und Sprachnotizen werden unwiderruflich gelöscht.")
            }
            .alert("Papierkorb leeren?", isPresented: $showEmptyTrashConfirmation) {
                Button("Abbrechen", role: .cancel) {}
                Button("Alles endgültig löschen", role: .destructive) { store.emptyNoteTrash() }
            } message: {
                Text("Alle Notizen und Medien im Papierkorb werden unwiderruflich gelöscht.")
            }
            .onChange(of: router.showNewNote) { _, requested in
                if requested { showNewNote = true; router.showNewNote = false }
            }
            .onChange(of: router.requestedNoteID) { _, id in
                guard let id, let note = store.notes.first(where: { $0.id == id }) else { return }
                editingNote = note
                router.requestedNoteID = nil
            }
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Scope.allCases) { value in
                        filterChip(value.rawValue, symbol: value.symbol, selected: scope == value) {
                            scope = value
                            if value == .trash || value == .archived { selectedFolderID = nil }
                        }
                    }
                }
            }
            if scope != .trash && scope != .archived {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("Alle Ordner", symbol: "tray.full", selected: selectedFolderID == nil) {
                            selectedFolderID = nil
                        }
                        ForEach(store.noteFolders) { folder in
                            filterChip(folder.name, symbol: folder.symbol, selected: selectedFolderID == folder.id) {
                                selectedFolderID = folder.id
                            }
                        }
                    }
                }
            }
            if !store.noteTags.isEmpty && scope != .trash {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        filterChip("Alle Tags", symbol: "tag", selected: selectedTag == nil) { selectedTag = nil }
                        ForEach(store.noteTags, id: \.self) { tag in
                            filterChip("#\(tag)", symbol: "number", selected: selectedTag == tag) { selectedTag = tag }
                        }
                    }
                }
            }
        }
    }

    private func filterChip(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? AnyShapeStyle(Color.cyan.gradient) : AnyShapeStyle(.thinMaterial), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func noteCard(_ note: NoteItem, gallery: Bool) -> some View {
        Button {
            if !note.isTrashed { editingNote = note }
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: note.pinned ? "pin.fill" : "note.text")
                        .foregroundStyle(note.color.color)
                    if let folder = store.noteFolders.first(where: { $0.id == note.folderID }) {
                        Text(folder.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    menu(for: note)
                }
                Text(note.title).font(.headline).lineLimit(2)
                Text(note.preview).font(.subheadline).foregroundStyle(.secondary).lineLimit(gallery ? 5 : 2)
                if note.hasMedia {
                    HStack(spacing: 10) {
                        if !note.attachments.isEmpty { Label("\(note.attachments.count)", systemImage: "photo") }
                        if !note.recordings.isEmpty { Label("\(note.recordings.count)", systemImage: "waveform") }
                    }
                    .font(.caption2).foregroundStyle(note.color.color)
                }
                if !note.normalizedTags.isEmpty {
                    Text(note.normalizedTags.prefix(3).map { "#\($0)" }.joined(separator: "  "))
                        .font(.caption2).foregroundStyle(.cyan).lineLimit(1)
                }
                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: gallery ? 190 : nil, alignment: .topLeading)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .contextMenu { contextMenu(for: note) }
    }

    private func menu(for note: NoteItem) -> some View {
        Menu {
            contextMenu(for: note)
        } label: {
            Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func contextMenu(for note: NoteItem) -> some View {
        if note.isTrashed {
            Button("Wiederherstellen", systemImage: "arrow.uturn.backward") { store.restoreNote(note.id) }
            Button("Endgültig löschen", systemImage: "trash", role: .destructive) { pendingPermanentDelete = note }
        } else {
            Button("Bearbeiten", systemImage: "pencil") { editingNote = note }
            Button(note.pinned ? "Loslösen" : "Anheften", systemImage: "pin") {
                var value = note; value.pinned.toggle(); _ = store.upsertNote(value)
            }
            Button(note.archived ? "Aus Archiv holen" : "Archivieren", systemImage: "archivebox") {
                var value = note; value.archived.toggle(); _ = store.upsertNote(value)
            }
            Button("In Papierkorb", systemImage: "trash", role: .destructive) { pendingTrash = note }
        }
    }

    private var emptyTitle: String {
        if !query.isEmpty { return "Nichts gefunden" }
        return scope == .trash ? "Papierkorb ist leer" : "Noch keine Notizen"
    }
    private var emptyDescription: String {
        if !query.isEmpty { return "Versuche einen anderen Suchbegriff oder Filter." }
        return scope == .trash ? "Gelöschte Notizen erscheinen hier." : "Erstelle Text, Checklisten, Bilder und Sprachnotizen."
    }
}

struct NoteEditorView: View {
    private enum PendingMediaDelete: Identifiable {
        case image(NoteAttachment)
        case recording(VoiceRecording)
        var id: String {
            switch self { case .image(let value): "image-\(value.id)"; case .recording(let value): "audio-\(value.id)" }
        }
    }

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var voiceService = VoiceNoteService()
    @State private var note: NoteItem
    @State private var tagsText: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showPreview = false
    @State private var showDiscardConfirmation = false
    @State private var pendingMediaDelete: PendingMediaDelete?
    @State private var newImageFiles: Set<String> = []
    @State private var newRecordingFiles: Set<String> = []
    @State private var filesToDeleteAfterSave: Set<String> = []
    @State private var mediaError: String?
    @State private var didSave = false

    private let original: NoteItem

    init(note: NoteItem? = nil) {
        let value = note ?? NoteItem(title: "")
        original = value
        _note = State(initialValue: value)
        _tagsText = State(initialValue: value.tags.map { "#\($0)" }.joined(separator: " "))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Titel", text: $note.title, axis: .vertical)
                            .font(.largeTitle.bold())
                            .textFieldStyle(.plain)

                        HStack {
                            Picker("Ordner", selection: $note.folderID) {
                                Text("Ohne Ordner").tag(UUID?.none)
                                ForEach(store.noteFolders) { folder in
                                    Label(folder.name, systemImage: folder.symbol).tag(Optional(folder.id))
                                }
                            }
                            Toggle(isOn: $note.pinned) { Image(systemName: "pin.fill") }
                                .toggleStyle(.button)
                        }

                        TextField("Tags: #privat #idee", text: $tagsText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))

                        formattingBar

                        if showPreview {
                            Text(markdownPreview)
                                .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
                                .padding(14)
                                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                        } else {
                            TextEditor(text: $note.body)
                                .font(.body)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 300)
                                .padding(12)
                                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                        }

                        imageSection
                        voiceSection
                        colorSection
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(note.title.isEmpty ? "Neue Notiz" : "Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasUnsavedChanges)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen", action: requestDismiss) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save).buttonStyle(.glassProminent)
                }
            }
            .alert("Änderungen verwerfen?", isPresented: $showDiscardConfirmation) {
                Button("Weiter bearbeiten", role: .cancel) {}
                Button("Verwerfen", role: .destructive) {
                    cleanupNewMedia(); dismiss()
                }
            } message: { Text("Neue Bilder, Aufnahmen und Textänderungen gehen verloren.") }
            .alert(item: $pendingMediaDelete) { pending in
                switch pending {
                case .image(let attachment):
                    Alert(
                        title: Text("Bild entfernen?"),
                        message: Text("Das Bild wird beim Speichern aus der App gelöscht."),
                        primaryButton: .destructive(Text("Entfernen")) { removeImage(attachment) },
                        secondaryButton: .cancel()
                    )
                case .recording(let recording):
                    Alert(
                        title: Text("Sprachnotiz löschen?"),
                        message: Text("Die Aufnahme wird beim Speichern endgültig gelöscht."),
                        primaryButton: .destructive(Text("Löschen")) { removeRecording(recording) },
                        secondaryButton: .cancel()
                    )
                }
            }
            .alert("Medien", isPresented: Binding(
                get: { mediaError != nil },
                set: { if !$0 { mediaError = nil } }
            )) { Button("OK") { mediaError = nil } } message: { Text(mediaError ?? "Unbekannter Fehler") }
            .onChange(of: selectedPhotos) { _, values in importPhotos(values) }
            .onDisappear {
                voiceService.stopPlayback()
                if !didSave { cleanupNewMedia() }
            }
        }
    }

    private var formattingBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                formatButton("Titel", symbol: "textformat.size.larger") { appendFormat("\n# Überschrift\n") }
                formatButton("Fett", symbol: "bold") { appendFormat("**fetter Text**") }
                formatButton("Kursiv", symbol: "italic") { appendFormat("_kursiver Text_") }
                formatButton("Liste", symbol: "list.bullet") { appendFormat("\n- Listenpunkt") }
                formatButton("Nummer", symbol: "list.number") { appendFormat("\n1. Listenpunkt") }
                formatButton("Checkliste", symbol: "checklist") { appendFormat("\n- [ ] Aufgabe") }
                formatButton("Zitat", symbol: "text.quote") { appendFormat("\n> Zitat") }
                formatButton("Tabelle", symbol: "tablecells") {
                    appendFormat("\n| Spalte 1 | Spalte 2 |\n| --- | --- |\n| Inhalt | Inhalt |")
                }
                formatButton("Link", symbol: "link") { appendFormat("[Titel](https://)") }
                formatButton("Code", symbol: "chevron.left.forwardslash.chevron.right") {
                    appendFormat("`Code`")
                }
                Button(showPreview ? "Bearbeiten" : "Vorschau", systemImage: showPreview ? "pencil" : "eye") {
                    showPreview.toggle()
                }.buttonStyle(.glass)
            }
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Bilder", systemImage: "photo.on.rectangle.angled").font(.headline)
                Spacer()
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 8, matching: .images) {
                    Label("Hinzufügen", systemImage: "plus")
                }.buttonStyle(.glass)
            }
            if !note.attachments.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 9)], spacing: 9) {
                    ForEach(note.attachments) { attachment in
                        ZStack(alignment: .topTrailing) {
                            if let image = NoteMediaStore.image(for: attachment) {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(height: 125).clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                ContentUnavailableView("Bild fehlt", systemImage: "photo.badge.exclamationmark")
                                    .frame(height: 125)
                            }
                            Button(role: .destructive) { pendingMediaDelete = .image(attachment) } label: {
                                Image(systemName: "xmark.circle.fill").font(.title2).symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.65))
                            }.buttonStyle(.plain).padding(6)
                        }
                    }
                }
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Sprachnotizen", systemImage: "waveform").font(.headline)
                Spacer()
                if voiceService.isRecording {
                    Button("Stoppen", systemImage: "stop.fill", role: .destructive) {
                        if let recording = voiceService.stopRecording() {
                            note.recordings.append(recording); newRecordingFiles.insert(recording.fileName)
                        }
                    }.buttonStyle(.glassProminent)
                } else {
                    Button("Aufnehmen", systemImage: "mic.fill") {
                        Task {
                            do { try await voiceService.startRecording() }
                            catch { mediaError = error.localizedDescription }
                        }
                    }.buttonStyle(.glass)
                }
            }
            if voiceService.isRecording {
                HStack(spacing: 10) {
                    Circle().fill(.red).frame(width: 10, height: 10)
                    Text(DurationFormat.clock(voiceService.recordingDuration)).monospacedDigit()
                    GeometryReader { proxy in
                        Capsule().fill(.red.gradient)
                            .frame(width: proxy.size.width * recordingLevel, height: 7)
                    }.frame(height: 7)
                }
            }
            ForEach($note.recordings) { $recording in
                HStack(spacing: 10) {
                    Button {
                        voiceService.togglePlayback(recording)
                    } label: {
                        Image(systemName: voiceService.playingRecordingID == recording.id ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                    }.buttonStyle(.plain)
                    VStack(alignment: .leading) {
                        TextField("Name", text: $recording.title).font(.subheadline.bold())
                        Text("\(DurationFormat.clock(recording.duration)) • \(recording.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) { pendingMediaDelete = .recording(recording) } label: {
                        Image(systemName: "trash")
                    }.buttonStyle(.plain)
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 15))
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private var colorSection: some View {
        HStack {
            Label("Farbe", systemImage: "paintpalette.fill")
            Spacer()
            ForEach(NoteColorToken.allCases) { token in
                Button { note.color = token } label: {
                    Circle().fill(token.color).frame(width: 27, height: 27).overlay {
                        if note.color == token { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) }
                    }
                }.buttonStyle(.plain).accessibilityLabel(token.title)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private var markdownPreview: AttributedString {
        (try? AttributedString(markdown: note.body)) ?? AttributedString(note.body)
    }
    private var recordingLevel: CGFloat {
        CGFloat(min(1, max(0.05, (voiceService.recordingLevel + 60) / 60)))
    }
    private var hasUnsavedChanges: Bool {
        note != original || tagsText != original.tags.map { "#\($0)" }.joined(separator: " ")
    }

    private func formatButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: symbol, action: action).buttonStyle(.glass)
    }
    private func appendFormat(_ text: String) {
        if !note.body.isEmpty, !text.hasPrefix("\n") { note.body += " " }
        note.body += text
    }
    private func importPhotos(_ values: [PhotosPickerItem]) {
        guard !values.isEmpty else { return }
        Task {
            for value in values {
                do {
                    if let photo = try await value.loadTransferable(type: ImportedNotePhoto.self) {
                        let attachment = try NoteMediaStore.importImage(photo.data)
                        note.attachments.append(attachment)
                        newImageFiles.insert(attachment.fileName)
                    }
                } catch { mediaError = error.localizedDescription }
            }
            selectedPhotos = []
        }
    }
    private func removeImage(_ attachment: NoteAttachment) {
        note.attachments.removeAll { $0.id == attachment.id }
        filesToDeleteAfterSave.insert(attachment.fileName)
    }
    private func removeRecording(_ recording: VoiceRecording) {
        voiceService.stopPlayback()
        note.recordings.removeAll { $0.id == recording.id }
        filesToDeleteAfterSave.insert(recording.fileName)
    }
    private func requestDismiss() {
        if hasUnsavedChanges { showDiscardConfirmation = true }
        else { dismiss() }
    }
    private func save() {
        if voiceService.isRecording, let recording = voiceService.stopRecording() {
            note.recordings.append(recording); newRecordingFiles.insert(recording.fileName)
        }
        note.tags = tagsText.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        guard store.upsertNote(note) else { return }
        for file in filesToDeleteAfterSave {
            if file.hasPrefix("note-image-") {
                AppPersistence.removeMediaFile(named: file, from: AppPersistence.attachmentsDirectory)
            } else {
                AppPersistence.removeMediaFile(named: file, from: AppPersistence.recordingsDirectory)
            }
        }
        didSave = true
        dismiss()
    }
    private func cleanupNewMedia() {
        voiceService.cancelRecording()
        for file in newImageFiles { AppPersistence.removeMediaFile(named: file, from: AppPersistence.attachmentsDirectory) }
        for file in newRecordingFiles { AppPersistence.removeMediaFile(named: file, from: AppPersistence.recordingsDirectory) }
        newImageFiles.removeAll(); newRecordingFiles.removeAll()
    }
}

struct NoteFolderManagerView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editingFolder: NoteFolder?
    @State private var showNewFolder = false
    @State private var pendingDelete: NoteFolder?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.noteFolders) { folder in
                        Button { editingFolder = folder } label: {
                            HStack {
                                Label(folder.name, systemImage: folder.symbol).foregroundStyle(folder.color.color)
                                Spacer()
                                Text("\(store.activeNotes.filter { $0.folderID == folder.id }.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button("Löschen", systemImage: "trash", role: .destructive) { pendingDelete = folder }
                        }
                    }
                } footer: {
                    Text("Beim Löschen eines Ordners bleiben seine Notizen erhalten und werden in „Ohne Ordner“ verschoben.")
                }
            }
            .navigationTitle("Ordner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Neuer Ordner", systemImage: "folder.badge.plus") { showNewFolder = true } }
            }
            .sheet(isPresented: $showNewFolder) { NoteFolderEditorView() }
            .sheet(item: $editingFolder) { NoteFolderEditorView(folder: $0) }
            .alert("Ordner löschen?", isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("Abbrechen", role: .cancel) { pendingDelete = nil }
                Button("Ordner löschen", role: .destructive) {
                    if let folder = pendingDelete { store.deleteFolder(folder.id) }
                    pendingDelete = nil
                }
            } message: { Text("Die enthaltenen Notizen werden nicht gelöscht.") }
        }
    }
}

struct NoteFolderEditorView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var folder: NoteFolder
    @State private var showDiscardConfirmation = false
    private let original: NoteFolder
    private let symbols = ["folder.fill", "person.crop.circle.fill", "briefcase.fill", "house.fill", "lightbulb.fill", "heart.fill", "cart.fill", "book.fill"]

    init(folder: NoteFolder? = nil) {
        let value = folder ?? NoteFolder(name: "")
        original = value
        _folder = State(initialValue: value)
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Ordnername", text: $folder.name)
                Picker("Symbol", selection: $folder.symbol) {
                    ForEach(symbols, id: \.self) { symbol in Label(symbol, systemImage: symbol).tag(symbol) }
                }
                Picker("Farbe", selection: $folder.color) {
                    ForEach(NoteColorToken.allCases) { token in Label(token.title, systemImage: "circle.fill").tag(token) }
                }
            }
            .navigationTitle(folder.name.isEmpty ? "Neuer Ordner" : "Ordner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        if folder != original { showDiscardConfirmation = true }
                        else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { if store.upsertFolder(folder) { dismiss() } }
                        .disabled(folder.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(folder != original)
            .alert("Ordner-Änderungen verwerfen?", isPresented: $showDiscardConfirmation) {
                Button("Weiter bearbeiten", role: .cancel) {}
                Button("Verwerfen", role: .destructive) { dismiss() }
            }
        }
    }
}
