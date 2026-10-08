# Review und Verifikation

Stand: 8. Oktober 2026. Unabhängige statische Review der Authentifizierung, Zertifikatprüfung, Sitzungsbindung, Freigabeprüfung, Menüaktionen und öffentlichen Dateien.

## Gefundene und behobene Grenzen

- Gerätewiderruf wird unmittelbar vor der Helper-Ausführung unter einem gemeinsamen Authentifizierungs-Lock erneut geprüft. Bereits wartende Anfragen können nach erfolgreichem Widerruf keine neue Aktion ausführen.
- Codex wird ausschließlich über den Bundle-Identifier und zusätzliche sichtbare Codex-Kontextmerkmale erkannt. Gleichnamige Apps reichen nicht.
- Mehrere unterschiedliche gültige Freigabekarten sperren die Aktion.
- iOS zeigt die konkreten Freigabedetails und verwendet zur Bestätigung die erfasste Anfrage-ID und Revision. Geänderte Anfragen werden nicht automatisch bestätigt.
- Dynamische Menüs verwenden eine explizite Liste sicherer Navigations-/Anzeige-/Einstellungsaktionen. Generische Run/Confirm/Allow/Send-Aktionen umgehen keine Freigabeprüfung.
- Claude-Terminalausgabe ist kein authentischer Nachweis einer aktuellen Eingabe oder Freigabe. Send/Approve/Decline werden deshalb aktuell nicht angeboten oder ausgeführt.
- Der Mac zeigt Kopplungsdaten nur für den eigenen laufenden Serverprozess mit passender PID und gültiger Laufzeit.
- Nicht-ASCII-Kopplungscodes und ungültige UTF-8-Texte werden sauber abgewiesen; abgelaufene Rate-Limit-Einträge entfernt.

Die abschließende statische Review fand keine verbleibenden High/Critical-Probleme innerhalb der geprüften Grenzen. Das ist eine Freigabe zur Prototyp-Quellcodeablage, kein Nachweis vollständiger Micro-Parität oder realer Desktop-Kompatibilität.

## Prüfevidenz

20 Backend- und echte HTTPS-Tests bestehen, darunter falscher/abgelaufener/gedrosselter Kopplungscode, Gerätewiderruf, Stale Revision, falscher Host, unbekannte Sitzung, doppelte Befehle, gebundene Freigabe, fehlende Capability, Textlimit und SSE-Snapshot. Native iOS-Tests und macOS-Build-/Helper-Evidenz stehen in den plattformspezifischen Prüfberichten.

Die Review führte eine redigierende Mustersuche über 20 Quellcodedateien aus; keine Treffer. CodeQL, Semgrep und Gitleaks waren nicht verfügbar. Es gibt keine Drittanbieter-Paketabhängigkeiten im Backend; diese Feststellung ersetzt keine Prüfung der Betriebssystem-/Toolchain-Abhängigkeiten.

## Verbleibende Grenzen

Zwischen einer finalen AX-Fokusprüfung und einer OS-Eingabezustellung kann sich der Vordergrund ändern. Live-Tests an vorhandenen Desktop-Sitzungen stehen aus. Betriebssystemberechtigungen werden nicht automatisch erteilt. Physische iPhone-Installation, Kamera, Mikrofon und Daumenbedienung sind eigenständige Nachweise. Rohdaten zu privaten Sitzungen, Kopplungscodes, Tokens und QR-Screenshots gehören nicht ins öffentliche Repository.
