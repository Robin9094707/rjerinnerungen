import SwiftUI

struct DebugConsoleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logger = DebugLogger.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Log-Datei", value: logger.logURL.lastPathComponent)
                    ShareLink(item: logger.logURL) {
                        Label("Log teilen", systemImage: "square.and.arrow.up")
                    }
                }

                Section("Live Log") {
                    if logger.lines.isEmpty {
                        ContentUnavailableView(
                            "Keine Logs",
                            systemImage: "ladybug",
                            description: Text("Timer- und AlarmKit-Ereignisse erscheinen hier.")
                        )
                    } else {
                        ForEach(Array(logger.lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("Debug")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Leeren", role: .destructive) {
                        logger.clear()
                    }
                }
            }
            .onAppear { logger.load() }
        }
    }
}
