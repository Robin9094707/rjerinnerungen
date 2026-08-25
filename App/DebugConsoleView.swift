import SwiftUI

struct DebugConsoleView: View {
    @State private var refreshID = UUID()

    var body: some View {
        List {
            Section {
                if DebugLogger.shared.entries.isEmpty {
                    Text("Noch keine Debug-Einträge.").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(DebugLogger.shared.entries.reversed().enumerated()), id: \.offset) { _, entry in
                        Text(entry).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
            } header: {
                Text("Lokales Diagnoseprotokoll")
            } footer: {
                Text("Es werden keine Passwörter, Tokens oder privaten Schlüssel protokolliert.")
            }
        }
        .id(refreshID)
        .navigationTitle("Debug")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: DebugLogger.shared.exportText) { Image(systemName: "square.and.arrow.up") }
                Button(role: .destructive) {
                    DebugLogger.shared.clear()
                    refreshID = UUID()
                } label: { Image(systemName: "trash") }
            }
        }
    }
}
