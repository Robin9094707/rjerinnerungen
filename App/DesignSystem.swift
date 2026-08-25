import SwiftUI

extension View {
    @ViewBuilder
    func ultraGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

struct UltraBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(.blue.opacity(0.10))
                .frame(width: 360, height: 360)
                .blur(radius: 80)
                .offset(x: 170, y: -280)
        }
    }
}

struct UltraCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ultraGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct PriorityBadge: View {
    let priority: ReminderPriority

    var body: some View {
        Label(priority.title, systemImage: priority.symbolName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .accessibilityLabel("Priorität \(priority.title)")
    }
}

struct EmptyStateCard: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }
}
