import SwiftUI

enum RJTheme {
    static let cyan = Color(red: 0.10, green: 0.82, blue: 0.96)
    static let blue = Color(red: 0.20, green: 0.42, blue: 1.00)
    static let violet = Color(red: 0.56, green: 0.28, blue: 1.00)
    static let pink = Color(red: 0.96, green: 0.28, blue: 0.62)
}

struct UltraBackground: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            RadialGradient(
                colors: [RJTheme.cyan.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 8,
                endRadius: 560
            )
            RadialGradient(
                colors: [RJTheme.violet.opacity(0.15), .clear],
                center: .bottomTrailing,
                startRadius: 8,
                endRadius: 600
            )
            LinearGradient(
                colors: [.clear, RJTheme.blue.opacity(0.05), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct UltraGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }
}

struct RJSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var symbol: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let symbol {
                    Label(title, systemImage: symbol)
                        .font(.headline)
                } else {
                    Text(title).font(.headline)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct RJMetric: View {
    let value: String
    let label: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}

struct AccentDot: View {
    let accent: TimerAccentToken
    let selected: Bool

    var body: some View {
        Circle()
            .fill(accent.color)
            .frame(width: selected ? 30 : 24, height: selected ? 30 : 24)
            .overlay {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
            .accessibilityLabel(accent.title)
    }
}

struct EmptyCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        UltraGlassCard {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text(message)
            )
            .frame(maxWidth: .infinity)
        }
    }
}

extension View {
    func ultraProminentButton() -> some View { buttonStyle(.glassProminent) }
    func ultraGlassButton() -> some View { buttonStyle(.glass) }
}
