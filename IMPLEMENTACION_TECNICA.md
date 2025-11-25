# Implementación técnica — Proyecto "plataformas"

Este documento recoge cómo se implementó técnicamente el laboratorio, los cambios realizados en archivos de configuración, y los comandos exactos para levantar, probar y depurar los servicios. Está escrito en español y pensado para reproducir la demo paso a paso.

Índice
- Resumen de la arquitectura
- Lista de servicios y responsabilidades
- Cambios en archivos de configuración (resumen por archivo)
- Comandos para construir / levantar / probar
- Procedimientos especiales (TSIG / DNSSEC / macvlan DHCP client)
- Notas finales y buenas prácticas

---

## Resumen de la arquitectura

El laboratorio está orquestado con Docker Compose. Servicios principales:

- `dhcp` (Kea DHCPv4 y opcional DHCPv6)
- `dns_primary` (BIND primario, TSIG, DNS64, soportes de DNSSEC)
- `dns_secondary` (BIND secundario, AXFR con TSIG)
- `mail` (Postfix + Dovecot; usuarios de prueba)
- `ntp` (Chrony)

Todos los servicios se ejecutan en una red Docker `plataformas_net` configurada con subnet IPv4 `172.18.0.0/16` (definida en `docker-compose.yml`). Por seguridad/consistencia, las claves TSIG se comparten a través del volumen `bind_keys`.

---

## Lista de servicios y responsabilidades

- `plataformas_dhcp`:
  - Ejecuta Kea DHCPv4 (config: `dhcp/kea-dhcp4.conf`).
  - Opcional: Kea DHCPv6 (config: `dhcp/kea-dhcp6.conf`) — requiere red IPv6 para pruebas.

- `plataformas_dns_primary` (IP fija 172.18.0.10):
  - Autoritativo para `lab.local`.
  - Soporta DNS64 (config en `dns-primary/named.conf.options`).
  - Incluye soporte para DNSSEC (scripts en `dns-primary/generate-dnssec.sh`).
  - Tsig key incluida en `dns-primary/tsig.key` y sincronizada vía volumen `bind_keys`.

- `plataformas_dns_secondary` (IP fija 172.18.0.11):
  - Slave que obtiene zonas por AXFR usando la clave TSIG.

- `plataformas_mail`:
  - Postfix + Dovecot; usuarios `alice`, `bob`, `usuario` creados por `mail/create_mail_users.sh`.

- `plataformas_ntp`:
  - Chrony; configurado para usar `pool.ntp.org` por defecto (archivo: `ntp/chrony.conf`).

---

## Cambios en archivos de configuración (resumen)

Los cambios más relevantes realizados durante la implementación y depuración:

- `docker-compose.yml`:
  - Definida la red `plataformas_net` con `subnet: 172.18.0.0/16`.
  - Asignadas IPs estáticas para los servicios DNS (172.18.0.10 y 172.18.0.11) para evitar ambigüedades A/AAAA.
  - Volumen `bind_keys` creado y montado en ambos contenedores DNS.

- `dhcp/kea-dhcp4.conf`:
  - Antes: la subred estaba en `192.168.100.0/24` y el `pool` apuntaba a rangos `172.18.0.x` (mezcla y error de sintaxis JSON).
  - Cambiado a servir la red Docker entera:
    - `"subnet": "172.18.0.0/16"`
    - `"pools": [{"pool": "172.18.0.50 - 172.18.0.200"}]`
  - Se corrigió la sintaxis JSON (coma faltante) y se ajustaron opciones de router/ DNS dentro del `option-data`.

- `dhcp/kea-dhcp6.conf`:
  - Archivo con configuración de ejemplo para DHCPv6 (`fd00:100:100::/64`), quedó presente pero necesita red IPv6 activa para pruebas.

- `dns-primary/named.conf.options`:
  - Añadida la directiva `dns64 64:ff9b:100::/96` con `clients { any; }` para pruebas NAT64.
  - `dnssec-validation auto;` habilitado para validación.

- `dns-primary/named.conf.local` y `dns-secondary/named.conf.local`:
  - Incluyen `include "/etc/bind/tsig.key";` y configuran transferencias AXFR con `key transfer-key`.

- `dns-primary/generate-dnssec.sh`:
  - Script añadido para generar KSK/ZSK (`dnssec-keygen`) y firmar la zona (`dnssec-signzone`).

- `mail/create_mail_users.sh`:
  - Script que crea tres usuarios de prueba (`alice`, `bob`, `usuario`), crea `Maildir` y fija contraseñas.

- `MConfig` y `README.md`:
  - Documentación con comandos reproducibles y pasos de verificación.

---

## Comandos para construir, levantar y probar (lista práctica)

1) Construir y levantar todo:

```bash
docker compose up -d --build
```

2) Reconstruir y levantar un servicio concreto (ej. DHCP):

```bash
docker compose up -d --no-deps --build dhcp
```

3) Logs de un servicio:

```bash
docker compose logs -f --tail=200 dns_primary
docker compose logs -f --tail=200 dhcp
```

4) Ver AXFR desde secundario (usar IP fija del primario):

```bash
docker compose exec dns_secondary dig @172.18.0.10 lab.local AXFR
```

5) Probar DNSSEC en el primario (si la zona está firmada):

```bash
docker compose exec dns_primary dig @127.0.0.1 lab.local SOA +dnssec +noqr
```

6) Probar e inspeccionar Kea DHCP (logs y procesos):

```bash
docker compose logs -f dhcp
docker compose exec dhcp ps aux | grep kea || true
```

7) Obtener un lease real (procedimiento macvlan usado en la demo):

```bash
# 1. crear interfaz macvlan en el host (reemplazar br-XXX por el bridge detectado)
sudo ip link add link br-34676fe4d132 name mvtest0 type macvlan mode bridge
sudo ip link set mvtest0 up

# 2. arrancar cliente en contenedor que use mvtest0
docker run --rm --network host --privileged -v "$PWD/dhcp-client-logs":/var/lib/dhcpcd alpine:3.18 \
  sh -lc "apk add --no-cache udhcpc iproute2; udhcpc -i mvtest0 -n -q; ip -4 addr show dev mvtest0 | awk '/inet /{print \$2}' > /var/lib/dhcpcd/eth0.lease; cat /var/lib/dhcpcd/eth0.lease"

# 3. limpiar la interfaz macvlan
sudo ip link delete mvtest0
```

8) Probar mail (envío simple):

```bash
docker compose exec mail sendmail -v usuario@lab.local <<'EOF'
Subject: Prueba

Mensaje de prueba
EOF

docker compose exec mail ls -l /home/usuario/Maildir/new
```

9) Ver estado de NTP / Chrony:

```bash
docker compose exec ntp chronyc sources
docker compose exec ntp chronyc tracking
```

---

## Procedimientos especiales y notas técnicas

### TSIG (transferencias seguras AXFR)

- Archivo de ejemplo: `dns-primary/tsig.key`
- Forma: bloque `key "transfer-key" { algorithm hmac-sha256; secret "..."; };`
- El entrypoint de los contenedores DNS copia/usa esta clave en el `volume` `bind_keys` para que tanto primario como secundario la lean desde `/var/lib/bind/keys`.

Comando para probar AXFR autenticado (si hace falta especificar clave en línea):

```bash
dig @172.18.0.10 lab.local AXFR -y hmac:transfer-key:V1J6dG5Gd1FLbmprY2tGc3BtV0ZxQm5sV1hTQmM0WXM=
```

### DNSSEC (firmado de zona)

- Script: `dns-primary/generate-dnssec.sh`.
- Flujo básico que se automatizó en el repo:
  1. `dnssec-keygen` para KSK y ZSK
  2. `dnssec-signzone -o lab.local ...` crea `.signed`
  3. Recargar `named` (systemctl reload bind9 o `service bind9 reload`) o reiniciar el contenedor.

Comando rápido dentro del contenedor primario:

```bash
docker compose exec dns_primary bash -lc "cd /etc/bind/zones && dnssec-signzone -o lab.local db.lab.local"
docker compose exec dns_primary rndc reload || service bind9 reload || true
```

### DHCPv6

- La configuración de Kea para DHCPv6 existe (`dhcp/kea-dhcp6.conf`) pero **no** es funcional en la red Docker actual porque `docker-compose.yml` no tiene IPv6 habilitado.
- Opciones para habilitar DHCPv6:
  - Habilitar IPv6 en la red Docker (añadir `enable_ipv6: true` y un subnet IPv6) y recrear contenedores.
  - O ejecutar Kea en `network_mode: host` para pruebas en el host.

### Macvlan y permisos

- Para crear interfaces macvlan se necesita `sudo` en el host. La demo creó `mvtest0` sobre el bridge Docker detectado y ejecutó un contenedor en `--network host --privileged` que montó un volumen para guardar el lease.

---

## Cambios en control de versiones y consideraciones operacionales

- Se añadió `MConfig` y `IMPLEMENTACION_TECNICA.md` (este archivo) para documentar comandos exactos.
- Se corrigió y actualizó `dhcp/kea-dhcp4.conf` para servir `172.18.0.0/16` y evitar errores de selección de subnet.
- Se actualizó `README.md` para usar la IP fija del primario en comandos AXFR y evitar ambigüedades A/AAAA en `dig`.
- Se añadió entrada en `.gitignore` para `dhcp-client-logs` y se limpió el archivo de lease del índice git para evitar conflictos al hacer `git pull`/`push`.

---
