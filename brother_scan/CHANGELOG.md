# Changelog

Alle nennenswerten Änderungen dieses Add-ons. Format nach
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

## [1.0.2] - 2026-10-11

### Behoben

- Absturz (Segmentation fault) bei jedem Scan: `libsane-brother4` ruft
  `getprotobyname("TCP")` auf und dereferenziert das Ergebnis auch dann, wenn
  `/etc/protocols` fehlt. Das Image installiert jetzt `netbase`.
- Neustart-Meldungen zeigten UTC statt der lokalen Zeit.
- Normales Stoppen des Add-ons wurde als Absturz von `brscan-skey` gezählt.

## [1.0.1] - 2026-10-11

### Behoben

- Kein `scanimage -A` mehr: Das brother4-Backend stürzt beim Auflisten der
  Optionen ab („dumped core“). Modus- und Quellnamen sind jetzt fest hinterlegt
  (aus `libsane-brother4` 0.4.11 ausgelesen).
- Überflüssigen Symlink unter `/etc/opt/brother/scanner` entfernt.

### Verbessert

- Warnung, wenn Drucker und Home Assistant in verschiedenen Netzen liegen.
- Start prüft mit `scanimage -L`, ob SANE den Scanner kennt.
- Ausgabe von `brscan-skey -l` wird zuverlässig protokolliert.
- Abstürze von `scanimage` werden als solche gemeldet; bei `log_level: debug`
  zusätzlich SANE-Debugausgabe.

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
