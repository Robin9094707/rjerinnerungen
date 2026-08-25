import SwiftUI

struct OnboardingView: View {
    let completion: () -> Void

    @State private var page = 0
    @State private var alarmService = AlarmKitService.shared
    @State private var notificationService = NotificationService.shared
    @State private var eventService = EventKitService.shared

    private let pages: [(title: String, message: String, symbol: String, colors: [Color])] = [
        (
            "Deine Zeit. Eine Zentrale.",
            "Erinnerungen, Kalender, Timer, Wecker und Notizen – verbunden in einer ruhigen, schnellen Oberfläche.",
            "sparkles.rectangle.stack.fill",
            [.cyan, .blue]
        ),
        (
            "Prominent, wenn es zählt",
            "AlarmKit bringt Timer und wichtige Wecker auf Sperrbildschirm, Dynamic Island und StandBy – inklusive Snooze.",
            "bell.and.waves.left.and.right.fill",
            [.orange, .pink]
        ),
        (
            "Mit deinem iPhone verbunden",
            "Kalender und Apple Erinnerungen bleiben optional. Du entscheidest, was RJ ZeitZentrale sehen oder exportieren darf.",
            "iphone.gen3.radiowaves.left.and.right",
            [.purple, .cyan]
        )
    ]

    var body: some View {
        ZStack {
            UltraBackground()

            VStack(spacing: 22) {
                HStack {
                    Text("RJ")
                        .font(.headline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                    Spacer()
                    Text("\(page + 1) / \(pages.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                if page == pages.count - 1 {
                    permissionStrip
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Button {
                    if page < pages.count - 1 {
                        withAnimation(.smooth) { page += 1 }
                    } else {
                        Haptics.success()
                        completion()
                    }
                } label: {
                    Text(page == pages.count - 1 ? "ZeitZentrale starten" : "Weiter")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .padding(.top)
        }
        .interactiveDismissDisabled()
    }

    private func pageView(
        _ value: (title: String, message: String, symbol: String, colors: [Color])
    ) -> some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: value.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 176, height: 176)
                    .blur(radius: 22)
                    .opacity(0.34)
                Image(systemName: value.symbol)
                    .font(.system(size: 76, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        LinearGradient(
                            colors: value.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            Text(value.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(value.message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var permissionStrip: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                permissionButton("Hinweise", symbol: "app.badge.fill") {
                    Task { _ = await notificationService.requestAuthorization() }
                }
                permissionButton("Wecker", symbol: "alarm.waves.left.and.right.fill") {
                    Task { _ = await alarmService.requestAuthorization() }
                }
                permissionButton("Kalender", symbol: "calendar") {
                    Task { _ = await eventService.requestEventAccess() }
                }
            }
        }
        .padding(.horizontal)
    }

    private func permissionButton(
        _ title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.title3)
                Text(title)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.glass)
    }
}
