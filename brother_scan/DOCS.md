# Brother Scan to Paperless

Dieses Add-on macht Home Assistant zum „PC“, den dein Brother-Multifunktionsgerät
über die **Scan-Taste** ansteuert. Ein Scan über **Scan → zu PC → Datei** landet als
PDF (Standard: 300 dpi, Graustufen) direkt in `/share/paperless/consume`, wo
Paperless-ngx ihn automatisch übernimmt.

Ausgelegt für den **Brother MFC-L2710DW** auf Home Assistant OS (x86-64).
Andere Brother-Geräte, die von `brscan4` und `brscan-skey` unterstützt werden,
funktionieren in der Regel ebenfalls (Modell in der Konfiguration anpassen).

## Funktionsweise

```
 Drucker-Taste ──UDP 54925──▶ brscan-skey ──▶ brother-scan ──TCP 54921──▶ Drucker
                                              │  (scanimage, brscan4)
                                              ▼
                              TIFF-Seiten ─▶ PDF ─▶ /share/paperless/consume
```

1. Beim Start registriert das Add-on den Scanner bei `brscan4` (`brsaneconfig4`).
2. `brscan-skey` meldet sich per SNMP beim Drucker an und teilt ihm mit, an welche
   IP/Port (UDP 54925) Tasten-Ereignisse gesendet werden sollen. Ab dann erscheint
   der Anzeigename (Standard `HomeAssistant`) im Druckermenü.
3. Drückst du am Drucker auf Start, ruft `brscan-skey` das Skript `brother-scan` auf.
   Es scannt alle Seiten aus dem Vorlageneinzug – oder, wenn dieser leer ist, vom
   Vorlagenglas –, erzeugt ein PDF und legt es atomar im Zielordner ab
   (erst `.name.pdf.part`, dann Umbenennen), damit Paperless nie halbe Dateien sieht.

## Voraussetzungen

- Home Assistant OS auf amd64/x86-64.
- Der Drucker hat eine **feste IP-Adresse** (DHCP-Reservierung im Router).
- Drucker und Home Assistant befinden sich im **selben Netz/VLAN** oder UDP 54925
  vom Drucker zu Home Assistant ist erlaubt (siehe „Netzwerk“).
- Paperless-ngx überwacht `/share/paperless/consume` (z. B. das Paperless-ngx-Add-on
  oder ein Container, der `/share` einbindet). Der Ordner wird bei Bedarf angelegt.

## Konfiguration

| Option | Standard | Beschreibung |
|---|---|---|
| `printer_ip` | – (Pflicht) | IPv4-Adresse des Druckers |
| `printer_model` | `MFC-L2710DW` | Modellname exakt wie bei Brother |
| `scanner_name` | `Brother` | Interner Name der brscan4-Registrierung |
| `display_name` | `HomeAssistant` | Name des Ziel-PCs im Druckerdisplay (max. 15 Zeichen) |
| `host_ip` | leer (automatisch) | IP, die dem Drucker als Ziel gemeldet wird |
| `resolution` | `300` | 150, 200, 300 oder 600 dpi |
| `color_mode` | `gray` | `gray`, `color` (Farbe im schnellen Modus „24bit Color[Fast]“) oder `lineart` (Schwarzweiß, G4-komprimiert) |
| `source` | `auto` | `auto` (ADF, sonst Glas), `adf` oder `flatbed` |
| `paper_size` | `A4` | `A4`, `A5`, `Letter`, `Legal` |
| `output_dir` | `/share/paperless/consume` | Zielordner, muss unter `/share` liegen |
| `filename_prefix` | `scan` | ergibt z. B. `scan_2026-10-11_14-03-12.pdf` |
| `jpeg_quality` | `85` | JPEG-Qualität der Seiten im PDF |
| `log_level` | `info` | `debug`/`trace` zur Fehlersuche |

Nach dem Ändern der Optionen das Add-on neu starten.

## Bedienung am Drucker (MFC-L2710DW)

1. Dokument in den Vorlageneinzug legen (oder aufs Glas).
2. Taste **Scan** → **zu PC** → **Datei**.
3. Ziel-PC **HomeAssistant** wählen → **Start**.

Die Menübezeichnungen können je nach Firmware-Sprache leicht abweichen.
Im Add-on-Protokoll siehst du jeden Schritt, z. B.:

```
[14:03:12] INFO: Scan-Taste: Funktion FILE, Gerät brother4:net1;dev0, 300 dpi, gray, A4, Quelle auto
[14:03:12] INFO: Scanne aus dem Vorlageneinzug (Automatic Document Feeder(centrally aligned), Modus True Gray) ...
[14:03:41] INFO: 3 Seite(n) gescannt, erzeuge PDF ...
[14:03:42] INFO: Fertig: /share/paperless/consume/scan_2026-10-11_14-03-12.pdf (3 Seite(n), 1.1M, 30 s)
```

## Netzwerk: Warum Host-Networking?

**Kurz:** Das Add-on läuft mit `host_network: true`. Das ist die einzige Variante,
die zuverlässig und ohne manuelle IP-Pflege funktioniert. Alle anderen Rechte
bleiben minimal.

**Hintergrund** (aus der Analyse von `brscan-skey` 0.3.4):

- Die Scan-Taste ist ein **Rückkanal vom Drucker zum Host**: `brscan-skey` sendet
  dem Drucker per SNMP einen Datensatz der Form
  `TYPE=BR;BUTTON=SCAN;USER="HomeAssistant";FUNC=FILE;HOST=<ip>:54925;…`.
  Der Drucker schickt das Tasten-Ereignis dann per UDP an genau diese `<ip>:54925`.
- Im normalen Add-on-Netz (Bridge, `172.30.32.0/23`) würde `brscan-skey` die
  interne Container-IP melden. Die ist aus dem LAN nicht erreichbar → die Taste
  löst nichts aus. Genau daran scheitert auch der `EXPOSE`-Versuch in der
  Vorlage `jankar86/brother-brscan4`.
- `brscan-skey` liest aus seiner Konfiguration den (undokumentierten) Schlüssel
  `ip_address=`, der die gemeldete IP fest vorgibt. Theoretisch ginge damit auch
  Bridge-Netzwerk + Portweiterleitung `54925/udp` und manuell eingetragener
  LAN-IP von Home Assistant. Das ist aber nicht praxiserprobt, bricht bei
  IP-Wechseln und benötigt ebenfalls einen offenen Host-Port.
- Auch **mit** Host-Netzwerk ist die automatische Erkennung von `brscan-skey`
  unter HAOS unzuverlässig: Sie nimmt die erste Schnittstelle außer `lo`, das
  kann `docker0` oder `hassio` sein. Das Add-on ermittelt deshalb selbst per
  `ip route get <drucker-ip>` die Quell-IP Richtung Drucker und schreibt sie fest
  als `ip_address=` in die Konfiguration. Bei Bedarf kann sie über `host_ip`
  überschrieben werden.

**So wird Host-Networking abgesichert:**

| Maßnahme | Umsetzung |
|---|---|
| Keine erweiterten Rechte | kein `privileged`, kein `full_access`, keine Geräte, keine Zusatz-Capabilities (auch kein `NET_RAW`/`NET_ADMIN`) |
| Keine APIs | kein Zugriff auf Supervisor-, Core-, Auth- oder Docker-API |
| Eigenes AppArmor-Profil | nur Netzwerkfamilien inet/inet6/netlink/unix, Schreibverbot für `/proc/sys`, `/sys`, kein `mount` |
| Minimale Mounts | nur `/share` (schreibend), sonst nichts aus Home Assistant |
| Ein offener Port | `brscan-skey` lauscht nur auf UDP 54925; kein Web-UI, kein TCP-Port |
| Treiber verifiziert | Brother-Pakete werden beim Build per SHA-256 geprüft |
| Host bleibt unverändert | keine Änderungen an HAOS, keine Host-Konfiguration, keine udev-Regeln |

Sicherheitsbewertung im Store: Basis 5, −1 für Host-Netzwerk, +1 für das eigene
AppArmor-Profil = **5 von 6**.

## Automatischer Neustart

- Stürzt `brscan-skey` ab, startet s6-overlay es im Container neu – mit
  wachsender Wartezeit (5 s, 10 s, … bis 60 s).
- Nach mehr als 5 Abstürzen in 10 Minuten beendet sich das Add-on mit Fehlercode.
  Aktiviere in der Add-on-Übersicht **Watchdog**, dann startet Home Assistant das
  Add-on anschließend komplett neu.
- Mit **Beim Booten starten** läuft das Add-on nach jedem Neustart von Home
  Assistant automatisch.
- Ist der Drucker beim Start aus, ist das kein Fehler: `brscan-skey` wiederholt
  die Anmeldung beim Drucker selbstständig.

## Fehlersuche

| Symptom | Ursache / Lösung |
|---|---|
| `HomeAssistant` erscheint nicht im Druckermenü | Drucker-IP prüfen; im Protokoll die gemeldete Host-IP prüfen (muss die LAN-IP von HA sein); Drucker und HA im selben Netz? Add-on neu starten, Drucker ggf. kurz aus- und einschalten. |
| Ziel erscheint, aber nichts passiert | Firewall/VLAN blockiert UDP 54925 vom Drucker zu HA. |
| „keine Seite erhalten“ | TCP 54921 zum Drucker blockiert oder Drucker belegt; `log_level: debug` setzen. |
| „Registrierung fehlgeschlagen“ | `printer_model` exakt schreiben, z. B. `MFC-L2710DW`. |
| Zielordner nicht beschreibbar | Pfad unter `/share` prüfen; Ordner wird automatisch angelegt. |
| PDF erscheint, Paperless ignoriert es | Paperless muss denselben Ordner (`/share/paperless/consume`) überwachen. |

Weitere Details liefert `log_level: debug` (zeigt u. a. die vom Treiber
gemeldeten Scan-Modi und -Quellen).

## Lizenz

Die Add-on-Skripte stehen unter MIT-Lizenz. Die Brother-Treiber `brscan4` und
`brscan-skey` sind proprietär (Brother Industries, Ltd.); sie werden nicht mit
dem Repository verteilt, sondern beim Bauen direkt von Brother geladen. Mit der
Installation akzeptierst du die Brother-Lizenzbedingungen.
