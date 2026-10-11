#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Registriert den Brother-Scanner und schreibt die brscan-skey-Konfiguration.
# Läuft bei jedem Start des Add-ons; ein Fehler hier stoppt das Add-on.
# ==============================================================================
set -o pipefail

readonly SKEY_CONFIG="/opt/brother/scanner/brscan-skey/brscan-skey.config"
readonly NETDEVICE_CFG="/opt/brother/scanner/brscan4/brsanenetdevice4.cfg"
readonly HASSIO_NET_PREFIX="172.30.3"   # internes Supervisor-Netz 172.30.32.0/23

bashio::log.level "$(bashio::config 'log_level' 'info')"

printer_ip="$(bashio::config 'printer_ip')"
printer_model="$(bashio::config 'printer_model')"
scanner_name="$(bashio::config 'scanner_name')"
display_name="$(bashio::config 'display_name')"
output_dir="$(bashio::config 'output_dir')"

bashio::log.info "Brother Scan to Paperless ${ADDON_VERSION:-unbekannt}"
bashio::log.info "Drucker: ${printer_model} @ ${printer_ip} (SANE-Name: ${scanner_name})"

# ------------------------------------------------------------------------------
# Eigene IP ermitteln, die dem Drucker als Ziel für Tasten-Ereignisse gemeldet wird
# ------------------------------------------------------------------------------
if bashio::config.has_value 'host_ip'; then
    host_ip="$(bashio::config 'host_ip')"
    bashio::log.info "Host-IP aus Konfiguration: ${host_ip}"
else
    route="$(ip -4 route get "${printer_ip}" 2>&1)" \
        || bashio::exit.nok "Keine Route zum Drucker ${printer_ip}: ${route}"
    host_ip="$(sed -nE 's/.* src ([0-9.]+).*/\1/p' <<< "${route}" | head -n1)"
    iface="$(sed -nE 's/.* dev ([^ ]+).*/\1/p' <<< "${route}" | head -n1)"
    [[ -n "${host_ip}" ]] \
        || bashio::exit.nok "Konnte die eigene IP nicht ermitteln (${route}). Bitte 'host_ip' setzen."
    bashio::log.info "Host-IP automatisch ermittelt: ${host_ip} (Interface ${iface})"

    # Läuft der Weg zum Drucker über einen Router, liegen beide in verschiedenen
    # Netzen. Dann muss der Router auch UDP 54925 vom Drucker zu HA durchlassen.
    gateway="$(sed -nE 's/.* via ([0-9.]+).*/\1/p' <<< "${route}" | head -n1)"
    if [[ -n "${gateway}" ]]; then
        bashio::log.warning "Drucker (${printer_ip}) und Home Assistant (${host_ip}) liegen in verschiedenen"
        bashio::log.warning "Netzen (Router ${gateway}). Der Drucker muss ${host_ip} über UDP 54925 erreichen"
        bashio::log.warning "können, sonst erscheint '$(bashio::config 'display_name')' nicht im Druckermenü."
    fi
fi

if [[ "${host_ip}" == "${HASSIO_NET_PREFIX}"* ]]; then
    bashio::log.warning "Die IP ${host_ip} liegt im internen Supervisor-Netz und ist für den Drucker"
    bashio::log.warning "nicht erreichbar. Läuft das Add-on ohne Host-Netzwerk, muss 'host_ip' auf die"
    bashio::log.warning "LAN-IP von Home Assistant gesetzt werden (siehe Dokumentation, Abschnitt Netzwerk)."
fi

# ------------------------------------------------------------------------------
# Erreichbarkeit des Scanners prüfen (TCP 54921, ohne zusätzliche Capabilities)
# Nur Warnung: Der Drucker darf beim Start ausgeschaltet sein.
# ------------------------------------------------------------------------------
if timeout 3 bash -c "exec 3<>/dev/tcp/${printer_ip}/54921" 2>/dev/null; then
    bashio::log.info "Scanner-Port ${printer_ip}:54921 ist erreichbar."
else
    bashio::log.warning "Scanner ${printer_ip}:54921 aktuell nicht erreichbar – Drucker aus oder IP falsch?"
    bashio::log.warning "Die Registrierung wird von brscan-skey automatisch wiederholt."
fi

# ------------------------------------------------------------------------------
# Scanner bei brscan4 registrieren (vorherige Einträge entfernen)
# ------------------------------------------------------------------------------
# Einträge haben das Format: DEVICE=<name> , <modell> , <typ> , IP-ADDRESS=<ip>
while read -r existing; do
    [[ -n "${existing}" ]] || continue
    bashio::log.debug "Entferne alte Scanner-Registrierung: ${existing}"
    brsaneconfig4 -r "${existing}" >/dev/null 2>&1 || true
done < <(sed -nE 's/^DEVICE=([^ ]+) ,.*/\1/p' "${NETDEVICE_CFG}" 2>/dev/null)

brsaneconfig4 -a name="${scanner_name}" model="${printer_model}" ip="${printer_ip}" \
    || bashio::exit.nok "brsaneconfig4 konnte den Scanner nicht registrieren."

registered="$(grep -E "^DEVICE=${scanner_name} , " "${NETDEVICE_CFG}" | grep -F "IP-ADDRESS=${printer_ip}")" \
    || bashio::exit.nok "Registrierung fehlgeschlagen – ist das Modell '${printer_model}' korrekt geschrieben (z. B. MFC-L2710DW)?"
bashio::log.info "Registriert: ${registered}"
bashio::log.debug "$(brsaneconfig4 -q 2>/dev/null | sed -n '/Devices on network/,$p')"

# ------------------------------------------------------------------------------
# brscan-skey konfigurieren
#   ip_address: IP, die dem Drucker per SNMP als Ziel gemeldet wird (statt
#               Auto-Erkennung, die unter HAOS ein Docker-Interface wählen kann)
#   user:       Name, der im Druckerdisplay unter „Scan > to File“ erscheint
# brscan-skey hängt beim Aufruf den SANE-Gerätenamen als Argument an.
# ------------------------------------------------------------------------------
cat > "${SKEY_CONFIG}" <<EOF
password=
user=${display_name}
ip_address=${host_ip}
IMAGE="/usr/local/bin/brother-scan IMAGE"
OCR="/usr/local/bin/brother-scan OCR"
EMAIL="/usr/local/bin/brother-scan EMAIL"
FILE="/usr/local/bin/brother-scan FILE"
SEMID=b
EOF
bashio::log.info "brscan-skey meldet dem Drucker ${host_ip}:54925/udp als Ziel, Anzeigename '${display_name}'."

# ------------------------------------------------------------------------------
# Zielordner prüfen
# ------------------------------------------------------------------------------
mkdir -p "${output_dir}" \
    || bashio::exit.nok "Zielordner ${output_dir} kann nicht angelegt werden."
probe="${output_dir}/.brother_scan_write_test"
if ! ( : > "${probe}" ) 2>/dev/null; then
    bashio::exit.nok "Zielordner ${output_dir} ist nicht beschreibbar."
fi
rm -f "${probe}"
bashio::log.info "PDF-Ziel: ${output_dir}"

# Laufzeitverzeichnis für Lock-, Zähler- und Cache-Dateien
mkdir -p /run/brother-scan
rm -f /run/brother-scan/restarts

# ------------------------------------------------------------------------------
# Prüfen, ob SANE das Brother-Backend lädt und das Gerät kennt. Nur "-L":
# "-A"/"--help" bringen das proprietäre Backend zum Absturz.
# ------------------------------------------------------------------------------
devices="$(timeout 30 scanimage -L 2>&1)"
rc=$?
if grep -q 'brother4:net1;dev0' <<< "${devices}"; then
    bashio::log.info "SANE kennt den Scanner: $(grep -m1 'brother4:net1;dev0' <<< "${devices}")"
else
    bashio::log.warning "SANE listet den Scanner nicht (Code ${rc}): $(tr '\n' ' ' <<< "${devices}")"
fi
