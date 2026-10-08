# Funktionsabdeckung und offene Nachweise

„Alle Funktionen erreichbar“ ist das Ziel. Der aktuelle Code darf nicht als bereits bewiesene vollständige Codex-Micro-Kompatibilität verstanden werden. Eine registrierte Aktion ist erst ausführbar, wenn der aktuelle Adapter genau diese Capability meldet.

| Micro-Familie | iPhone-Konzept / Implementierung | Status / Grenze |
|---|---|---|
| Sechs Agententasten | Sechs Plätze, echte Host-Sitzungen | Live-Sitzungserkennung braucht macOS-Berechtigung |
| Zustandsfarben und gewählter Agent | Status aus Host-Snapshot, keine erfundenen Ergebnisse | Unbekannter Zustand bleibt unbekannt; keine gesicherte vollständige Unread-Semantik |
| Einzeltipp / Doppeltipp zum Fokus | Auswahl und Host-Fokus | UI-/Adapterabgleich erforderlich |
| Recent / Pinned / Priority / Custom Bindung | Auswahl-/Zuordnungskonzept | Vollständige Modus-Parität gesondert prüfen |
| Sechs Eingabeebenen | Sechs persistente Profile, Belegung innerhalb derselben Ansicht | Lokale Profile vorhanden; AppSense-Abgleich offen |
| Fast / Plan | Aktionen im Katalog | Nur tatsächlich nachgewiesene Desktop-Capability ausführbar |
| Einmal freigeben / ablehnen | Codex-Freigabe mit gebundener Anfrage-ID und Detailprüfung | Claude-Freigaben aktuell gesperrt; Live-Prüfung offen |
| Fork / neuer Chat | Aktionen im Katalog bzw. dynamisches Menü | Desktop-Version und Adapter-Capability erforderlich |
| Senden / Stop | Codex-Senden und nachgewiesenes Stop/Fokus mit konkreter Sitzung | Claude-Senden aktuell gesperrt: Terminalausgabe beweist keinen aktiven Prompt |
| Push-to-talk / Handsfree | iPhone-Mikrofon und editierbarer lokaler Entwurf | Nur On-Device-Speech, reales Gerät noch prüfen |
| Voice Chat / Mute | Katalogeinträge | Kein vollständiger bidirektionaler Desktop-Audiokanal implementiert |
| Vier Joystick-Richtungen | Vier große, belegbare Tasten | Standardbelegung und tatsächliche Capability nötig |
| Dial Composer / Reasoning / Scroll / Custom | Touch-Regler und konfigurierbare Modi | Keine vollständige nachgewiesene Desktop-Dial-Semantik |
| Eigene Commands / Tastenzuordnung | Sichtbarer Aktionskatalog und tatsächliche AX-Menüeinträge | Keine beliebige Shell-Ausführung; nicht erkannte Commands gesperrt |
| AppSense | Automatisch zur Vordergrund-App gehörende Ebene | Noch kein vollständiges Verhalten |
| Icons / Reset / Helligkeit / Auto-Dim | Lokale Bildschirm-/Profilanpassung möglich | Hardware-RGB und Hardware-Reset nicht identisch übertragbar |
| Batterie / Bluetooth 3 Geräte / USB | iPhone-Systemeigenschaften und gekoppelte Hosts | Hardware-Verhalten nicht emulierbar; Hersteller-/OpenAI-USB-Angaben widersprechen sich |
| ChatGPT-spezifische Ebene | Erweiterbare Adapterarchitektur | Aktueller Auftrag betrifft Codex und Claude; keine vollständige ChatGPT-Steuerung |
| Anhänge / Browser / Terminal / Review / Git / Skills / Plugins / Schedules | Erweiterbarer Katalog, dynamische reale Menüaktionen | Kein Capability-Versprechen allein durch Katalogeintrag |

## Adaptergrenzen

Codex: Der Bundle-Identifier allein beweist keinen Codex-Modus. Der Helper verlangt zusätzliche sichtbare Codex-Kontextmerkmale und eindeutige ausgewählte Chats. Fehlende oder mehrdeutige UI-Evidenz sperrt Aktionen. Änderungen der Desktop-Oberfläche können die Erkennung unterbrechen.

Claude: Terminal/iTerm-Tabs werden über ihre TTY und einen bekannten nativen Claude-Prozess in der Vordergrund-Prozessgruppe gebunden. Node/npm-Installationen, Ghostty und weitere Terminalprogramme sind aktuell nicht abgedeckt. Terminalausgabe ist keine vertrauenswürdige strukturierte Freigabe-API; sicherheitskritische Aktionen müssen bei unzureichendem Nachweis gesperrt bleiben.

## Zur vollständigen Abnahme erforderlich

1. Aktuelle Desktop-Oberflächen nach Berechtigungsfreigabe prüfen und jede echte Micro-Aktion an einer ungefährlichen Testsitzung durchlaufen.
2. Nicht abgedeckte semantische Aktionen mit versionsgebundenen Adaptern oder offiziellen bestehenden Sitzungs-APIs ergänzen.
3. Alle vier Bindungsmodi, AppSense, Dial-Semantik, Sprachdialog, Anhänge sowie Status-/Unread-Verhalten nachweisen.
4. Reales kleines iPhone: Daumenbedienung, Kamera, Sprache, Netzwerkwechsel, Sperren/Entsperren und Barrierefreiheit prüfen.

Erst dann darf „alle Funktionen“ als erfüllt gemeldet werden.
