# Build Notes 2.0

## Reproduzierter Buildpfad

```text
macos-26
→ /Applications/Xcode_26.5.app
→ XcodeGen
→ Unit Tests im iPhone-17-Pro-Max-Simulator (iOS 26.5)
→ Release / iphoneos / generic iOS device
→ CODE_SIGNING_ALLOWED=NO
→ Payload/RJZeitZentrale.app
→ RJ-ZeitZentrale-unsigned.ipa
```

## Bundle-IDs

- App: `eu.rjuhas.zeitzentrale`
- Widget/Live Activity: `eu.rjuhas.zeitzentrale.widgets`
- Tests: `eu.rjuhas.zeitzentrale.tests`

## Signierung

Die GitHub-IPA ist absichtlich unsigniert. Der spätere Signierer muss die
Haupt-App und `RJZeitZentraleWidgets.appex` signieren. Für die lokale
Grundversion sind keine Secrets und kein Apple-Team im Repository nötig.

Die Vorlage `Configuration/RJZeitZentrale-iCloud.entitlements.example` wird
nicht automatisch in die unsigned IPA eingebunden. iCloud funktioniert nur,
wenn das eigene Developer-Profil den darin genannten Container erlaubt und
`CODE_SIGN_ENTITLEMENTS` beim signierten Build gesetzt wird.

## Behobene 1.0-Probleme

- Timer- und Verlaufsdaten liegen nun in Application Support und verwenden
  Dateischutz bis zur ersten Benutzeranmeldung. Das verhindert Cocoa-Fehler 513
  bei AlarmKit-Rückrufen auf einem gesperrten Gerät.
- Erinnerungen werden zuerst lokal gespeichert. Ein AlarmKit-/EventKit-Fehler
  wird anschließend als Warnung gemeldet und blockiert das Bearbeiten nicht.
- Fehlgeschlagene AlarmKit-Eskalationen erhalten einen normalen lokalen Hinweis
  als Fallback.
- mitgelieferte Audiodateien werden im Bundle und im Ressourcen-Unterordner
  aufgelöst; der Workflow prüft alle drei Dateien vor der IPA-Erstellung.
- der Snooze-Titel lautet „Schlummern“ und verwendet eine feste kontrastreiche
  Systemfarbe.

## Apple-Grenzen

- Critical Alerts: Das genehmigungspflichtige Entitlement
  `com.apple.developer.usernotifications.critical-alerts` ist nicht enthalten.
- Standort: Apple bietet keine AlarmKit-Ortsplanung. Orts-Erinnerungen verwenden
  `UNLocationNotificationTrigger` und benötigen die passende Systemfreigabe.
- Eigene Töne: WAV/AIFF/AIF/CAF, maximal 30 Sekunden, gespeichert unter
  `Library/Sounds`.

## Workflow

Der endgültige Workflow ist manuell über `workflow_dispatch` startbar. Jeder
Lauf validiert Plists und iCloud-Vorlage, generiert das Projekt, führt Tests aus,
baut ohne Codesignatur, prüft Ressourcen/Extension/Signatur und veröffentlicht
die IPA als GitHub-Actions-Artefakt.
