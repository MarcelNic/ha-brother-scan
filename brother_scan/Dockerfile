# https://developers.home-assistant.io/docs/apps/configuration#app-dockerfile
# Debian statt Alpine: die Brother-Treiber sind glibc-Binaries (x86-64).
FROM ghcr.io/home-assistant/base-debian:trixie-2026.10.0

ARG BUILD_VERSION=dev
ARG BUILD_ARCH=amd64
ENV ADDON_VERSION="${BUILD_VERSION}"

# Proprietäre Brother-Treiber werden nicht im Repository mitgeliefert, sondern
# beim Build direkt von Brother geladen und gegen feste SHA-256-Summen geprüft.
ARG BRSCAN4_URL="https://download.brother.com/welcome/dlf105200/brscan4-0.4.11-1.amd64.deb"
ARG BRSCAN4_SHA256="027b73648722ac8c8eb1a9c419d284a6562cc763feac9740a2b75a683b092972"
ARG BRSCAN_SKEY_URL="https://download.brother.com/welcome/dlf006652/brscan-skey-0.3.4-0.amd64.deb"
ARG BRSCAN_SKEY_SHA256="6360f7e6fbb55dda9dcd05a030dca12e56f8d8ce0377d4a836297084f5cea891"

RUN \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        iproute2 \
        libtiff-tools \
        procps \
        sane-utils \
    \
    && curl -fsSL -o /tmp/brscan4.deb "${BRSCAN4_URL}" \
    && echo "${BRSCAN4_SHA256}  /tmp/brscan4.deb" | sha256sum -c - \
    && curl -fsSL -o /tmp/brscan-skey.deb "${BRSCAN_SKEY_URL}" \
    && echo "${BRSCAN_SKEY_SHA256}  /tmp/brscan-skey.deb" | sha256sum -c - \
    \
    # postinst von brscan4 schreibt eine udev-Regel (für USB, hier irrelevant)
    && mkdir -p /etc/udev/rules.d \
    && dpkg -i /tmp/brscan4.deb /tmp/brscan-skey.deb \
    && rm -f /etc/udev/rules.d/*brother* \
    \
    # brscan-skey sucht die Netzwerkgeräte u. a. unter /etc/opt/brother/...
    && mkdir -p /etc/opt/brother/scanner \
    && ln -sfn /opt/brother/scanner/brscan4 /etc/opt/brother/scanner/brscan4 \
    \
    # Nur das Brother-Backend laden: schneller und keine Abstürze fremder Backends
    && echo "brother4" > /etc/sane.d/dll.conf \
    && rm -f /etc/sane.d/dll.d/* \
    \
    && apt-get clean \
    && rm -rf /tmp/*.deb /var/lib/apt/lists/* /var/cache/apt/archives/*.deb

COPY rootfs /

RUN chmod a+x \
        /etc/cont-init.d/*.sh \
        /etc/services.d/brscan-skey/run \
        /etc/services.d/brscan-skey/finish \
        /usr/local/bin/brother-scan

LABEL \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.type="app" \
    io.hass.arch="${BUILD_ARCH}" \
    org.opencontainers.image.title="Brother Scan to Paperless" \
    org.opencontainers.image.description="brscan-skey für Brother MFC mit Ablage in Paperless-ngx" \
    org.opencontainers.image.licenses="MIT"
