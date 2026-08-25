# Funktionsumfang 2.0

## Zentrale und Schnellzugriff

- Live-Datum, Tagesstatus, nächste Fälligkeit und aktive Timer
- Kennzahlen für offene Erinnerungen, Timer, aktive Notizen und Wecker
- Schnell-Erfassung für Erinnerung, Notiz, Timer und Wecker
- dieselben vier Aktionen per langem Druck auf das Home-Screen-App-Icon
- Deep Links für konkrete Einträge und neue Erfassungen

## Erinnerungen und Kalender

- Titel, Details, Liste, Tags, Priorität, Startdatum und optionale Uhrzeit
- ohne Termin, nur am Ort oder kombiniert als Zeit- und Orts-Erinnerung
- Wiederholung stündlich, täglich, wöchentlich, monatlich oder jährlich
- Intervall 1–99, eigene Wochentage, Ende nach Datum oder Anzahl
- mehrere Vorwarnungen von Fälligkeit bis zwei Tage vorher
- frei einstellbares „Später erinnern“ von 1–120 Minuten
- normale oder zeitkritische lokale Benachrichtigungen
- optionaler AlarmKit-Systemwecker für einmalige zukünftige Termine
- lokales Speichern bleibt erfolgreich, selbst wenn AlarmKit ablehnt
- Aktionen „Erledigt“ und „Später erinnern“ direkt aus dem Hinweis
- Ortsradius 50–5.000 m, Betreten/Verlassen und einmalig/wiederholt
- Monatsraster mit wiederkehrenden Markierungen und Tagesagenda
- Apple-Kalender opt-in lesen
- Apple-Erinnerungen opt-in erstellen und verknüpfte Einträge aktualisieren

## Wecker

- einmalig oder an frei wählbaren Wochentagen
- AlarmKit-Systemdarstellung mit Lock Screen, StandBy und Dynamic Island
- lesbarer, kontrastreicher „Schlummern“-Button und Snooze 1–30 Minuten
- optionale AlarmKit-Voranzeige bis 60 Minuten
- Systemton, drei geprüfte App-Töne oder importierte eigene Audiodatei
- Vorschau, Validierung und bestätigtes Löschen eigener Töne
- Aktivieren, deaktivieren, bearbeiten und bestätigt löschen

## Timer

- mehrere parallele Timer
- Pause, Fortsetzen, Neustart, +1 Minute, bestätigt stoppen/löschen
- eigene Presets, Favoriten und bestätigte Preset-Löschung
- Verlauf, Sieben-Tage-Diagramm und bestätigtes Leeren
- AlarmKit-Persistenz über App-Neustarts
- Live Activity, Dynamic Island, Widget, Control Center und Siri

## Notizen

- eigene Ordner mit Symbol und Farbe
- Tags, Ordner- und Tag-Filter sowie Volltextsuche
- Galerie-/Listenansicht, Anheften und Farbcodierung
- Archiv und wiederherstellbarer Papierkorb
- Markdown-Vorlagen für Überschrift, fett, kursiv, Listen, Nummern,
  Checklisten und Zitate plus formatierte Vorschau
- bis zu acht Bilder pro Auswahl, lokale Größenoptimierung und Vorschau
- beliebig viele Sprachnotizen aufnehmen, benennen, anhören und löschen
- Bestätigungen beim Entfernen von Medien, Papierkorb und endgültigem Löschen
- Medien werden bei verworfenem Entwurf oder endgültiger Löschung bereinigt

## Daten, Synchronisierung und Diagnose

- Application-Support-Speicherung statt des früher fehleranfälligen
  Documents-Unterordners
- Dateischutz `completeUntilFirstUserAuthentication` für AlarmKit-Callbacks
  nach dem ersten Entsperren
- zerstörungsfreie Migration der vorhandenen 1.0-JSON-Dateien
- atomische JSON-Speicherung, Modell-Defaults und Formatversion 2
- optionales iCloud-Documents-Mirroring bei passender eigener Signatur
- vollständiger lokaler JSON-Export und persistente Debug-Konsole
- differenzierte Permission- und Fehlermeldungen
- Unit-Tests für Legacy-Migration, Intervalle, Endbedingungen, Tags und Orte

## Design und Barrierefreiheit

- iOS-26-Liquid-Glass-Flächen und System-Navigation
- adaptive Farben, Dark Mode, Dynamic Type und VoiceOver-Bezeichnungen
- kontraststarke AlarmKit-Schaltflächen
- haptisches Feedback und systemkonforme Bestätigungsdialoge
