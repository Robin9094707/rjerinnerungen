# RJ ZeitZentrale

Eine native iOS-All-in-one-App für Erinnerungen, Kalender, AlarmKit-Wecker,
Systemtimer und Notizen. Das Projekt ist vollständig auf SwiftUI und Apple-
Frameworks aufgebaut und enthält keine Drittanbieter-Abhängigkeiten.

## Highlights

- Dashboard mit Live-Status und Schnellaktionen
- interne Erinnerungen mit Prioritäten und Wiederholung
- zeitkritische lokale Hinweise
- optionale AlarmKit-Eskalation für besonders wichtige Erinnerungen
- echte AlarmKit-Wecker mit Wiederholung, Snooze und Systemton
- mehrere parallele Systemtimer mit Live Activity und Dynamic Island
- Monatskalender mit optionaler Apple-Kalender-Ansicht
- optionaler Export zu Apple Erinnerungen
- lokale, durchsuchbare und anheftbare Notizen
- Home-Screen-Widgets und Control-Center-Steuerelemente
- App Intents / Siri-Kurzbefehle für Schnell-Timer
- Liquid Glass, Dark Mode, Dynamic Type, VoiceOver und Haptics
- vollständiger lokaler JSON-Export und persistente Debug-Konsole

## Systemvoraussetzungen

- iOS/iPadOS 26.1 oder neuer
- Xcode 26.5 für den reproduzierten GitHub-Build
- AlarmKit-Berechtigung für Systemtimer und Wecker
- Kalender- und Erinnerungszugriff nur bei freiwilliger Apple-Integration

## Unsigned IPA in GitHub bauen

1. Den gesamten Inhalt dieses Ordners in die Wurzel eines GitHub-Repositories
   hochladen.
2. In GitHub `Actions` öffnen.
3. `Build RJ ZeitZentrale IPA` auswählen.
4. `Run workflow` ausführen.
5. Nach erfolgreichem Build das Artifact
   `RJ-ZeitZentrale-unsigned-IPA` herunterladen.
6. Die enthaltene IPA mit dem eigenen Signierdienst signieren. Auch die
   eingebettete Widget-Extension muss dabei signiert werden.

Bei einem Fehler wird `RJ-ZeitZentrale-build-log` mit dem vollständigen Test-
oder Buildprotokoll erzeugt.

## Projektaufbau

```text
App/                 Haupt-App, Stores, Services und SwiftUI-Oberflächen
Shared/              gemeinsame AlarmKit-Modelle und App Intents
WidgetExtension/     Live Activity, Dynamic Island, Widgets und Controls
Tests/               deterministische Unit-Tests
.github/workflows/   unsigned IPA Build
project.yml          XcodeGen Source of Truth
```

## Datenschutz

Alle App-Daten bleiben standardmäßig lokal in der App. Es gibt kein Tracking,
keine Werbung, kein Benutzerkonto und keinen fremden Server. Apple Kalender und
Apple Erinnerungen werden erst nach ausdrücklicher Freigabe gelesen oder
beschrieben.

## Wichtige Grenze bei „kritischen“ Hinweisen

Apples echte Critical Alerts benötigen ein spezielles, individuell von Apple
genehmigtes Entitlement. Dieses Projekt behauptet diese Berechtigung nicht und
bleibt dadurch normal selbst signierbar. Für hohe Dringlichkeit nutzt die App
stattdessen zeitkritische Benachrichtigungen oder – explizit gewählt – einen
prominenten AlarmKit-Systemwecker.
