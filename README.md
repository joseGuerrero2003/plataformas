# Laboratorio Dual-Stack (IPv4 + IPv6) con Vagrant

Este repositorio contiene una infraestructura de laboratorio Dual-Stack (IPv4 privado + IPv6 ULA) preparada para ejecutarse con `vagrant up`.
Servicios incluidos:
- Kea DHCPv4 y DHCPv6 (servidor `dhcp`)
- BIND9 DNS primario (`dns-primary`) y secundario (`dns-secondary`) con DNSSEC y TSIG
- DNS64 configurado en el primario (prefijo `64:ff9b:100::/96`)
- Postfix + Dovecot (servidor `mail`) con dos usuarios de prueba `alice` y `bob`
- Chrony (NTP) (`ntp`)
- Dos clientes `client1` y `client2` para pruebas de mail

Rangos y direccionamiento (decididos por el proyecto):
- IPv4 LAN: `192.168.100.0/24` (gateway `192.168.100.1`)
- DHCPv4 reserva/pool: `192.168.100.100 - 192.168.100.200`
- IPv6 ULA: `fd00:100:100::/48` (LAN `fd00:100:100::/64` gateway `fd00:100:100::1`)
- DNS64 NAT64 prefix: `64:ff9b:100::/96`

Arranque rápido:
1. Instala Vagrant y VirtualBox (u otro provider compatible).
2. En el directorio del proyecto ejecuta:

```bash
vagrant up
```

3. Para reprovisionar una máquina específica:
```bash
vagrant provision dns-primary
```

Notas importantes:
- Los scripts de aprovisionamiento están en `scripts/` y usan archivos de configuración en `dhcp/`, `dns-primary/`, `dns-secondary/`, `mail/` y `ntp/`.
- La clave TSIG compartida está en `dns-primary/tsig.key` (laboratorio). En producción nunca almacenes claves en texto plano.
- Script `dns-primary/generate-dnssec.sh` genera claves DNSSEC y firma la zona.
# Infraestructura Dual-Stack: Diseño, requisitos y verificación

Este repositorio contiene la documentación y guía necesaria para implementar una infraestructura de laboratorio/producción con las siguientes características requeridas:

- Dual Stack (IPv4 + IPv6)
- Servidor DHCPv4 (evaluación sobre DHCPv6)
- Al menos dos servidores DNS privados (primario y secundario) con DNSSEC y TSIG
- Un servidor DNS autoritativo (se asignará) y DNS64
- Servidor de correo (MTA/IMAP/POP) con al menos dos clientes
- Sincronización NTP de todos los servidores
- Herramientas y comandos para comprobación y monitorización

Este README explica la solución propuesta, componentes necesarios, ejemplos de configuración y comandos de verificación / monitoreo.

**Resumen de la solución**

- Topología mínima propuesta:
  - `vm-ntp` : Servidor NTP (opcional, puede usar pool.ntp.org)
  - `vm-dhcp` : Servidor DHCPv4 (y opcional DHCPv6)
  - `vm-dns-master` : Servidor DNS primario (BIND) con DNSSEC
  - `vm-dns-slave` : Servidor DNS secundario (BIND) con TSIG para transferencias
  - `vm-dns64` : Servidor/DNS resolver que implemente DNS64 (puede ser combinado con resolver interno)
  - `vm-mail` : Servidor correo (Postfix + Dovecot)
  - `vm-client1`, `vm-client2` : Clientes de correo / pruebas

- Recomendación de aprovisionamiento: usar `Vagrant` para crear máquinas y `Ansible` para configurar servicios (playbooks por servicio).

**Requisitos por servicio (paquetes / tecnologías)**

- Sistema base: Debian/Ubuntu LTS es preferible para ejemplos (apt). CentOS/RHEL similar con nombres de paquetes distintos.

- DHCPv4: `isc-dhcp-server`.
- DHCPv6 (opcional): `isc-dhcp-server` soporta dhcpv6 con `dhcpd6`, también se puede usar `wide-dhcpv6` u otro.
- DNS (resolver/authoritative): `bind9` (BIND 9.11+ recomendado para soporte DNS64/DNSSEC moderno).
- DNSSEC: utilidades `dnssec-keygen`, `dnssec-signzone`, y `named-checkconf`/`named-checkzone` (incluidas en bind9utils o bind9-dnsutils).
- TSIG (transferencias seguras): se generan claves HMAC (p. ej. HMAC-SHA256) y se incorporan a `named.conf` en bloques `key`.
- DNS64: configuración de `dns64` en BIND o usar `bind` + `views` o `pdns` con soporte DNS64.
- Mail server: `postfix` (MTA) + `dovecot` (IMAP/POP) + `spamassassin`/`rspamd` opcional para filtrado.
- Clientes de correo: `mutt`, `thunderbird` o clientes CLI `swaks` para pruebas SMTP.
- NTP: `chrony` (recomendado) o `ntp`.
- Monitorización / logs / comprobación: `prometheus` + `node_exporter` + `grafana` (opcional), `netdata`, `nagios`/`check_mk`, `syslog`/`rsyslog`, `journalctl`, `logrotate`.

**Decisión sobre DHCPv6**

- Para una red Dual-Stack hay 2 enfoques para IPv6 address assignment:
  - SLAAC (Stateless Address Autoconfiguration) + RDNSS para indicar DNS: sencillo, recomendado cuando no se necesita control centralizado de direcciones.
  - DHCPv6 (stateful) para asignar direcciones y opciones (DNS, etc.): necesario si se requiere control centralizado (leases, reservas, inventario).

- Recomendación: implementar SLAAC + RDNSS para simplicidad y, si necesitan control de direcciones y leases o inventario, implementar DHCPv6 stateful.

**Ejemplos de configuración (snippets)**

1) DHCPv4 (`/etc/dhcp/dhcpd.conf` básico):

```
authoritative;
option domain-name "example.local";
option domain-name-servers 10.0.0.10, 10.0.0.11;
default-lease-time 600;
max-lease-time 7200;

subnet 10.0.0.0 netmask 255.255.255.0 {
  range 10.0.0.100 10.0.0.200;
  option routers 10.0.0.1;
}
```

2) DHCPv6 (opcional) (`/etc/dhcp/dhcpd6.conf`):

```
default-lease-time 600;
max-lease-time 7200;

subnet6 2001:db8:1:0::/64 {
  range6 2001:db8:1:0::100 2001:db8:1:0::1ff;
}
```

3) BIND: named.conf.options (resolver con DNS64 example):

```
options {
  directory "/var/cache/bind";
  recursion yes;
  allow-query { any; };
  forwarders { 8.8.8.8; 8.8.4.4; };
  dns64 64:ff9b::/96 {
    map {
      exclude { ::ffff:0.0.0.0/96; };
    };
  };
};
```

Nota: la sintaxis exacta de `dns64` varía según la versión de BIND; confirmar versión y documentación.

4) BIND: ejemplo de clave TSIG (generada con `dnssec-keygen` / `tsig-keygen`):

```
key "transfer-key" {
  algorithm hmac-sha256;
  secret "BASE64ENCODED==";
};

zone "example.local" {
  type master;
  file "/etc/bind/zones/db.example.local";
  allow-transfer { key transfer-key; };
};
```

En el secondary:

```
server 10.0.0.10 {
  keys { transfer-key; };
};

zone "example.local" {
  type slave;
  file "/var/cache/bind/db.example.local";
  masters { 10.0.0.10; };
};
```

5) Firmado DNSSEC (flujo básico):

- Generar claves KSK/ZSK:

```
dnssec-keygen -a RSASHA256 -b 2048 -n ZONE example.local   # ZSK
dnssec-keygen -a RSASHA256 -b 4096 -n ZONE -f KSK example.local   # KSK
```

- Firmar zona:

```
dnssec-signzone -A -3 `head -c 1000 /dev/urandom | sha1sum | cut -b 1-16` -N increment -o example.local -t db.example.local
```

6) Mail server (Postfix + Dovecot) comprobaciones básicas:

- Postfix main.cf (fragmento):

```
myhostname = mail.example.local
mydomain = example.local
myorigin = $mydomain
mydestination = $myhostname, localhost.$mydomain, localhost
relayhost =
inet_interfaces = all
inet_protocols = all  # para Dual-Stack
smtpd_tls_cert_file=/etc/letsencrypt/live/mail.example.local/fullchain.pem
smtpd_tls_key_file=/etc/letsencrypt/live/mail.example.local/privkey.pem
```

- Dovecot: habilitar protocolos `imap`, `pop3`, `submission` y autenticación adecuada.

**Sincronización NTP**

- Instalar `chrony` en todos los hosts y apuntar a `pool.ntp.org` o al `vm-ntp` interno.

Ejemplo `/etc/chrony/chrony.conf` (cliente):

```
pool 2.pool.ntp.org iburst
allow 10.0.0.0/24   # si este host actúa como servidor para la LAN
```

Verificar: `chronyc sources` y `chronyc tracking`.

**Comprobaciones y herramientas de diagnóstico**

- Red y conectividad:
  - `ip a`, `ip -6 a`, `ip route`, `ip -6 route`
  - `ping` y `ping6` / `ping -6`
  - `ss -tunlp` / `netstat -tunlp`

- DHCP:
  - `systemctl status isc-dhcp-server`
  - Revisar `/var/lib/dhcp/dhcpd.leases`
  - `dhcping` para probar (si está disponible)

- DNS:
  - `named-checkconf` y `named-checkzone`
  - `dig @10.0.0.10 example.local SOA +dnssec` para comprobar DNSSEC
  - `dig +short AAAA www.example.com` y comprobar resolución (DNS64: `dig @dns64server www.ipv4-only.example +short` deberían devolver IPv6 sintético)
  - `dig @ns2 example.local AXFR -y hmac:transfer-key:BASE64KEY` para probar transferencias TSIG

- DNSSEC validation:
  - `dig +dnssec www.example.local` y comprobar RRSIG
  - `delv` (resolver con validación) si disponible

- Mail:
  - `swaks --to user@example.local --server 10.0.0.20 --from test@local` para enviar pruebas SMTP
  - Revisar logs `/var/log/mail.log` o `journalctl -u postfix`

- NTP:
  - `chronyc sources` y `chronyc tracking`

- Monitorización y métricas:
  - `node_exporter` para métricas de servidores (Prometheus)
  - `grafana` para dashboards
  - `netdata` para monitorización inmediata

**Seguridad y buenas prácticas**

- Usar claves TSIG con HMAC-SHA256 para transferencias entre master/slave.
- Proteger las llaves DNSSEC y tener backups seguros.
- Habilitar TLS (STARTTLS) en SMTP y autenticar clientes.
- Configurar firewall (ufw/iptables/nftables) sólo permitiendo puertos necesarios: DNS(53), DNS64/recursion sólo dentro de la red, DHCP(67/68), SMTP(25/587/465), IMAP(143/993), POP3(110/995), NTP(123).

**Automatización propuesta**

- Vagrant + Ansible:
  - `Vagrantfile` para crear VMs (cada VM con NICs IPv4/IPv6 y un `private_network` para la LAN dual-stack).
  - Playbooks Ansible por rol: `ntp`, `dhcp`, `dns_master`, `dns_slave`, `dns64/resolver`, `mail`, `clients`.

- Inventory ejemplo (`inventory.ini`):

```
[ntp]
vm-ntp ansible_host=192.168.56.10

[dhcp]
vm-dhcp ansible_host=192.168.56.11

[dns]
vm-dns-master ansible_host=192.168.56.12
vm-dns-slave ansible_host=192.168.56.13

[mail]
vm-mail ansible_host=192.168.56.14

[clients]
vm-client1 ansible_host=192.168.56.21
vm-client2 ansible_host=192.168.56.22
```

**Comandos de verificación rápidos**

- DNSSEC: `dig @10.0.0.12 example.local SOA +dnssec`
- Transferencia TSIG: `dig @10.0.0.13 example.local AXFR -y hmac:transfer-key:BASE64KEY`
- DHCP lease: `tail -n 50 /var/lib/dhcp/dhcpd.leases`
- SMTP send test: `swaks --to admin@example.local --server 10.0.0.14`
- NTP check: `chronyc sources` y `chronyc tracking`

**Checklist mínima para empezar (qué te hace falta)**

- Infraestructura de virtualización: `Vagrant`, `VirtualBox`/`libvirt` o servidor KVM.
- Herramienta de automatización: `Ansible` (altamente recomendable).
- Sistemas base (imágenes): Debian/Ubuntu LTS para todas las VMs.
- Paquetes listados arriba instalables por playbook.
- Certificados TLS (Let's Encrypt) o CA internal para TLS en mail y, si se desea, para HTTPS de paneles de administración.
- Claves TSIG y claves DNSSEC generadas y almacenadas de forma segura.

**Siguientes pasos — si quieres, puedo:**

- 1) Generar un `Vagrantfile` de ejemplo con N máquinas (coordinado con la topología propuesta).
- 2) Crear playbooks Ansible para aprovisionar: `ntp`, `dhcp`, `bind-dns` (master/slave), `bind-dns64`, `postfix+dovecot` y clientes.
- 3) Añadir ejemplos concretos de zonas firmadas y scripts para firmarlas automáticamente.

Si quieres que continúe y te entregue el `Vagrantfile` + playbooks de Ansible listos para ejecutar, dime cuántas VMs quieres crear en la máquina local y si prefieres `VirtualBox` o `libvirt`/KVM. También confirma si deseas DHCPv6 (stateful) o sólo SLAAC + RDNSS.

---
Archivo creado por: Guía de implementación automática. Para cualquier fragmento de configuración que quieras que genere completo (archivo listo para copiar), indícamelo y lo agrego al repo.
