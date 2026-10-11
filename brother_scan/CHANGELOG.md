# Changelog

Alle nennenswerten Änderungen dieses Add-ons. Format nach
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

## [1.0.0] - 2026-10-11

### Hinzugefügt

- Erste Version auf Basis von `jankar86/brother-brscan4`.
- Brother `brscan4` 0.4.11 und `brscan-skey` 0.3.4, beim Build per SHA-256 geprüft.
- Konfiguration von Drucker-IP, Modell, Anzeigename, Auflösung, Farbmodus, Quelle,
  Papierformat und Zielordner über die Home-Assistant-Oberfläche.
- Feste Meldung der Host-IP an den Drucker (`ip_address`), automatisch per
  `ip route get` ermittelt.
- Mehrseitiges PDF mit 300 dpi, atomare Ablage in `/share/paperless/consume`.
- Neustart von `brscan-skey` mit Backoff; nach wiederholten Abstürzen Übergabe an
  den Supervisor-Watchdog.
- Eigenes AppArmor-Profil, keine zusätzlichen Capabilities oder API-Zugriffe.
