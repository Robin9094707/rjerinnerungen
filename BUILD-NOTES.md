# Build Notes

## GitHub

Der Workflow ist absichtlich nahe an der bereits erprobten RJ-UltraTimer-Referenz gehalten:

```text
macos-26
→ Xcode 26.5
→ XcodeGen
→ Release / iphoneos / generic iOS device
→ CODE_SIGNING_ALLOWED=NO
→ Payload/RJ Ultra Erinnerungen.app
→ RJ-Ultra-Reminders-unsigned.ipa
```

Bei einem Buildfehler wird `RJ-Ultra-Reminders-build.log` automatisch als Artifact hochgeladen.

## Bundle IDs

- App: `eu.rjuhas.ultrareminders`
- Live Activity Extension: `eu.rjuhas.ultrareminders.widgets`

## Signing

Die Projektquelle enthält absichtlich keine Team-ID, Zertifikate oder Provisioning Profiles. Der externe Signaturdienst muss App und eingebettete `.appex` korrekt signieren.

## Critical Alerts

Nicht standardmäßig als Entitlement eingebettet. Siehe `CriticalAlerts.entitlements.example` und README.

## APIs

Das Deployment Target bleibt bei iOS 18.0. Liquid Glass wird mit `#available(iOS 26.0, *)` gekapselt. Dadurch bleibt die App auf iOS 18+ lauffähig, während ein Build mit Xcode 26.5 die neue Darstellung nutzen kann.
