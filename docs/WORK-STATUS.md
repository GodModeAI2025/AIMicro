# Arbeitsstand und Wiederaufnahme

Stand: 8. Oktober 2026. **Arbeit auf ausdrücklichen Nutzerwunsch beendet, vorerst keine weitere Implementierung.**

## Letzte verbindliche Richtung

AIMicro vollständig auf **direktes SSH zur herdr-API** optimieren. Die kompakte native iPhone-Oberfläche wird weiterverwendet. herdr bildet die gemeinsame Sitzungsebene für seine Coding-Agenten. Die bisherige macOS-/Desktop-Anbindung ist ein gesicherter Ausgangsstand und kein endgültiges Ziel mehr.

Der Nutzer verlangte anschließend, Stand, Arbeit und Plan im Git zu dokumentieren und die Arbeit für jetzt zu beenden. Diese Dokumentation erfüllt diesen Abschluss; sie behauptet keinen fertigen SSH/herdr-Client.

## Fertig und nachgewiesen

- Recherche zu Codex Micro einschließlich dokumentierter Standardbelegungen, sechs Agentenplätzen, sechs Ebenen, Dial-Modi, Sprachbedienung und nicht übertragbarer Hardwareeigenschaften.
- Native iPhone-App mit bedienbarem Querformat, großen Haupttasten, sechs Profilen, Slot-Zuordnung, vier Dial-Modi und Bereichen innerhalb derselben Ansicht statt Überladung eines kleinen Displays.
- Xcode MCP für Build, Tests, Simulatorbedienung und Screenshots eingesetzt. **6/6 native Tests bestehen** im eingefrorenen Ausgangsstand.
- Reale HTTPS-Testkopplung: falscher Zertifikat-Pin abgewiesen; richtige Kopplung und Keychain-Speicherung erfolgreich; tatsächlicher Hostzustand abgefragt; Entkopplung geprüft. Dabei keine vorhandene Coding-Sitzung verändert.
- Mac-Host gebaut und Ad-hoc-Signatur geprüft. Helper-Grenztests bestehen.
- **20 Backend-/HTTPS-Tests bestehen.** Gerätewiderruf, falsche/stale Ziele, doppelte Befehle, Freigabebindung, Limits und SSE getestet.
- Unabhängige Sicherheitsreview durchgeführt und Blocker behoben. Keine verbleibenden High/Critical-Befunde im geprüften Prototypumfang; kein vollständiger Sicherheits- oder Live-Kompatibilitätsnachweis.
- Öffentlicher Ausgangsstand im Repository: Commit `768b3a9`, Branch `main`.

## Bewusste Grenzen des Ausgangsstands

- Vollständige Codex-Micro-Parität ist **nicht erreicht**. Aktionskatalogeinträge allein sind kein Funktionsnachweis; Einzelheiten in Capability-Matrix.md.
- Native Codex-Desktop-Aktionen sind ohne passende macOS-Berechtigung und eindeutige sichtbare Sitzungsevidenz gesperrt. Eine echte Desktop-Mutation wurde nicht live nachgewiesen.
- Claude-Terminal-Senden und -Freigaben sind gesperrt: gespeicherte Terminalausgabe beweist keinen aktuellen Eingabe-/Freigabedialog. Nachgewiesene Auswahl/Fokus/Stop sind vorgesehen, aber keine vollständige Live-Abnahme.
- Der native Mac-Host wurde geöffnet; der Nutzer kündigte die Freigabe von macOS-Berechtigungen an. Eine erfolgte Freigabe wird nicht als geprüft behauptet. Für das neue direkte SSH-Ziel sind diese Desktop-TCC-Berechtigungen grundsätzlich nicht Teil der Verbindung.
- Physisches iPhone, Kamera/Mikrofon, VoiceOver/Dynamic Type, Geräteinstallation und Distribution sind offen. Kein App-Store-/TestFlight-Upload.

## SSH/herdr: recherchiert, noch nicht gebaut

- Lokal verifiziert: **herdr 0.9.1**, mitgeliefertes Schema **Protokoll 22**, Schema-Version 1.
- Gemeinsame API umfasst Agentenlisten, Zustände, Read, Prompt, Focus, Send Keys, Events und Snapshot; SSH-Weiterleitung ist dokumentiert.
- Keine generischen approve/reject/fast/plan/reasoning/fork-Methoden im geprüften Schema. Diese Micro-Semantik braucht gesonderte Capability-Abbildung.
- Empfehlung nach Review: **offizielles Apple SwiftNIO SSH** statt Citadel und dessen zusätzlichem SSH-Fork/Legacy-Krypto-Umfang. Geprüfter Quellstand: `149f32ffacda5770e513cb41bd175e3d6ef77ce3`. Noch keine SwiftPM-Einbindung oder endgültige Dependency-Freigabe.
- Geplanter Transport: SSH-Exec-Kanal mit konstantem, gebündeltem Python-Gateway im Speicher; JSON über stdin/stdout. Keine automatische Remote-Installation, kein zusätzlicher nativer Mac-Host erforderlich.
- **Kein gateway.py, kein Swift-SSH-Transport, keine SSH/herdr-Integrationstests implementiert.** Die Umstellung wurde vor dem ersten Codeänderungsschritt angehalten.
- Keine produktiven herdr-Panes gelesen oder verändert. Der aktuelle Agent läuft außerhalb eines herdr-Kontexts; die eingebauten herdr-Regeln wurden respektiert.
- Der temporäre HTTPS-Testserver wurde beim Abschluss beendet. Vorhandene Nutzer-/herdr-Sitzungen wurden nicht beendet.

## Plan zur Wiederaufnahme

1. **SSH-Grundlage:** Apple SwiftNIO SSH mit genauer Revision und Package.resolved einbinden; Lizenzhinweise aufnehmen. Ed25519-Geräteidentität im Keychain; SSH-Profil mit Host, Port, Benutzer und expliziter herdr-Sitzung. Unbekannten Host-Key anzeigen und vor Authentifizierung separat verifizieren; Änderungen sperren. Keine acceptAnything-/automatische TOFU-Vertrauensregel.
2. **Gateway test-first:** begrenzte lokale herdr-Socket-API über einen SSH-Exec-Kanal. Allowlist statt beliebiger Shell-Endpunkte. Vertrag unten implementieren; keine produktiven Server starten, stoppen oder upgraden.
3. **Sitzungsbindung:** Host + ausgewählte herdr-Sitzung + Verbindungsidentität + tatsächlicher Agent/Terminal/native Session. Keine ungezielten Focus-/Current-Fallbacks. Revision, UUID-Deduplizierung und geänderte Besetzung prüfen; keine automatische Wiederholung unklar zugestellter Mutationen.
4. **iPhone-Integration:** Verbindungspanel auf SSH umstellen; Snapshot/Status/Read/Focus/Prompt/Stop über herdr. Terminal-/Dialoginhalt im vorhandenen mittleren Bereich. Voice-Diktat bleibt lokaler editierbarer Entwurf; Senden ausdrücklich.
5. **Micro-Abdeckung:** vier Slot-Modi, Ebenen/AppSense, Dial und belegbare Aktionen prüfen. Fast/Plan/Reasoning/Fork/Freigaben pro tatsächlich verfügbarer Capability behandeln. `blocked` bedeutet Aufmerksamkeit, keine automatisch zulässige Bestätigung.
6. **Verifikation:** Mock-Unix-Socket-Tests, echte isolierte SSH-Verbindung und native Xcode-MCP-Prüfung auf kleinem iPhone. Host-Key-Wechsel, falsche Identität, Agentenersatz, Disconnect, Reconnect und unbekannte Zustände testen. Danach unabhängige Review und erst an einer ausdrücklich ausgewählten ungefährlichen herdr-Sitzung live prüfen.
7. **Abschluss:** Capability-Matrix, Bedienungsanleitung und Beweise aktualisieren; committen/pushen. Reale Geräteinstallation gesondert melden.

## Vereinbarter Gateway-Entwurf

Ein persistenter SSH-Exec-Kanal, newline-delimited JSON:

```json
{"id":"UUID","op":"hello","version":1,"sessionName":"default","hostIdentity":"canonical SSH fingerprint"}
{"id":"UUID","op":"snapshot"}
{"id":"UUID","op":"read","sessionId":"opaque current session ID","lines":120}
{"id":"UUID","op":"action","request":{"commandId":"UUID","hostId":"bound host","sessionId":"bound session","expectedRevision":1,"action":"send","text":"reviewed text","parameters":{}}}
```

Hello antwortet mit `{id,ok,state,connectionId}`; die weiteren Antwortformen sind vor Implementierung im Shared-Protokoll eindeutig zu definieren. Session-IDs ändern sich bei Reconnect/Besetzungswechsel; alte Befehle dürfen nicht wiederverwendet werden. `send` nutzt ausschließlich `agent.prompt`, das blocked-Sitzungen abweist. Keine automatische Pane-/Shell-Eingabe als Ersatz. Absichtliche Tastennavigation wird getrennt von semantischer Freigabe angeboten.

**Offener API-Punkt:** Im geprüften herdr-Vertrag fehlt eine atomare Expected-Occupant-Bedingung für Prompt/Send Keys. Vorab-Bindungsprüfung und herdr-Live-Agentvalidierung reduzieren das Risiko, ersetzen aber keine atomare CAS-Prüfung. Bei Implementierung ausdrücklich lösen oder als verbleibende Grenze offenlegen.

## Ablage

README.md ist der Einstieg; Research-and-Concept.md enthält die Recherche, Herdr-Integration-Concept.md die alternative Architektur, Build-Plan.md die bisherige Umsetzung, Capability-Matrix.md die tatsächlichen Grenzen und Review-and-Validation.md die Review-Evidenz. iOS/Verification.md beschreibt den geprüften nativen Ausgangsstand. Private Schlüssel, Codes, Tokens, private Screenshots und Rohlogs gehören nicht ins öffentliche Git.
