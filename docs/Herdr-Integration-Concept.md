# Vorschlag: AIMicro als herdr-Fernbedienung

Stand 8. Oktober 2026. Nutzer fragt, ob ein gemeinsamer herdr-Adapter mit SSH/API einfacher wäre als einzelne Coding-Anbieter-Adapter. Ergebnis: **ja für herdr-verwaltete Agenten; keine automatische vollständige Micro-Semantik**. Dies ist ein geprüfter Architekturvorschlag, noch kein implementierter herdr-Adapter.

## Aktuell verifiziert

Lokal installiert: herdr 0.9.1. `herdr api schema --output …` liefert ein Schema mit 276849 Bytes. Lokale CLI-Hilfe enthält `agent list/get/read/prompt/send-keys/focus/wait/start`, `pane process-info`, `api snapshot` und `--machine`-Routing. Keine produktive Sitzung wurde gelesen oder verändert. Das exportierte Schema enthält keine Methoden für approve/reject/reasoning/fast/fork.

Die aktuelle öffentliche Dokumentation nennt JSON-Nachrichten über einen lokalen Unix-Socket, Event-Abonnements, einen Snapshot und CLI-API-Weiterleitung über nicht-interaktives SSH. Die lokale/remote Protokoll-Kompatibilität muss beim Verbindungsaufbau geprüft werden; installierte und online dokumentierte Versionen können abweichen.

## Empfohlenes Ziel

```text
iPhone: AIMicro Querformat
    │ SSH mit Host-Key-Prüfung, eigene Geräteidentität
    ▼
Ausgewählter Rechner + ausgewählte herdr-Sitzung
    │ begrenzte API-Weiterleitung, JSON-Payload außerhalb Shell-Interpolation
    ▼
herdr Socket API
    ├─ Codex CLI
    ├─ Claude Code
    └─ weitere von herdr erkannte Agenten
```

Damit entfällt für diesen Betriebsmodus die Accessibility-/Terminal-iTerm-Erkennung des aktuellen Mac-Hosts. Die bestehende iPhone-Oberfläche, Profile, lokale Sprache, Freigabedetailansicht und Befehlsbindung bleiben verwendbar. Ein kleiner herdr-Transport/Adapter übersetzt die API in das vorhandene HostState-Modell. Ein nativer macOS-Host wird bei direktem iPhone-SSH nicht zwingend benötigt. Alternativ kann der schon gebaute Host zunächst lokal/über SSH zur herdr-CLI verbinden; das verkürzt die Migration, benötigt aber weiterhin den Bridge-Rechner.

## Funktionsabbildung

| iPhone-Control | herdr-API/CLI | Grenze |
|---|---|---|
| Sechs Agentenplätze | agent.list/get, stabile Zielidentität | Schlüssel = Maschine + herdr-Sitzung + Agent/Pane + aktuelle Agentenidentität |
| Statusfarben | working/blocked/done/idle/unknown, seen/completion_seq soweit vorhanden | unknown bleibt unbekannt |
| Einzeltipp/Doppeltipp | lokale Auswahl / agent.focus | Fokus markiert gesehen; Read allein nicht |
| Text oder Diktat senden | agent.prompt | Blocked wird abgewiesen; kein raw pane.run als Fallback |
| Stop | agent.send_keys mit esc/ctrl+c | Bedeutung des Keys ist je Agent unterschiedlich |
| Verlauf lesen | agent.read / pane.read | Kein blindes Scrollen des Anbieter-UI; Terminal-Inhalt im gleichen iPhone-Bereich |
| Joystick | Agenten-/Pane-/Tab-Navigation | Micro-Plan/Fast braucht separate Capability |
| Dial | Lesen/Scrollen, Agenten-/Modusauswahl | Reasoning nicht generisch durch herdr verfügbar |
| Neuer Agent | agent.start nach ausgewähltem bereitstehendem Shell-Pane | Kein automatischer Ersatz vorhandener Sitzungen |
| Ereignisse | events.subscribe + authoritative Snapshot nach Reconnect | Bei SSH-Abbruch mutierende Befehle nicht blind wiederholen |
| Freigeben/Ablehnen | blocked + aktuelle sichtbare Anfrage + bewusste Key-Antwort | Keine universelle strukturierte approve/reject-API im geprüften Schema |
| Anbieter-Fast/Plan/Fork/Modell | Capability-spezifische Integration oder belegbare Aktionen | herdr vereinheitlicht Steuerung, nicht jede Anbieterfunktion |

## Sichere Verbindung

SSH-Host-Key wird beim ersten Pairing angezeigt und verbindlich gespeichert; Änderung sperrt die Verbindung. Keine Abschaltung der Host-Key-Prüfung. iPhone-Schlüssel im Keychain, mit Widerruf je Gerät. Für die produktive Variante möglichst eingeschränkter API-Zugang statt unbeschränkter Shell-Zugang. Remotehost und herdr-Sitzung immer explizit auswählen; kein stiller Fallback auf Local. Keine interaktive TUI-Scraping-Verbindung als Ersatz für die API.

Ein Herdr-Pane darf inzwischen eine Shell enthalten. Deshalb Senden nur über `agent.prompt` mit live Agentenauflösung; generische Pane-Eingabe nie automatisch als Prompt benutzen. Blocked ist Aufmerksamkeit, kein Nachweis einer bestimmten Freigabe. Für eine sichere Ein-Tipp-Freigabe braucht es aktuelle, reviewbare Anfrageidentität und passende herdr-/Agenten-Hooks. Ohne diese zeigt die App das Terminal-/Dialogbild und bietet bewusste Navigation statt einer erfundenen semantischen Bestätigung.

## Migration

1. Vorhandenen nativen iPhone-/Host-Stand im Repository erhalten; Desktop-Adapter als optionalen Modus behandeln.
2. Transport abstrahieren; lokale herdr-CLI oder SSH-API-Forwarder zunächst mit einer isolierten Testsitzung prüfen.
3. Agentenlisten, Zustände, Read, Focus, Prompt, Stop und Reconnect integrieren. Protocolschema-Version prüfen.
4. Direkten iPhone-SSH-Client mit Host-Key/Keychain/Background-Reconnect ergänzen; endgültige Bibliothekswahl nach Lizenz-/Build-/Sicherheitsprüfung.
5. Micro-Matrix separat abnehmen. Fast, Plan, Reasoning, Fork, Voice Chat, Anhänge und Freigaben nicht als automatisch erledigt markieren.

Wichtige Scope-Änderung: herdr verwaltet Agenten-Terminals. Bestehende Codex-Desktop-Chats werden nicht allein durch SSH zu herdr übernommen. CLI-Sitzungen müssen bereits in herdr laufen oder gezielt aufgenommen/fortgesetzt werden, soweit der jeweilige Agent das unterstützt.

## Quellen

- https://herdr.dev/docs/socket-api/
- https://herdr.dev/docs/cli-reference/
- https://herdr.dev/docs/agent-automation/
- https://herdr.dev/docs/persistence-remote/
- Lokale herdr-0.9.1-CLI-Hilfe und mitgeliefertes Schema, frisch geprüft.
