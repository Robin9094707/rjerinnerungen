import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderCoordinator.self) private var coordinator

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Heute", systemImage: "sparkles") }

            AllRemindersView()
                .tabItem { Label("Alle", systemImage: "checklist") }

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }

            SettingsView()
                .tabItem { Label("Mehr", systemImage: "gearshape") }
        }
        .task { await coordinator.bootstrap(context: modelContext) }
        .alert("RJ Ultra Erinnerungen", isPresented: Binding(
            get: { coordinator.message != nil },
            set: { if !$0 { coordinator.message = nil } }
        )) {
            Button("OK", role: .cancel) { coordinator.message = nil }
        } message: {
            Text(coordinator.message ?? "")
        }
        .alert("Fehler", isPresented: Binding(
            get: { coordinator.errorMessage != nil },
            set: { if !$0 { coordinator.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { coordinator.errorMessage = nil }
        } message: {
            Text(coordinator.errorMessage ?? "Unbekannter Fehler")
        }
    }
}
