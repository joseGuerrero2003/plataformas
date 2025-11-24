FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends chrony sudo && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/plataformas
COPY ntp /etc/chrony
COPY scripts /opt/plataformas/scripts
COPY docker/ntp/docker-entrypoint-ntp.sh /opt/plataformas/docker-entrypoint-ntp.sh
RUN chmod +x /opt/plataformas/docker-entrypoint-ntp.sh /opt/plataformas/scripts/start_chrony.sh

EXPOSE 123/udp

ENTRYPOINT ["/opt/plataformas/docker-entrypoint-ntp.sh"]
