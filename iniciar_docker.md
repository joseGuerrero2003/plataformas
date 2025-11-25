# Iniciar Docker

Este documento recoge los comandos en orden para construir, levantar y verificar todos los servicios del proyecto (DHCP - Kea, DNS primario/secundario - BIND, Mail - Postfix/Dovecot y NTP - Chrony).

Requisitos previos:
- Docker + Docker Compose instalados y funcionando.
- Estar en la raíz del repositorio (`/workspaces/plataformas`).

1) Construir las imágenes

Usa la `Makefile` incluida o Docker Compose directamente.

Con Makefile (recomendado):
```bash
make build
```

Con Docker Compose:
```bash
docker compose build --parallel
```

2) Levantar los servicios

Modo por defecto (puente Docker):
```bash
make up
# ó
docker compose up -d
```

Si necesitas que los servicios usen la red del host (recomendado para pruebas DHCP/DHCPv6 reales), usa el override:
```bash
make up-host
# ó
docker compose -f docker-compose.yml -f docker-compose.override-host.yml up -d
```

3) Comprobar que los contenedores están corriendo
```bash
docker compose ps
docker compose logs -f --tail=100
```

4) Verificar DNS (BIND)

- Comprobar que la zona `lab.local` está cargada en el primario:
```bash
docker compose exec dns_primary dig @127.0.0.1 lab.local SOA +short
```

- Comprobar que el secundario intenta transferencia AXFR y forzar una transferencia manual:
```bash
# Desde el secundario (prueba AXFR contra el primario)
docker compose exec dns_secondary dig @dns_primary lab.local AXFR
```

Si obtienes `Transfer status: timed out` o no ves registros, revisa:
- Que `dns-secondary/named.conf.local` tiene como `masters` el hostname `dns_primary` o la IP accesible desde la red Docker.
- Que existe la clave TSIG en `dns-primary/tsig.key` y que ese archivo se monta en el secundario con permisos que permitan lectura (no debe estar montado en modo `ro` si necesitas cambiar permisos dentro del contenedor).

5) Regenerar / crear la clave TSIG (si faltara)

Este fragmento crea una clave segura y la guarda en `dns-primary/tsig.key` en formato que BIND incluye (usa OpenSSL para generar el secreto):
```bash
# Genera secreto Base64
KEY=$(openssl rand -base64 32)
cat > dns-primary/tsig.key <<EOF
key "transfer-key" {
  algorithm hmac-sha256;
  secret "$KEY";
};
EOF

# Asegúrate de permisos razonables (UID de tu usuario en host suele ser 1000)
chmod 640 dns-primary/tsig.key
chown $(id -u):$(id -g) dns-primary/tsig.key
```

Notas importantes:
- El archivo `dns-primary/tsig.key` debe estar disponible también al `dns_secondary` (ya sea montándolo o copiándolo al contenedor). Evita montarlo con `:ro` si el entrypoint necesita ajustar permisos; si prefieres no permitir cambios, copia la clave dentro del contenedor en tiempo de arranque.
- Si prefieres generar la clave dentro del contenedor (y no en el host), ejecuta:
```bash
docker compose exec dns_primary bash -c 'KEY=$(openssl rand -base64 32) && cat >/etc/bind/tsig.key <<EOF
key "transfer-key" { algorithm hmac-sha256; secret "$KEY"; };
EOF'
```

6) Asegurar que `masters` del secundario apunta al primario por nombre de servicio

Editar `dns-secondary/named.conf.local` y sustituir cualquier IP fija por `dns_primary` (nombre del servicio Compose). Ejemplo (host del `masters`):
```conf
masters {
  dns_primary;
};
```

Puedes hacer el cambio con `sed` (desde la raíz del repo):
```bash
sed -i 's/192.168.100.10/dns_primary/g' dns-secondary/named.conf.local
```

Luego reinicia los servicios DNS:
```bash
docker compose up -d --build dns_primary dns_secondary
docker compose logs -f dns_secondary --tail=200
```

7) Verificar DHCP (Kea)

- Comprobar logs de Kea:
```bash
docker compose exec dhcp tail -n 200 /var/log/kea/kea-dhcp4.log
```

- Verificar fichero de leases:
```bash
docker compose exec dhcp cat /var/lib/kea/dhcp4.leases
```

Nota: para que DHCP (especialmente DHCPv6) funcione plenamente sobre una red real puede requerir `network_mode: host` en Docker.

8) Verificar NTP (Chrony)

```bash
docker compose exec ntp chronyc sources
docker compose exec ntp chronyc tracking
```

9) Verificar Mail (Postfix + Dovecot)

- Comprobar procesos y logs:
```bash
docker compose exec mail ps aux | egrep 'postfix|dovecot'
docker compose exec mail tail -n 200 /var/log/postfix-foreground.log
docker compose exec mail tail -n 200 /var/log/dovecot-foreground.log
```

- Enviar un correo de prueba desde el contenedor (si los usuarios están creados):
```bash
docker compose exec mail bash -c 'echo "Prueba" | sendmail -v usuario@lab.local'
```

10) Comandos útiles de diagnóstico

- Ver IPs asignadas a servicios:
```bash
docker compose ps -q | xargs docker inspect --format '{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

- Ejecutar un `dig` desde tu host (si mapeaste puertos) contra el primario:
```bash
dig @127.0.0.1 -p 5353 lab.local SOA +short
```

11) Solución de problemas rápida

- Si `dns_secondary` no puede conectar al primario:
  - Confirma la IP/hostname del `masters` en `dns-secondary/named.conf.local`.
  - Asegúrate que el puerto 53 del primario es accesible desde la red Docker (o usa `network_mode: host`).

- Si `chown`/`chmod` sobre `tsig.key` falla dentro del contenedor: no montes el archivo como `:ro`; monta un volumen Docker para las claves o copia la clave en el container al arrancar.

12) Reinicio completo

```bash
docker compose down
docker compose up -d --build
```
