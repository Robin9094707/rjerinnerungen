# Features

## Erinnerungen

- 6 Prioritäten: Niedrig, Normal, Wichtig, Hoch, Dringend, Ultra
- Kategorien und freie Tags
- Notizen
- Ohne Termin oder mit Datum/Uhrzeit
- Wiederholung: täglich, Mo–Fr, wöchentlich, monatlich, jährlich
- Vorwarnungen: 5 / 10 / 15 / 30 / 60 / 120 Minuten oder 1 Tag
- Standard-Snooze pro Erinnerung
- Suche nach Titel, Notiz und Tags
- Filter für offen, erledigt, alle und Ultra/Dringend

## Notifications

- lokale iOS-Notifications
- Passive / Active / Time Sensitive / Critical-Fallback je Priorität
- eigene Sounds für normale, dringende und Ultra-Erinnerungen
- Aktionen direkt aus der Notification:
  - Erledigt
  - +5 Minuten
  - +15 Minuten
  - +1 Stunde
- Badge wird beim Öffnen der App zurückgesetzt
- Testnotification aus den Einstellungen
- Notification Health / Pending-Count
- Neuaufbau der Notification-Planung

## Live Activity / Dynamic Island

- optional pro Erinnerung
- Countdown
- Titel, Priorität und Untertitel
- Lock Screen
- Dynamic Island compact / expanded / minimal
- bewusster Start aus der Detailansicht

## Apple Erinnerungen

- EventKit Vollzugriff erst nach Nutzerfreigabe
- Import offener Apple-Erinnerungen
- Duplikatschutz über `calendarItemIdentifier`
- Export einzelner RJ-Erinnerungen zurück zu Apple Erinnerungen
- einfache Übernahme von Priorität und Wiederholung

## Backup

- komplettes JSON-Backup
- JSON-Restore
- ISO-8601-Datumsformat
- konfliktarmer Import über UUID

## Siri & Kurzbefehle

- App Intent „Schnelle RJ-Erinnerung“
- Titel + Minuten + Priorität
- App Shortcut mit Siri-Phrasen
- Intent legt die Notification sofort an und synchronisiert den Datensatz beim nächsten App-Start in SwiftData

## UI/Qualität

- SwiftUI
- SwiftData
- iOS-26-Liquid-Glass mit Material-Fallback auf älteren unterstützten Systemen
- Dark Mode
- Dynamic Type
- VoiceOver-freundliche Labels
- SF Symbols
- Haptics
- Charts/Insights
- Empty States
- Debug-Konsole
