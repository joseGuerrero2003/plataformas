FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    bind9 bind9utils dnsutils openssl sudo rsync && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash bind || true

WORKDIR /opt/plataformas
COPY dns-primary /etc/bind
COPY scripts /opt/plataformas/scripts
COPY docker/dns/docker-entrypoint-dns.sh /opt/plataformas/docker-entrypoint-dns.sh
RUN chmod +x /opt/plataformas/docker-entrypoint-dns.sh /opt/plataformas/scripts/start_named.sh

EXPOSE 53/tcp 53/udp

ENTRYPOINT ["/opt/plataformas/docker-entrypoint-dns.sh"]
