# GitHub-Kurzanleitung

1. ZIP entpacken.
2. Den Inhalt des Ordners `RJ-ZeitZentrale` vollständig in die Repository-Wurzel
   laden. Nicht nur den äußeren Ordner hochladen.
3. GitHub → `Actions` → `Build RJ ZeitZentrale IPA` öffnen.
4. `Run workflow` drücken.
5. Unter `Artifacts` die Datei `RJ-ZeitZentrale-unsigned-IPA` laden.

Falls die Aktion rot wird, das Artifact `RJ-ZeitZentrale-build-log`
herunterladen. Für eine Reparatur immer dieses Log zusammen mit dem vollständigen
Source-ZIP bereitstellen. Das korrigierte Ergebnis soll wieder als vollständiges
ZIP ersetzt werden; kein Patch- oder Merge-Workflow ist erforderlich.
