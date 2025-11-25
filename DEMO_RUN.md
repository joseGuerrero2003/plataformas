DEMO: Comandos para levantar y verificar el laboratorio Dual-Stack
===============================================================

Este archivo contiene, en orden, los comandos necesarios para levantar el laboratorio con `vagrant` (provider: Docker), verificar el correcto funcionamiento de los servicios (Kea DHCPv4/DHCPv6, BIND primario/secundario con DNSSEC/TSIG y DNS64, servidor de correo Postfix+Dovecot, clientes) y acciones de debugging/recuperación comunes en contenedores.

Ejecuta los comandos desde la raíz del proyecto `/workspaces/plataformas` en el host o Codespaces.

PRE-REQUISITOS
-------------
- Docker instalado y en ejecución.
- Vagrant instalado (versión que soporte provider `docker`).
- Permisos para ejecutar Docker desde tu usuario.

PASOS (ordenados)
-----------------

1) Limpiar cualquier estado previo (recomendado)

```bash
vagrant destroy -f || true
docker ps -a --filter "name=plataforma" || true
```

2) Asegurarse de que los scripts sean ejecutables (opcional pero recomendado)

```bash
chmod +x ./scripts/*.sh || true
```

3) Levantar todo el laboratorio (puede tardar unos minutos)

```bash
vagrant up --provider=docker
```

4) Verificar el estado de las máquinas Vagrant

```bash
vagrant status
```

5) Listar contenedores Docker creados por Vagrant

```bash
docker ps -a --format "table {{.Names}}	{{.Status}}	{{.Ports}}"
```

6) Comprobar logs de aprovisionamiento por cada contenedor (si alguno falló)

```bash
docker logs dns-primary   | tail -n 200
docker logs dns-secondary | tail -n 200
docker logs dhcp          | tail -n 200
docker logs mail          | tail -n 200
docker logs client1       | tail -n 200
docker logs client2       | tail -n 200
```

7) Verificaciones básicas de red y hostnames dentro de cada contenedor

```bash
docker exec -it dns-primary   hostname -f; ip -4 -o addr show || true
docker exec -it dns-secondary hostname -f; ip -4 -o addr show || true
docker exec -it dhcp          hostname -f; ip -4 -o addr show || true
docker exec -it mail          hostname -f; ip -4 -o addr show || true
docker exec -it client1       hostname -f; ip -4 -o addr show || true
docker exec -it client2       hostname -f; ip -4 -o addr show || true
```

8) Comprobar Kea DHCPv4 y DHCPv6 (en la VM `dhcp`)

Revisar procesos e intentos de arranque:

```bash
docker exec -it dhcp ps aux | egrep "kea|dhcp" || true
```

Ver leases (si Kea escribió archivos de lease):

```bash
docker exec -it dhcp bash -lc "[ -f /var/lib/kea/dhcp4.leases ] && tail -n 200 /var/lib/kea/dhcp4.leases || echo 'No dhcp4 leases file'"
docker exec -it dhcp bash -lc "[ -f /var/lib/kea/dhcp6.leases ] && tail -n 200 /var/lib/kea/dhcp6.leases || echo 'No dhcp6 leases file'"
```

Si Kea no está corriendo (systemd no se ejecuta en contenedores), arráncalo manualmente en foreground para debugging:

```bash
docker exec -it dhcp bash -lc "/usr/sbin/kea-dhcp4 -c /etc/kea/kea-dhcp4.conf &>/var/log/kea-dhcp4.log &"
docker exec -it dhcp bash -lc "/usr/sbin/kea-dhcp6 -c /etc/kea/kea-dhcp6.conf &>/var/log/kea-dhcp6.log &"
docker exec -it dhcp tail -n 200 /var/log/kea-dhcp4.log

Nota: si al intentar asignar una dirección IPv6 dentro del contenedor recibes "RTNETLINK answers: Operation not permitted", es porque el contenedor no tiene las capacidades necesarias para manipular interfaces (NET_ADMIN/NET_RAW). Soluciones:

1) Recrear el contenedor `dhcp` con las capacidades apropiadas en `Vagrantfile` (ya incluidas en este repo): `--cap-add=NET_ADMIN --cap-add=NET_RAW` y `--sysctl net.ipv6.conf.all.disable_ipv6=0`, luego `vagrant destroy -f dhcp && vagrant up --provider=docker dhcp`.

2) Si arrancaste el contenedor con `docker run`, recrearlo con las flags:

```bash
docker run --cap-add=NET_ADMIN --cap-add=NET_RAW --sysctl net.ipv6.conf.all.disable_ipv6=0 ...
```

3) Como alternativa temporal, si tienes privilegios en el host, añade la dirección IPv6 en la interfaz del host o lanza el contenedor con `--privileged` (no recomendado en entornos compartidos).

```

9) Comprobar DNS (BIND) en `dns-primary` y transferencia a `dns-secondary`

Prueba de resolución local en el primario:

```bash
docker exec -it dns-primary bash -lc "dig @127.0.0.1 lab.local A +short"
docker exec -it dns-primary bash -lc "dig @127.0.0.1 lab.local AAAA +short"
```

Si `named` no está activo por systemd, arranca `named` en foreground para debugging y ver logs:

```bash
docker exec -it dns-primary bash -lc "/vagrant/scripts/start_named.sh"
```

Verificar transferencia en el esclavo:

```bash
docker exec -it dns-secondary bash -lc "ls -l /etc/bind/zones/slaves || true"
docker exec -it dns-secondary bash -lc "[ -f /etc/bind/zones/slaves/db.lab.local ] && echo 'Slave zone exists' || echo 'Slave zone missing'"
```

Prueba DNS desde un cliente (usa la IP del contenedor primario o el nombre si resuelve):

```bash
docker exec -it client1 bash -lc "apt-get update -qq && apt-get install -y -qq dnsutils || true; dig @127.0.0.1 lab.local A +short || dig @$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-primary) lab.local A +short"
```

10) Probar DNSSEC y DNS64 (si está configurado)

```bash
docker exec -it dns-primary bash -lc "dig @127.0.0.1 lab.local SOA +dnssec"
docker exec -it dns-primary bash -lc "dig @127.0.0.1 example.com AAAA +short"
```

11) Probar servidor de correo (en `mail`) — envío desde cliente

Enviar un mensaje desde `client1` hacia `alice@lab.local`:

```bash
docker exec -it client1 bash -lc "apt-get update -qq && apt-get install -y -qq mailutils || true; echo 'Mensaje de prueba' | mail -s 'Test desde client1' alice@lab.local"
```

Comprobar entrega en `mail`:

```bash
docker exec -it mail bash -lc "ls -R /home/alice/Maildir || echo 'Maildir no encontrado'"
docker exec -it mail bash -lc "tail -n 200 /var/log/mail.log || echo 'Sin mail.log (revisa /var/log)'"
```

Si Postfix/Dovecot no se inician por systemd, arráncalos en foreground dentro del contenedor (solo para debugging):

```bash
docker exec -it mail bash -lc "/vagrant/scripts/start_mail_services.sh"
```

12) Verificar clientes obtuvieron direcciones (DHCP)

```bash
docker exec -it client1 bash -lc "ip -4 -o addr show; ip -6 -o addr show"
docker exec -it client2 bash -lc "ip -4 -o addr show; ip -6 -o addr show"
```

13) Comprobaciones finales y limpieza

```bash
vagrant status
docker ps -a --format "table {{.Names}}	{{.Status}}	{{.Ports}}"

# Para detener y eliminar todo cuando termines
vagrant destroy -f
```

TROUBLESHOOTING: problemas comunes y soluciones
------------------------------------------------
- Error: "systemd not running" o servicios no arrancan
  - Motivo: contenedores Docker no ejecutan systemd por defecto.
  - Solución temporal: arrancar servicios en foreground dentro del contenedor (ejemplos arriba). Para un entorno más estable, construye una imagen Docker personalizada con systemd o con los servicios configurados para ejecutarse en primer plano.

- Error: permisos en `/vagrant/scripts/*.sh` o scripts no encontrados
  - Solución: `chmod +x scripts/*.sh` localmente; revisa que `d.volumes` esté montando el directorio correcto.

- Error: paquetes no encontrados o apt falla
  - Solución: revisa conectividad de red desde el contenedor: `docker exec -it <container> ping -c2 8.8.8.8` y reintenta `apt-get update`.

