FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    postfix dovecot-imapd dovecot-pop3d sasl2-bin sudo && rm -rf /var/lib/apt/lists/*
RUN useradd -m usuario && \
    useradd -m alice

WORKDIR /opt/plataformas
COPY mail /opt/mail
COPY scripts /opt/plataformas/scripts
COPY docker/mail/docker-entrypoint-mail.sh /opt/plataformas/docker-entrypoint-mail.sh
RUN chmod +x /opt/plataformas/docker-entrypoint-mail.sh /opt/plataformas/scripts/start_mail_services.sh

EXPOSE 25 143 993

ENTRYPOINT ["/opt/plataformas/docker-entrypoint-mail.sh"]
