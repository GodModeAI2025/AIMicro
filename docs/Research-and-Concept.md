# Micro Remote — Codex Micro auf einem iPhone-Querformat-Screen

Recherche und ursprüngliches Konzept vom 8. Oktober 2026. Der aktuelle Implementierungsstand und offene Funktionen stehen in [Capability-Matrix.md](Capability-Matrix.md); folgende Architektur enthält auch noch nicht umgesetzte Zielbilder. Nach Nutzerkorrektur auf echte iPhone-Bedienbarkeit überarbeitet. Der erste ImageGen-Entwurf ist verworfen: zu dicht und keine hinreichende Touch-Geometrie. Maßgeblich ist die neue [native Demo](../iOS/MicroRemoteDemo.xcodeproj) mit dem [kleinen iPhone-Demoscreen](../iOS/small-iphone-native.png); der Prüfbericht unter [iPhone-Prüfbericht](../iOS/Verification.md) dokumentiert die ausgeführten Prüfungen und Grenzen.

## Entscheidung

**Ja, eine native iPhone-Konsole für Codex und Claude lässt sich bauen. Eine heute nachgewiesene, vollständige Ersatzlösung für ALLE Funktionen des Originalgeräts ist damit noch nicht gegeben.**

Die entscheidende Produktentscheidung: Das iPhone stellt Bedienung, Sprache und Zustände dar. Ein Companion auf Mac oder Windows betreibt beziehungsweise verbindet die Agentensitzungen und führt Desktop-Aktionen aus. Das iPhone ist die gesamte sichtbare Bedienoberfläche; der ausführende Rechner bleibt notwendig, wenn seine lokalen Projekte bearbeitet werden sollen.

Wir planen keine reduzierte Fernbedienung mit vier Buttons. Jede recherchierte Funktion erhält eine Entsprechung, einen Integrationsweg und einen Abnahmepunkt. Unbekannte oder nicht verfügbare Funktionen bleiben im Register sichtbar. Sie dürfen nicht still verschwinden oder durch eine ähnlich klingende Aktion ersetzt werden.

„Ein Screen“ bedeutet hier genau eine dauerhafte Querformat-Konsole ohne Navigation auf weitere App-Seiten. Die Mitte wechselt ihren Inhalt für Chat, Diff, Aktionen, Konfiguration und Verbindung. Die äußeren Steuerflächen bleiben erhalten. Alle möglichen frei belegten Befehle gleichzeitig sichtbar zu machen ist auf einem iPhone nicht sinnvoll; auch das Original nutzt Ebenen und Konfiguration. Wenn wirklich keinerlei Inhaltswechsel erlaubt ist, sind umfassende Konfiguration, große Diffs und beliebig viele Sitzungen nicht gleichzeitig lesbar darstellbar.

## Was die Quellen tatsächlich belegen

Das Original verbindet sechs Agententasten mit Statusfarben und sechs Standardaktionen: Fast, Freigeben, Ablehnen, Abzweigen, Sprache, Senden. Agentenbelegung: zuletzt geändert, angeheftet, Priorität, manuell. Einzel-/Doppeltipp unterscheiden Auswahl und Desktop-Fokus. Sprache kennt Halten, Doppeltipp und optional Voice Chat. Der Joystick: Plan, vor, Seitenleiste, zurück. Regler-Modi: Composer, Reasoning, Scrollen, frei; Drehen, Drücken und Halten. Hinzu kommen Licht-/Dimmsteuerung, Layout-Reset und individuell belegbare Desktop-Befehle. Die offizielle Anleitung ist maßgeblich für diese Funktionsbasis. [OpenAI: Codex Micro](https://learn.chatgpt.com/docs/features/codex-micro).

Hardware: 13 Schalter, Touchsensor, Encoder, planarer Joystick, RGB, Bluetooth/USB-C, Mac/Windows. Der breite Sprachbutton kann zwei Schalter bedienen. Austauschbare Icon-Keycaps und Gehäusematerialien sind physische Eigenschaften. Work Louder beschreibt sechs programmierbare Ebenen und freie Belegungen. [Hersteller: Codex Micro](https://worklouder.cc/codex-micro).

Die Hersteller-Einrichtung ergänzt AppSense, drei Bluetooth-Kanäle, Schlaf-/Ein-/Aussteuerung und Reset. Beim Einstecken des USB-Kabels besteht ein Quellenwiderspruch: Hersteller beschreibt automatischen Wechsel, OpenAI verlangt manuelle Auswahl. Für einen exakten Gerätevergleich muss das an der betreffenden Firmware geprüft werden. [Hersteller: Setup](https://worklouder.cc/openai-micro-setup), [OpenAI: Einrichtung](https://learn.chatgpt.com/docs/features/codex-micro).

Die recherchierten Quellen enthalten keinen eingefrorenen, vollständigen Katalog sämtlicher auswählbarer Desktop-Kommandos aller App-Versionen. „ALLE“ braucht daher zusätzlich einen exportierten oder manuell erfassten Aktionskatalog der konkreten Zielversion. Das Konzept verspricht keine Vollständigkeit für unbekannte zukünftige Befehle.

## Der eine Screen — bewusst ein Controller

**Arbeitstitel: Micro Remote.** Eigene Gestaltung, kein offizielles OpenAI- oder Anthropic-Produkt. Die Demo verwendet Beispieldaten; weder Verbindung noch echte Agentensteuerung sind dadurch implementiert.

Der erste Entwurf hat zu viel gleichzeitig gezeigt: Chat, Freigabe, Prompt, 13 Tasten, Joystick, Regler, Hostwahl und sechs Profile. Das ist auf echter iPhone-Größe keine gute Bedienoberfläche. Der neue Entwurf behandelt das Telefon als Controller. Eine vollständige Chat-App muss nicht zusätzlich in denselben Screen passen.

**Oben eine Reihe mit sechs Agententasten.** Ein kurzer Name und ein eindeutiges Statussymbol reichen. Nur der gewählte Agent bekommt in der Mitte seinen vollständigen Namen, Provider und Zustand. Kein 2 × 3 Kartenblock mit mehrfach wiederholten Beschriftungen. Farbe wird durch Form/Text ergänzt. Details und längere Namen erscheinen auf Berührung in der Mitte.

**Links ein großes Richtungskreuz, rechts ein großer Regler.** Beide bleiben in der normalen Steueransicht an derselben Stelle. Das Kreuz verwendet diskrete Touch-Flächen mit mindestens 48 Punkten. Der Regler unterstützt Rastschritte, Drücken und Halten; eine zugängliche Schrittsteuerung ersetzt die Kreisgeste, wenn nötig. Ein mechanischer Encoder bleibt blind besser bedienbar als Glas.

**In der Mitte nur der aktuelle Entscheidungskontext.** Bei einer Freigabe beispielsweise `npm test` plus zwei große Aktionen Freigeben/Ablehnen und eine klar erreichbare Detailansicht. Bei einem laufenden Agenten stehen dort Unterbrechen und nächste Nachricht. Bei Sprache steht dort das Transcript. Es werden keine volle Historie und keine zweite Composer-Zeile parallel eingebaut.

**Unten drei große primäre Steuerflächen.** Belegung/Mehr, Halten zum Sprechen und Senden. Die sechs originalen Standardaktionen sind auf dieser Konsole erreichbar, aber nicht alle ständig zusätzlich sichtbar. Abzweigen und Fast liegen im Standard-Aktionssatz unter Belegung/Mehr oder werden auf eine frei belegte Fläche gesetzt. Freigaben haben während einer offenen Anfrage Vorrang im Zentrum.

Der Belegungsbutton schaltet auf derselben Root-View einen großen lokalen Aktionssatz beziehungsweise die sechs Ebenen frei. Rechnerwahl, sämtliche freie Mappings, Icons, Licht und Reset verwenden dieselbe lokale Fläche. Kein Seitenstapel, keine Mini-Toolbar mit 20 Symbolen. Die Funktion wird sichtbar beschriftet; Langdruck ist eine Abkürzung und niemals der einzige Zugang zu einer wesentlichen Einstellung.

**Beispiel für vollständige Reichweite:** Ebene 1 Kernaktionen, Ebene 2 Git/Review, Ebene 3 Dateien/Terminal/Browser, Ebene 4 Skills, Ebene 5 Sprach-/Regleroptionen, Ebene 6 frei. Diese Voreinstellung ist nur unser Entwurf; alle sechs Ebenen bleiben editierbar. Eine Ebene kann sechs gut lesbare Aktionen als 3 × 2 große Flächen anstelle des Kontextbereichs und der beiden Steuerinstrumente anzeigen. Die Agentenreihe bleibt erhalten. Damit ist die Zahl der erreichbaren Funktionen nicht von der Zahl gleichzeitig sichtbarer Buttons abhängig.

Der Sprachweg bleibt primär für längere Prompts. Für Korrekturen ersetzt ein Texteingabemodus die Instrumente vorübergehend durch die Systemtastatur und ein großes Textfeld. Große Diffs, Befehlstexte und Historien verwenden eine Detailfläche innerhalb derselben Konsole. Wer jede Funktion gleichzeitig und ohne Flächenwechsel sehen möchte, benötigt ein größeres Display; diese Einschränkung lässt sich nicht mit kleineren Buttons sinnvoll lösen.

### Geometrie und native Prüfung

Das Layout wird zuerst für ein kleines iPhone geprüft, nicht für ein großes Marketingbild. Zielgrößen sind 667 × 375 beziehungsweise ein tatsächlich vorhandenes kleines Simulatorgerät; zusätzlich ein größeres iPhone. Alle Maße sind **Punkte, keine Bildpixel**. Safe Areas werden aus der aktuellen View-Geometrie berechnet.

Planungsbeispiel für 667 × 375 ohne seitliche Safe-Area-Abzüge: 16 Punkte Außenrand ergeben 635 Punkte Breite. Sechs Agententasten mit fünf 6-Punkte-Abständen sind jeweils rund 101 Punkte breit und mindestens 48 Punkte hoch. Die Instrumente benötigen jeweils 144 Punkte; mit zwei 12-Punkte-Abständen bleiben ungefähr 323 Punkte in der Mitte. Kopf/Agentenreihe etwa 56, Fuß etwa 60, vertikale Abstände etwa 24: ungefähr 235 Punkte für den Hauptbereich. Zusätzliche Safe-Area-Abzüge verkleinern diese Werte und müssen nativ gemessen werden.

Hauptaktionen mindestens 48 × 48 Punkte, wichtige Sprach-/Sendeaktionen nach Möglichkeit 56–64 Punkte hoch. Im Richtungskreuz darf nicht nur dessen Gesamtfläche 144 Punkte groß sein: **jede einzelne Richtung muss einen mindestens 48 × 48 Punkte großen Hit-Bereich besitzen.** Der zentrale Reglerbereich ist ein eigener Hit-Bereich; Richtungswechsel und Langdruck dürfen sich nicht versehentlich überlagern.

Ein Screenshot wird in seiner logischen Größe beurteilt. Bei 2×/3×-Simulatorbildern wird die Pixelzahl durch den Displayfaktor geteilt. Messung von Bounds und Hit-Zielen, beide Querformatrichtungen, echte Safe Areas, Schriftvergrößerung und Interaktion gehören zum Prüfbericht. Vorliegende Preview-/Simulator-Nachweise werden dort getrennt von noch offenen Realgerät-Tests ausgewiesen.

Xcode MCP und die vorhandenen Apple-Skills für SwiftUI, anpassbare Layouts und Device Interaction dienen der nativen Demo und Prüfung. Das ersetzt weder Backend-Integration noch den Test mit echten Daumen am physischen Telefon.

## Vollständigkeitsregister: keine Funktion fällt aus dem Plan

Die erste Spalte benennt die recherchierte Funktionsfamilie. Die weiteren Spalten sind unser Entwurf und unsere Bewertung, keine behaupteten vorhandenen APIs.

Legende: **I** = iPhone selbst; **C** = Companion; **P** = Provider-/Versionsnachweis notwendig; **H** = nur digitale Entsprechung, keine physische Reproduktion.

| ID | Funktionsfamilie | Entsprechung auf dem einen Screen | Abhängigkeit |
|---|---|---|---|
| A01 | Sechs Agentenslots | Sechs große Kurz-Tasten in einer Reihe; gemischte Provider möglich | I+C |
| A02 | Zustandsfarben | Text, Symbol, Farbe; ungelesen getrennt von beendet | I+C |
| A03 | Auswahlpuls | Kontur und optionale Animation | I |
| A04 | Einzel-/Doppeltipp | Auswählen / Rechnerfenster fokussieren; 350-ms-Kompatibilität optional | I+C+P |
| A05 | Vier Bindungsstrategien | Auswahl im Fuß; manuelle Zuordnung im Zentrum | I+C |
| A06 | Unbelegter Slot | Neuer Chat wird nach Anlage diesem Slot zugeordnet | I+C |
| A07 | Alternative Slotbelegung | Chat, Aktion, Shortcut oder Skill als Typ speichern | I+C+P |
| K01 | Fast | Große Aktion im Belegungssatz; Provider-Zustand bestätigen | C+P |
| K02 | Freigeben | Exakte offene Anfrage beantworten | C+P |
| K03 | Ablehnen | Exakte offene Anfrage ablehnen | C+P |
| K04 | Abzweigen | Im Belegungssatz; neue Sitzung aus vorhandener Historie | C+P |
| K05 | Sprechen | Halten zum Aufnehmen; Loslassen beendet | I |
| K06 | Senden | Entwurf an den eindeutig ausgewählten Agenten | I+C |
| K07 | Geteilte Sprachtaste | Breites Feld oder zwei getrennte belegbare Ziele | I |
| V01 | Doppeltipp-Aufnahme | Start/Stopp mit sichtbarem Aufnahmestatus | I |
| V02 | Sprachverarbeitung | Aufnahme → Transkription → prüfbarer Entwurf | I+C je nach Engine |
| V03 | Voice Chat | Eigenes bidirektionales Sprachmodul oder geprüfte Desktop-Anbindung | C+P |
| V04 | Mikrofonwahl/-stumm | iPhone und gegebenenfalls Host als getrennte Quellen | I+C+P |
| J01 | Vier Richtungen | Touch-Joystick mit Totzone, Schwellwert und einer Auslösung pro Bewegung | I |
| J02 | Standardnavigation | Plan, Verlauf, Liste in der eigenen Konsole; Desktop separat | I+C+P |
| J03 | Freie Richtungsbelegung | Registry-Aktion oder Skill je Richtung | I+C+P |
| D01 | Composer-Navigation | Fokusrahmen, Drehen wählt, Druck bestätigt | I |
| D02 | Reasoning | Nur tatsächlich verfügbare Werte des aktuellen Modells | C+P |
| D03 | Gesprächs-Scrollen | Drehen scrollt, Druck springt ans Ende | I |
| D04 | Freier Regler | Vier Belegungen: links/rechts/drücken/halten | I+C+P |
| D05 | Abbrechen/Settings | Sichtbares Abbrechen; Kompatibilitätsbelegung des Nachbarslots; Halten öffnet Mitte | I |
| L01 | Sechs Ebenen | Sechs Profile; große lokale Auswahl über Belegungsbutton | I+C |
| L02 | Touchsensor/Ebenenwahl | Belegungsbutton und optional Wischgeste | I |
| L03 | AppSense | Aktive Desktop-App meldet Profilwechsel; manuelle Sperre möglich | C+P |
| M01 | Individuelles Layout | Langdruck → Editor in der Mitte; JSON-Export/Import geplant | I+C |
| M02 | Icon-/Keycap-Wechsel | Digitale Icon-Auswahl; doppelte Zuweisung tauscht Plätze | I+H |
| M03 | Layout-/Profil-Reset | Getrennte Rücksetzbereiche; Vorschau vor Löschen | I |
| X01 | Desktop-Aktionskatalog | Suchbares Register im Zentrum; keine fest eingebaute Auswahlliste | C+P |
| X02 | Shortcuts/Makros | Host, Ziel-App, Kombination und Wirkungsbereich explizit binden | C+P |
| X03 | Git/PR/Review | Diff prüfen, anschließend konkrete Repo-Aktion bestätigen | C+P |
| X04 | Dateien/Fotos | Auswahl im Zentrum; Upload dem richtigen Projekt zuordnen | I+C+P |
| X05 | Browser/Terminal | Host-Fenster öffnen oder eingebettete Ansicht; Fähigkeiten getrennt | C+P |
| X06 | Plugins/Schedules | Provider-spezifische Aktionen; fehlende Unterstützung sichtbar | C+P |
| N01 | Drei Kanäle | Drei unabhängig gepaarte Host-Slots | I+C+H |
| N02 | Bluetooth/USB | LAN als Hauptweg; Bluetooth-/USB-Transport eigenständige Machbarkeits-Spikes | C+P+H |
| N03 | Pairing/Re-Pairing | QR, Fingerprint, Widerruf und neue Bindung im Zentrum | I+C |
| R01 | RGB-Rahmen/Helligkeit | Zustandsrand und App-Dimmung, Farbe abschaltbar | I+H |
| R02 | Auto-Dim/Reaktivierung | In-App-Inaktivitätsregel und Reaktion auf Statuswechsel im Vordergrund | I+H |
| R03 | Akkuanzeige | Eigener iPhone-Akku; optional Host-Akku separat | I+C+H |
| R04 | Ein/Aus/Schlaf/Reset | Verbinden, Trennen, Standby und Companion-Neustart; kein Hardware-Bootloader | I+C+H |
| H01 | Mechanik/Material/Keycaps | Haptik, Touch und digitale Icons ersetzen den Bedienzweck | H |
| H02 | Rutschfeste Basis | iPhone-Ständer außerhalb der Software | H |
| H03 | Mac-/Windows-Betrieb | Getrennt getestete Companion-Pakete | C |

**Vollständig geplant bedeutet hier nicht vollständig bewiesen.** Sämtliche P-Zeilen müssen vor einer Paritätsaussage an der Zielversion überprüft werden. Die H-Zeilen verhindern bereits eine wörtliche Gleichheit aller Eigenschaften. Akku, Laden, mechanische Schalter, Materialien und physischer Reset sind Eigenschaften unterschiedlicher Geräte.

## Architektur und Integrationsgrenzen

```text
iPhone: eine native Querformat-Konsole
   │ authentifizierte Verbindung + Events
   ▼
Companion auf Mac / Windows
   ├─ Sitzungsregister und Capability-Register
   ├─ Desktop-Aktionen, App-Fokus, Shortcuts
   ├─ Codex-Adapter → dokumentierter App Server
   └─ Claude-Adapter → SDK oder betreute CLI-Sitzung
```

### Codex: zwei verschiedene Anforderungen

Für neue, von unserem Companion verwaltete Sitzungen ist der dokumentierte App Server der bevorzugte Weg. Er stellt unter anderem Threads, Turns, Streaming und Approval-Anfragen bereit. Konkrete Einstiegspunkte sind `thread/start`, `thread/resume`, `thread/fork`, `turn/start`, `turn/steer`, `turn/interrupt`, `model/list`, `skills/list` und `review/start`. Das Protokoll initialisiert jede Verbindung ausdrücklich. [OpenAI: App Server](https://developers.openai.com/codex/app-server).

**Das belegt keine beliebige Fernsteuerung der bereits laufenden offiziellen Desktop-App.** Ob dieselben Chats übernommen werden können, welche Historienformate unterstützt sind und ob Änderungen gleichzeitig aus Desktop und iPhone zulässig sind, muss separat geprüft werden. Ein zweiter App-Server-Prozess wird nicht ungeprüft gegen dieselbe aktive Sitzung betrieben.

Die Desktop-Anbindung benötigt zusätzlich Auswahl, Fensterfokus, UI-Navigation und Aktionen, die im Agentenprotokoll nicht repräsentiert sind. Reihenfolge: unterstützte externe Schnittstelle prüfen; dann explizite Desktop-Shortcuts; gegebenenfalls Accessibility-Adapter. Accessibility braucht Host-Berechtigungen, versionsbezogene Tests und echtes Readback. Ein erfolgreicher Tastendruck allein beweist nicht, dass der richtige Chat gewechselt oder eine Freigabe erteilt wurde.

Fast, Voice Chat, laufende UI-Zustände und der gesamte Micro-Aktionskatalog sind offene Nachweise. Undokumentierte interne Desktop-Sockets wären eine fragile Zusatzintegration; sie werden nicht zur Voraussetzung einer garantierten Parität gemacht.

### Claude: ebenfalls zwei Betriebsarten

Das Agent SDK ist der nachvollziehbare Weg für selbst verwaltete Claude-Agenten. Es enthält Werkzeuge, Sessions, Hooks, Skills und weitere Agentenfunktionen. Das macht eine eigene Oberfläche möglich, übernimmt aber nicht automatisch eine schon laufende Terminal-Sitzung. Für ein verbreitetes SDK-Produkt verweist Anthropic auf API-Key-Authentifizierung und nennt Einschränkungen für fremde Angebote mit claude.ai-Login. [Anthropic: Agent SDK](https://code.claude.com/docs/en/agent-sdk/overview).

Für tatsächliche vorhandene Claude-Code-CLI-Sitzungen wird eine betreute Host-Integration separat prototypisiert: Session-Lifecycle, Eingabekanal, strukturierte Events, Approval-Routing und Wiederaufnahme. PTY-Steuerung ist ein möglicher Fallback, aber ANSI-Ausgaben und Prompt-Erkennung sind kein stabiler Ersatz für strukturierte Zustände. Bestehende unmanaged CLI-Prozesse werden nicht als sicher übernehmbar vorausgesetzt.

Anthropics Remote Control zeigt, dass lokale Claude-Code-Arbeit vom Telefon steuerbar ist, bleibt jedoch eine Oberfläche über claude.ai beziehungsweise die Claude-App. Die recherchierte Anleitung liefert keine allgemeine öffentliche API für unsere eigene Konsole; einige Befehle bleiben lokal. Deshalb wird Remote Control nicht als bereits verfügbare Backend-Schnittstelle eingeplant. [Anthropic: Remote Control](https://code.claude.com/docs/en/remote-control).

SDK-Freigaben werden über `canUseTool` beziehungsweise geeignete Hooks mit dem iPhone verbunden. Der Adapter muss jeweils die wirkliche Rechteentscheidung abbilden; manche Modi oder Regeln entscheiden bereits vorher. [Anthropic: User Input](https://code.claude.com/docs/en/agent-sdk/user-input).

Reasoning ist ein providerspezifischer Parameter. Gleichnamige Werte bedeuten keine gleiche Rechenintensität. Modell, Version und Organisationsgrenzen bestimmen die verfügbare Skala; der Regler zeigt die tatsächlichen Werte und wann eine Änderung wirksam wird. [Anthropic: Model Configuration](https://code.claude.com/docs/en/model-config).

### Native iPhone-App

Geplante Technik: SwiftUI für die Konsole, systemeigene Haptik, Audioaufnahme und Speech für Transkription. Spracherkennung ohne eingeblendete Tastatur ist grundsätzlich vorgesehen; Sprachverfügbarkeit und lokale Ausführung werden auf dem konkreten Gerät geprüft. Ein eigener Sprachdialog wäre eine zusätzliche Engine und muss so gekennzeichnet werden. [Apple: Speech](https://developer.apple.com/documentation/Speech).

LAN-Verbindung über TLS/WebSocket, Host-Erkennung optional über Bonjour. QR-Pairing enthält Host-Adresse, kurzlebiges Pairing-Geheimnis und Zertifikat-Fingerprint. Nach Bindung erhält jedes Telefon eine widerrufbare Geräteidentität; Zugangsdaten bleiben im Keychain beziehungsweise am Host. LAN-Berechtigungen werden im Vordergrund erklärt und auf einem echten iPhone getestet. [Apple: TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy).

Fernzugriff später über VPN oder einen gesondert authentifizierten Relay. Kein öffentlich offener Companion-Port. Bluetooth-HID-Emulation als vollwertiges Micro und direkte USB-C-Gleichheit sind kein belegter iOS-Transportweg dieses Konzepts. Ein eigener BLE-GATT-Dienst mit Host-Companion oder ein kabelgebundener IP-Weg wären separate Untersuchungen. WLAN zuerst liefert den Bedienzweck, aber erfüllt keine wörtliche Transport-Parität.

Im Vordergrund kann die Konsole als Desk-Controller wach bleiben. Nach Sperren oder Hintergrundwechsel darf sie keine dauerhafte Live-Verbindung voraussetzen. Der Host arbeitet weiter; beim Rückkehren werden Snapshot und offene Anfragen neu geladen. Push-Benachrichtigungen sind eine spätere Ergänzung und ersetzen keine permanent sichtbaren RGB-Agententasten.

## Verträge, die eine verlässliche Steuerung ermöglichen

**Sitzungsidentität:** Jede Aktion trägt `hostId`, `providerId`, `sessionId` und bei laufender Arbeit `turnId`. Der Name „API“ ist nur eine Anzeige. Slotnummern sind keine Identitäten.

**Fähigkeiten:** Jeder Adapter liefert ein versionsbezogenes Manifest. Aktionen tragen ID, Parameter-Schema, Berechtigungsbedarf, aktuelle Verfügbarkeit, Bestätigungserfordernis und Unterstützung für Readback. Ein unbekannter Befehl wird nicht als generischer Shell-Text ausgeführt. Das Register besitzt auch nicht verfügbare Einträge mit verständlichem Grund.

**Befehl:** Ein Command-Envelope enthält `commandId`, Zielidentität, Aktions-ID, Parameter, erwartete Zustandsrevision und Ablaufzeit. Empfang, Ausführung und bestätigter Endzustand sind verschiedene Ereignisse. Bei Verbindungsverlust bleibt der Zustand „unbestätigt“, bis der Host Auskunft gibt.

**Freigaben:** Die Antwort bindet sich an `requestId`, Sitzung, Turn und Umfang. Vor dem Senden prüft der Host, dass die Anfrage noch offen ist. Zwei Clients dürfen dieselbe Anfrage nur einmal beantworten. Nach Host- oder Sitzungswechsel sind alte Freigabeflächen sofort deaktiviert. Unbestätigte Freigaben werden nach Reconnect nicht automatisch erneut gesendet.

**Zustände:** `unassigned`, `idle`, `running`, `needsInput`, `error`; `completed` und `unread` werden gesondert geführt. Disconnect ist ein Transportzustand und darf nie zu „fertig“ werden. Ein grüner Slot verliert Unread nur durch nachvollziehbares Lesen beziehungsweise Bestätigen.

**Events:** Sequenznummer je Host, Snapshot auf Reconnect, danach geordnete Updates. Lücken lösen erneute Synchronisierung aus. Das iPhone schätzt keinen Agentenzustand aus der zuletzt gesehenen Animation.

**Profile:** Sechs Ebenen mit frei belegbaren Slots, Kommandos, Richtungen und Encoder-Ereignissen. Profile enthalten Zielhost-/App-Regeln, Icons und Spracheinstellungen. AppSense wechselt nur bei bestätigtem Host-Fokus; ein manueller Lock hat Vorrang. Provider-Wechsel übernimmt die Belegung, prüft aber jede Fähigkeit neu.

**Kompatibilitätsparameter:** Originalnahe Zeitfenster und Dimmintervalle werden als versionierte Parameter erfasst, nicht nach Gefühl eingestellt. Dazu gehören Doppeltipp-Zeit, Touch-Haltedauer, Timeout der Verbindungsauswahl, Default-Dimmzeit und erlaubte Dimmwerte. Der native Bedienmodus darf für größere Touch-Flächen andere Gesten anbieten, muss solche Abweichungen aber ausdrücklich in der Paritätsmatrix ausweisen. App-Dimmung, Systemhelligkeit und automatische Displaysperre sind getrennte Zustände.

**Mehrfachauslösung:** Joystick-Totzone, explizite Rückkehr in die Mitte, Druck-/Langdrucktrennung und Encoder-Rastung. Halten für Aufnahme und Doppeltipp für Daueraufnahme müssen dieselbe eindeutige Zustandsmaschine verwenden. Ein Screenshot ersetzt diese Tests nicht.

**Änderungen versus Berechtigungen:** „Freigeben“ beantwortet eine Werkzeuganfrage. „Diff übernehmen“ beziehungsweise „Git commit“ sind eigene Repo-Aktionen. Eine Ablehnung darf keine bereits geschriebenen Änderungen rückgängig machen, wenn das nicht der ausdrückliche Aktionstyp ist.

## Umsetzungsplan mit Entscheidungspunkten

Die Reihenfolge priorisiert Integrationsnachweise. Eine schöne Oberfläche allein löst die Vollständigkeitsforderung nicht. Aufwand ist eine Planungsschätzung für eine erfahrene Entwicklerperson, keine Lieferzusage.

| Phase | Ergebnis | Abnahme | Grobe Dauer |
|---|---|---|---|
| 0: Inventar | Zielversionen, Original-Mappings, kompletter auswählbarer Aktionskatalog, Quellenwidersprüche | Jede Aktion besitzt Register-ID und Herkunft; kein versteckter Restposten | 2–4 Tage |
| 1: Integrations-Spikes | Codex-Session, Claude-Session, vorhandene Desktop-/CLI-Sitzung, Fast und Voice untersucht | Echte Status-/Approval-/Focus-Rückmeldung; offene Grenzen dokumentiert | 4–8 Tage |
| 2: Native Konsole | Eine Root-View, sechs Slots/Kommandos/Ebenen, Joystick, Regler, Editor | Kleine und große iPhones, Safe Area, 44-Punkte-Ziele, VoiceOver | 4–6 Tage |
| 3: Companion | Pairing, Adapter, Events, IDs, Reconnect, Profile | Keine Aktion landet beim falschen Host; Zustandsverlust wird erkannt | 5–8 Tage |
| 4: Funktionsparität | Sprachmodi, Makros, AppSense, Aktionsregister, Dateien, Diff und Git | Alle unterstützbaren Registereinträge mit Wirkung und Readback | 5–10 Tage |
| 5: Auslieferung | Mac-/Windows-Pakete, reales iPhone, Betriebsanleitung, Versionsmatrix | Neustart/Upgrade/Widerruf/Offline und vollständiger Abnahmelauf | 4–7 Tage |

Orientierung: etwa fünf bis neun Arbeitswochen für eine belastbare erste Version beider Provider, sofern die Spikes keine grundlegenden Schnittstellenlücken zeigen. Eine eigene SDK-basierte Konsole wäre einfacher als die vollständige Übernahme bestehender Desktop-/CLI-Sitzungen. Nicht verfügbare externe Schnittstellen können zusätzliche Zeit erfordern oder eine exakte Parität verhindern. API- beziehungsweise Abonnementkosten werden getrennt behandelt; ein Companion garantiert keine Übertragbarkeit bestehender Provider-Tarife.

**Entscheidung nach Phase 1:**

1. Wenn bestehende Sitzungen samt Zustand und Aktionen verlässlich steuerbar sind: vollständige Fernbedienung weiterbauen.
2. Wenn nur selbst verwaltete Sitzungen verlässlich gehen: das als eigenen Produktmodus benennen; ursprüngliche Desktop-Parität bleibt offen.
3. Wenn einzelne Aktionen nur UI-Automation erlauben: in der Versionsmatrix als solche markieren und bei fehlendem Readback deaktivieren.

Keines dieser Ergebnisse berechtigt, „ALLE Funktionen vollständig umgesetzt“ zu behaupten, solange noch P-Zeilen offen sind.

## Akzeptanz: was „ALLE“ am Ende konkret heißt

Für jede Register-ID und jedes Kommando des erfassten Zielversions-Katalogs gibt es einen Testfall mit Anbieter, Host, Auslöser, erwarteter Wirkung und beobachteter Bestätigung. Der Bericht zeigt unterstützt, teilweise, physisch nicht übertragbar oder offen. Ein Prozentsatz allein genügt nicht.

- Sechs Slots zeigen gleichzeitig richtige Zustände; Auswahl, Unread und unbelegt werden unabhängig geprüft.
- Jede Bindungsstrategie, Ebene, freie Belegung und Reset-Variante funktioniert nach App-/Host-Neustart.
- Einzel-/Doppeltipp und Fensterfokus werden am realen Desktop verifiziert.
- Die sechs Standardaktionen laufen providerbezogen; nicht verfügbare Funktionen bleiben sichtbar begründet.
- Alle vier Regler-Modi und vier Richtungen funktionieren; keine zweite Auslösung beim Rückweg.
- Diktat unterstützt Halten, Doppeltipp, Stoppen, Korrigieren und ausdrückliches Senden. Provider-Sprachdialog wird separat geprüft.
- Host-Wechsel während einer Freigabe kann niemals die Antwort an den vorherigen oder falschen Agenten schicken.
- Abbruch, abgelaufene Anfrage, zwei verbundene Telefone und verlorene Antwort sind kontrollierte Zustände.
- WLAN-Unterbrechung, Host-Schlaf, iPhone-Sperre und Hintergrundwechsel verlieren keine offene Anfrage und erzeugen keine doppelte Repo-Aktion.
- Große Diffs und lange Fragen bleiben lesbar im Zentrum; äußere Steuerflächen bleiben erreichbar.
- iPhone-Safe-Area, Schriftvergrößerung, VoiceOver und Farbsehschwächen werden praktisch geprüft.
- Bluetooth und USB werden nur dann als unterstützt ausgewiesen, wenn der konkrete gewählte Transport auf iPhone und beiden Hostsystemen nachgewiesen ist.
- Weder Original-Hardware-Haptik noch physische Beleuchtung werden als durch Software identisch ersetzt beworben.

## Empfehlung

Den einen Screen bauen, zunächst mit Mac-Companion und beiden strukturierten Agentenadaptern. Vor größerer UI-Implementierung zwei schwierige Beweise erbringen: vorhandene Sitzungen zuverlässig übernehmen und den vollständigen Micro-Aktionskatalog tatsächlich ausführen. Danach Windows und alternative Transporte ergänzen.

Das Ergebnis kann den Bedienzweck des Codex Micro auf einem iPhone erfüllen und um gemischte Anbieter erweitern. Die Aussage „ALLE Eigenschaften identisch“ ist wegen der Hardware falsch; „ALLE dokumentierten Bedienfunktionen erreichbar“ ist ein sinnvoller, testbarer Anspruch, dessen Desktop- und Provider-Grenzen das Register ausdrücklich sichtbar macht.
