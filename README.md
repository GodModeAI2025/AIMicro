# AIMicro

**Aktuelle Zielrichtung: direktes SSH zu herdr. Arbeit auf Nutzerwunsch vorerst beendet; Umstellung geplant, noch nicht implementiert. [Stand, Arbeit und Wiederaufnahmeplan](docs/WORK-STATUS.md).**

Native iPhone-Fernbedienung im Querformat mit lokalem macOS-Host für **vorhandene Codex-Desktop-Chats und Claude-Code-Terminals**. Das Projekt entstand aus der Untersuchung des Codex Micro von Work Louder.

**Entwicklungsstand:** Beide nativen Apps bauen. HTTPS-Kopplung, Zertifikat-Pinning, widerrufbare Geräte und sitzungsgebundene Befehle sind implementiert. Vollständige Funktionsgleichheit mit Codex Micro ist noch nicht erreicht oder durch Live-Desktop-Tests nachgewiesen. Nicht verfügbare Funktionen bleiben sichtbar und gesperrt. Keine simulierte Freigabe wird als echte Desktop-Aktion ausgegeben.

## Bedienkonzept

Ein dauerhaftes Querformat mit sechs Agentenplätzen, vier Richtungstasten, drei Kontextaktionen, einem Regler und drei großen unteren Tasten. Zusätzliche Funktionen ersetzen den mittleren Bereich innerhalb derselben Ansicht: Ebenen, Belegung, Aktionen, Agenten und Verbindung. Damit werden nicht sämtliche Funktionen gleichzeitig auf ein iPhone gepresst. Kleine iPhones wurden bereits im Simulator bei 667 × 375 Punkten geprüft; Haupttasten messen mindestens 48 Punkte.

## Bauen und starten

1. Auf dem Mac `macOS/build-host.sh` ausführen, anschließend `macOS/AIMicro Host.app` öffnen und den Host starten. Benötigt Swift/Xcode-Werkzeuge und `/usr/bin/python3`.
2. macOS verlangt Bedienungshilfen für den Host/Helper und gegebenenfalls Automation für Terminal/iTerm. Die App zeigt diese getrennten Berechtigungen an. Sie erteilt sie nicht selbst.
3. `iOS/MicroRemoteDemo.xcodeproj` in Xcode öffnen. Scheme `MicroRemoteDemo` auf iPhone-Simulator oder einem eigenen, passend signierten iPhone starten. Der interne Projektname ist historisch; die Anwendung verwendet echte Host-Kommunikation.
4. Auf beiden Geräten dasselbe erreichbare Netzwerk verwenden. Im iPhone-Bereich Verbindung den QR-Code des Hosts scannen. QR-Code, Kopplungscode und Zertifikat-Fingerprint ausschließlich zwischen den eigenen Geräten übertragen.
5. Erst nach erfolgreicher Kopplung, aktueller Sitzungserkennung und vorhandener Capability werden Aktionen freigeschaltet.

Der Mac lauscht standardmäßig per HTTPS auf Port 9443. Kein Cloud-Relay und keine Übertragung von Provider-Zugangsdaten an das iPhone. Pairing-Dateien, Schlüssel und Geräteinformationen liegen außerhalb des Git-Repositories im Application-Support-Verzeichnis. Der QR-Code enthält kurzlebige Zugangsdaten und darf nicht veröffentlicht werden.

## Nachweise und Grenzen

- Backend: 20 Unit- und tatsächliche HTTPS-Integrationstests bestanden.
- iOS: sechs native Grenztests via Xcode MCP bestanden; native Builds erfolgreich.
- Mac: nativer Build, Ad-hoc-Signaturprüfung und reine Helper-Bindungstests bestanden.
- Vorhandene Desktop-Sitzungen werden über macOS Accessibility und für Terminal/iTerm zusätzlich nachgewiesene TTY-/Prozessidentität angebunden. Das ist versionsabhängig und kein zugesicherter offizieller Remote-Control-Vertrag der Desktop-Anbieter.
- Hardwaregefühl, RGB-Tasten, USB-Umschaltung und die Hardware-Batterie sind nicht auf einen Touchscreen übertragbar.
- Live-Desktop-Funktionsprüfung, reale iPhone-Mikrofon-/Kamera-Prüfung, VoiceOver/Dynamic-Type-Prüfung und signierte Geräteinstallation sind gesonderte offene Nachweise. Simulatorbeweise ersetzen sie nicht.

Alternative Architektur: [herdr über SSH/API](docs/Herdr-Integration-Concept.md). Diese Anbindung ist vorgeschlagen, noch nicht implementiert.

Details: [Funktionsabdeckung](docs/Capability-Matrix.md), [Build-Plan](docs/Build-Plan.md), [Protokoll](Shared/Protocol.md), [Mac-Host](macOS/README.md), [iPhone-Verifikation](iOS/Verification.md).

## Prüfen

```sh
python3 -m unittest discover -s Tests -v
python3 macOS/Helper/test-binding.py
macOS/build-host.sh
```

## Recherchequellen

- [OpenAI: Codex Micro](https://learn.chatgpt.com/docs/features/codex-micro)
- [Work Louder: Codex Micro](https://worklouder.cc/codex-micro)
- [Work Louder: Einrichtung](https://worklouder.cc/openai-micro-setup)
- [Codex App Server](https://developers.openai.com/codex/app-server)
- [Claude Code Remote Control](https://code.claude.com/docs/en/remote-control)

Die dokumentierten Micro-Standardaktionen und Hardwareeigenschaften sind die Referenz; dynamische Desktop-Menüs ergänzen den Katalog, ersetzen aber keinen Nachweis vollständiger Semantik.
