# GitHub-Kurzanleitung

1. Das vollständige Source-ZIP entpacken.
2. Den **Inhalt** von `RJ-ZeitZentrale` vollständig in die Repository-Wurzel
   laden; keine alte Teilfassung darüberkopieren.
3. GitHub → `Actions` → `Build RJ ZeitZentrale IPA` öffnen.
4. `Run workflow` drücken und den Branch `main` wählen.
5. Nach dem grünen Lauf unter `Artifacts`
   `RJ-ZeitZentrale-unsigned-IPA` herunterladen.
6. Die enthaltene IPA mit dem eigenen Profil signieren; dabei App und
   Widget-Extension gemeinsam signieren.

Falls der Lauf rot wird, das Artifact `RJ-ZeitZentrale-build-log` herunterladen.
Für eine Reparatur dieses Log zusammen mit dem vollständigen Source-ZIP
bereitstellen. Das korrigierte Paket ist wieder als vollständiger Ersatz
gedacht, nicht als Patch oder Merge.

Die optionale iCloud-Aktivierung ist in `README.md` beschrieben. Für normales
Sideloading ist sie nicht erforderlich und in der unsigned Standard-IPA aus.
