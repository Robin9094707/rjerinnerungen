# Build Notes

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

Die GitHub-IPA ist absichtlich unsigniert. Der spätere Signierer muss sowohl
die Haupt-App als auch `RJZeitZentraleWidgets.appex` signieren. AlarmKit,
ActivityKit und WidgetKit benötigen in diesem Projekt kein proprietäres Secret.

## Critical Alerts

Das Entitlement `com.apple.developer.usernotifications.critical-alerts` ist
nicht enthalten. Es wird von Apple nur nach Einzelfreigabe ausgestellt und darf
nicht als allgemein verfügbare Funktion vorausgesetzt werden.

## Workflow

Der Workflow ist bewusst manuell über `workflow_dispatch` startbar. Jeder Lauf
testet die App, baut sie ohne Codesignatur und veröffentlicht die IPA als
GitHub-Actions-Artefakt.
