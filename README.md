# RJ Ultra Erinnerungen

Eine vollständig native SwiftUI-Erinnerungs-App für iPhone und iPad, ausgelegt auf den GitHub-Workflow aus RJ's iOS Golden Master.

## Schnellstart

1. Inhalt dieses Ordners in ein neues GitHub-Repository laden.
2. GitHub → **Actions** → **Build RJ Ultra Erinnerungen IPA**.
3. **Run workflow** starten.
4. Artifact **RJ-Ultra-Reminders-unsigned-IPA** herunterladen.
5. Die IPA mit deinem eigenen Signaturdienst signieren/installieren.

Der Workflow baut bewusst ohne Signing (`CODE_SIGNING_ALLOWED=NO`). Die eingebettete Live-Activity-Extension wird gemeinsam mit der App in die IPA gepackt und muss beim späteren Signieren mit signiert werden.

## Systemvoraussetzungen

- Deployment Target: iOS/iPadOS 18.0+
- Build-Umgebung: GitHub `macos-26`, Xcode 26.5
- SwiftUI + SwiftData
- ActivityKit + WidgetKit
- UserNotifications
- EventKit
- AppIntents
- Charts

## Wichtiger Hinweis zu Erinnerungen im Hintergrund

Exakte Erinnerungszeitpunkte werden mit lokalen `UNNotificationRequest`s geplant. `BGAppRefreshTask` wird nur für opportunistische Wartung verwendet, weil iOS einen Background Refresh nicht zu einer exakten Uhrzeit garantiert.

## Critical Alerts

Die App enthält bereits den Codepfad für echte Critical Alerts inklusive kritischem Custom Sound. Apple verlangt dafür jedoch ein spezielles, von Apple freigegebenes Entitlement. Ohne dieses Entitlement fällt die Stufe **Ultra** automatisch auf **Time Sensitive** zurück.

`CriticalAlerts.entitlements.example` ist absichtlich **nicht** im Build aktiviert. Dadurch bleibt die unsigned IPA mit normalen Signaturdiensten kompatibel. Erst wenn dein Apple-Team das Entitlement besitzt, solltest du eine echte `.entitlements`-Datei aktivieren und in `project.yml` als `CODE_SIGN_ENTITLEMENTS` setzen.

## Datenschutz

- Erinnerungen liegen lokal in SwiftData.
- Apple-Erinnerungen werden nur nach ausdrücklicher EventKit-Freigabe gelesen.
- Kein externer Server und keine Tracking-SDKs.
- Debug-Logs enthalten keine Passwörter oder Tokens.
