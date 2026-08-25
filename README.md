# RJ ZeitZentrale 2.0

RJ ZeitZentrale ist eine native iOS-All-in-one-App für Erinnerungen, Kalender,
AlarmKit-Wecker, Systemtimer und multimediale Notizen. Sie ist vollständig mit
SwiftUI und Apple-Frameworks umgesetzt, enthält keine Drittanbieter-SDKs und
speichert standardmäßig ausschließlich lokal.

## Highlights

- Dashboard, Liquid Glass, Dark Mode, Dynamic Type, VoiceOver und Haptics
- Erinnerungen mit frei wählbarem Start, Uhrzeit, Priorität, Liste und Tags
- stündliche, tägliche, wöchentliche, monatliche und jährliche Intervalle
- eigene Wochentage, Wiederholungsanzahl oder Enddatum und mehrere Vorwarnungen
- Orts-Erinnerungen beim Betreten oder Verlassen eines konfigurierbaren Radius
- optionale AlarmKit-Eskalation und Apple-Erinnerungen-Integration
- AlarmKit-Wecker mit Wochentagen, Voranzeige, Snooze und eigenen Audiodateien
- mehrere parallele AlarmKit-Timer, Presets, Statistik und Verlauf
- Notizordner, Tags, Anheften, Archiv, Papierkorb, Suche und Galerieansicht
- Markdown-Formatierung, Checklisten, Bilder und aufnehmbare Sprachnotizen
- optionale iCloud-Documents-Synchronisierung bei kompatibler eigener Signatur
- Home-Screen-Schnellaktionen, Widgets, Control Center, Live Activities,
  Dynamic Island und Siri-/Kurzbefehle-Intents
- atomische, migrationsfähige Speicherung und vollständiger Datenexport

Eine detaillierte Matrix steht in [FEATURES.md](FEATURES.md).

## Systemvoraussetzungen

- iOS/iPadOS 26.1 oder neuer
- Xcode 26.5 für den reproduzierbaren GitHub-Build
- AlarmKit- und Mitteilungsberechtigung für Systemtimer und Wecker
- Standortzugriff „Immer“ nur für freiwillige Orts-Erinnerungen
- Mikrofonzugriff nur beim Start einer Sprachnotiz

## Unsigned IPA in GitHub bauen

1. Den **gesamten Inhalt** dieses Ordners in die Wurzel eines GitHub-Repositories
   laden.
2. GitHub → `Actions` → `Build RJ ZeitZentrale IPA` öffnen.
3. `Run workflow` ausführen.
4. Nach erfolgreichem Test und Device-Build das Artifact
   `RJ-ZeitZentrale-unsigned-IPA` herunterladen.
5. Die IPA mit dem eigenen Dienst signieren. Die eingebettete
   `RJZeitZentraleWidgets.appex` muss ebenfalls signiert werden.

Der Workflow arbeitet mit `CODE_SIGNING_ALLOWED=NO`, prüft App-Icon, Töne,
Widget-Extension und Info.plist und veröffentlicht bewusst keine Zertifikate
oder Secrets. Bei einem Fehler wird `RJ-ZeitZentrale-build-log` erzeugt.

## Eigene Wecktöne

Über Einstellungen oder den Wecker-Editor lassen sich WAV-, AIFF-, AIF- und
CAF-Dateien mit höchstens 30 Sekunden importieren. Die App validiert die Datei,
kopiert sie nach `Library/Sounds`, bietet eine Vorschau und stellt beim Löschen
alle betroffenen Wecker und Presets sauber auf den Systemton zurück. Ein gerade
von einem laufenden Timer verwendeter Ton bleibt geschützt, bis der Timer endet.

## Optionale iCloud-Synchronisierung

Die ausgelieferte unsigned IPA enthält absichtlich kein fest verdrahtetes
iCloud-Entitlement. Damit bleibt sie mit normalen Sideload-Signaturen nutzbar.
Wenn dein Apple-Developer-Profil iCloud Documents unterstützt:

1. Für den App Identifier `eu.rjuhas.zeitzentrale` den Container
   `iCloud.eu.rjuhas.zeitzentrale` anlegen/aktivieren.
2. `Configuration/RJZeitZentrale-iCloud.entitlements.example` ohne die Endung
   `.example` kopieren.
3. Im App-Target `CODE_SIGN_ENTITLEMENTS` auf diese Datei setzen und mit einem
   passenden Provisioning Profile signieren.
4. In der App unter Einstellungen die Synchronisierung einschalten.

Ohne passendes Profil zeigt die App „Nicht in Signatur“ und alle lokalen
Funktionen arbeiten unverändert weiter. Die Synchronisierung ist ein privates
Datei-Mirroring mit Last-Write-Wins, keine Kollaborationsdatenbank.

## Datenschutz und Systemgrenzen

Es gibt kein Tracking, keine Werbung, kein Konto und keinen fremden Server.
Apple Kalender, Apple Erinnerungen, Standort, Mikrofon und iCloud werden nur
nach einer jeweiligen Systemfreigabe verwendet.

- Apple überwacht Ortsradien systemseitig; ein ortsabhängiger AlarmKit-Wecker
  existiert nicht, daher nutzt die App dort eine lokale Benachrichtigung.
- Echte Apple Critical Alerts benötigen ein individuell genehmigtes Entitlement.
  Es ist nicht enthalten. Hohe Prioritäten verwenden zeitkritische Hinweise;
  ein einmaliger Termin kann explizit als AlarmKit-Wecker eskaliert werden.
- Die App kann aus Datenschutzgründen nicht die Benachrichtigungen anderer Apps
  lesen oder als allgemeine Notification-Inbox übernehmen.

## Projektaufbau

```text
App/                 Haupt-App, Datenmodell, Services und SwiftUI-Oberflächen
Shared/              AlarmKit-Metadaten, Timer-Modelle und App Intents
WidgetExtension/     Live Activity, Dynamic Island, Widgets und Controls
Configuration/       optionale, nicht aktivierte iCloud-Entitlement-Vorlage
Tests/               Migration, Wiederholung und Kernlogik
.github/workflows/   reproduzierbarer unsigned IPA Build
project.yml          XcodeGen Source of Truth
```
