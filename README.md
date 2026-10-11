# Brother Scan-Key Apps für Home Assistant

Home-Assistant-Add-on-Repository (Add-ons heißen in neueren Versionen „Apps“) mit:

| Add-on | Beschreibung |
|---|---|
| [Brother Scan to Paperless](brother_scan/) | Scan-Taste am Brother MFC (z. B. MFC-L2710DW) → 300-dpi-PDF in `/share/paperless/consume` |

Basiert auf [jankar86/brother-brscan4](https://github.com/jankar86/brother-brscan4),
umgebaut als Home-Assistant-Add-on (Konfiguration über die Oberfläche, s6-overlay,
AppArmor, Paperless-Ablage).

## Installation

### 1. Repository hinzufügen

[![Repository hinzufügen](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FMarcelNic%2Fha-brother-scan)

Oder manuell:

1. **Einstellungen → Add-ons/Apps → Store** öffnen.
2. Oben rechts **⋮ → Repositories**.
3. `https://github.com/MarcelNic/ha-brother-scan` eintragen → **Hinzufügen**.
4. Store neu laden (⋮ → **Nach Updates suchen**).

### 2. Add-on installieren

1. Im Store **Brother Scan to Paperless** öffnen → **Installieren**.
   Das Image wird lokal auf deinem Mini-PC gebaut (einige Minuten); dabei werden
   die Brother-Treiber direkt von brother.com geladen und per SHA-256 geprüft.
2. Reiter **Konfiguration**: mindestens `printer_ip` setzen, z. B.:

   ```yaml
   printer_ip: 192.168.1.207
   printer_model: MFC-L2710DW
   display_name: HomeAssistant
   resolution: "300"
   output_dir: /share/paperless/consume
   ```

3. Reiter **Info**: **Beim Booten starten** und **Watchdog** aktivieren → **Starten**.
4. Reiter **Protokoll** prüfen. Erwartet wird u. a.:

   ```
   INFO: Host-IP automatisch ermittelt: 192.168.1.10 (Interface enp1s0)
   INFO: Registriert: DEVICE=Brother , MFC-L2710DW , … , IP-ADDRESS=192.168.1.207
   INFO: brscan-skey läuft (PID 123). Registrierte Geräte: ...
   ```

### 3. Am Drucker scannen

**Scan → zu PC → Datei → HomeAssistant → Start.** Das PDF erscheint nach wenigen
Sekunden in `/share/paperless/consume` und wird von Paperless-ngx übernommen.

### 4. Paperless-ngx

Paperless muss `/share/paperless/consume` als Consume-Ordner nutzen – beim
Paperless-ngx-Add-on ist das üblicherweise der Fall; bei einem eigenen Container
`/share/paperless/consume` als Consume-Volume einbinden.

## Netzwerk & Sicherheit

Das Add-on benötigt Host-Networking, weil der Drucker Tasten-Ereignisse per UDP
an eine IP sendet, die ihm vorher gemeldet wurde – eine interne Container-IP wäre
nicht erreichbar. Die ausführliche Analyse und die Absicherung (eigenes
AppArmor-Profil, keine Capabilities, keine APIs, nur `/share`) stehen in
[brother_scan/DOCS.md](brother_scan/DOCS.md#netzwerk-warum-host-networking).

Am Home Assistant OS selbst wird nichts verändert: Alles läuft im Add-on-Container,
geschrieben wird nur in den konfigurierten Ordner unter `/share`.

## Struktur

```
repository.yaml                    Repository-Metadaten für den Add-on-Store
brother_scan/
├── config.yaml                    Add-on-Definition, Optionen, Rechte
├── Dockerfile                     Debian-Basis + Brother-Treiber
├── apparmor.txt                   eigenes AppArmor-Profil
├── DOCS.md / README.md / CHANGELOG.md
├── icon.png / logo.png
├── translations/{de,en}.yaml      Beschriftung der Optionen
└── rootfs/
    ├── etc/cont-init.d/10-brother-setup.sh   Registrierung & Konfiguration beim Start
    ├── etc/services.d/brscan-skey/run        Listener (s6-Dienst)
    ├── etc/services.d/brscan-skey/finish     Neustart-/Watchdog-Logik
    └── usr/local/bin/brother-scan            Scan → PDF → Consume-Ordner
```

## Lizenz

MIT für den Code in diesem Repository (siehe [LICENSE](LICENSE)). Die
Brother-Treiber sind proprietär und werden nicht mitgeliefert.
