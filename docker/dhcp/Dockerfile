FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# Intentar instalar paquetes con los nombres presentes en la mayoría de repos
# Si no se encuentran, añadimos el repositorio oficial de ISC Kea como fallback.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends wget gnupg lsb-release ca-certificates sudo; \
    if apt-get install -y --no-install-recommends kea-dhcp4-server kea-dhcp6-server; then \
        echo "Kea packages installed from distro repos"; \
    else \
        echo "Kea packages not in distro repos, adding ISC package repository"; \
        DIST=$(lsb_release -cs || echo "focal"); \
        # Add ISC packages repository (may require internet access from build host)
        echo "deb [signed-by=/usr/share/keyrings/isc-archive-key.gpg] https://packages.isc.org/apt/ ${DIST}-kea110 main" > /etc/apt/sources.list.d/isc-kea.list || true; \
        wget -qO /usr/share/keyrings/isc-archive-key.gpg https://packages.isc.org/isc/keys/isc-archive-key.gpg || true; \
        apt-get update; \
        apt-get install -y --no-install-recommends kea-dhcp4-server kea-dhcp6-server || true; \
    fi; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/plataformas
COPY dhcp /etc/kea
COPY scripts /opt/plataformas/scripts
COPY docker/dhcp/docker-entrypoint-dhcp.sh /opt/plataformas/docker-entrypoint-dhcp.sh
RUN chmod +x /opt/plataformas/docker-entrypoint-dhcp.sh /opt/plataformas/scripts/start_kea.sh

EXPOSE 67/udp

ENTRYPOINT ["/opt/plataformas/docker-entrypoint-dhcp.sh"]
