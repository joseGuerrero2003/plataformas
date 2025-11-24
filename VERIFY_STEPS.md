# Verificación paso a paso del laboratorio Dual-Stack

Este documento guía paso a paso desde el levantamiento de las máquinas con `vagrant` hasta las comprobaciones finales: DHCPv4/DHCPv6 (Kea), DNS primario/secundario (BIND) con DNSSEC+TSIG, DNS64, servidor de correo (Postfix+Dovecot), NTP (chrony) y pruebas cliente.

Importante: ejecutar los comandos desde la raíz del proyecto (`/workspaces/plataformas`). Use un terminal con `vagrant` disponible.

**Prerequisitos**
- **Host**: `vagrant` + proveedor (VirtualBox, libvirt, etc.) instalado.
- **Proyecto**: Archivos en `Vagrantfile` y carpetas `scripts/`, `dhcp/`, `dns-primary/`, `dns-secondary/`, `mail/`, `ntp/`.

**1) Levantar el laboratorio**

Levante todas las máquinas y aplique aprovisionamiento:

```bash
vagrant up --provision
```

Si ya levantaste y solo quieres reprovisionar:

```bash
vagrant provision <nombre_maquina>
# Ejemplo: vagrant provision dns-primary
```

Esperar a que todos los `systemctl` se inicien; en caso de errores revisa `vagrant ssh <maquina>` y `journalctl -xe`.

**2) Comprobar estado general de VMs**

Listado rápido de máquinas:

```bash
vagrant status
```

Entrar en una VM (ejemplo `dhcp`):

```bash
vagrant ssh dhcp
sudo systemctl status kea-dhcp4-server kea-dhcp6-server
sudo journalctl -u kea-dhcp4-server -n 200
exit
```

**3) Verificar DHCPv4 (Kea)**

- En la VM `dhcp` comprobar servicio:

```bash
vagrant ssh dhcp -c "sudo systemctl status kea-dhcp4-server kea-dhcp6-server"
vagrant ssh dhcp -c "sudo ls -l /var/lib/kea/"
vagrant ssh dhcp -c "sudo tail -n 200 /var/log/syslog | grep -i kea || sudo journalctl -u kea-dhcp4-server -n 200"
```

- En clientes verificar que obtuvieron IPv4 e IPv6 (clientes usan DHCP):

```bash
vagrant ssh client1 -c "ip -4 -o addr show; ip -6 -o addr show"
vagrant ssh client2 -c "ip -4 -o addr show; ip -6 -o addr show"
```

- Desde el host (opcional) ver leases si el archivo existe en `dhcp` VM:

```bash
vagrant ssh dhcp -c "sudo cat /var/lib/kea/dhcp4.leases | tail -n 200"
```

Si los clientes no reciben IPv4, revisar que la interfaz host-only esté correcta en VirtualBox y que la VM `dhcp` tenga `kea-dhcp4-server` corriendo.

**4) Verificar DHCPv6 (Kea)**

- Comprobar que `kea-dhcp6-server` está activo en la VM `dhcp`:

```bash
vagrant ssh dhcp -c "sudo systemctl status kea-dhcp6-server"
vagrant ssh dhcp -c "sudo tail -n 200 /var/log/syslog | grep -i kea || sudo journalctl -u kea-dhcp6-server -n 200"
```

- En clientes verificar direcciones IPv6 ULA `fd00:100:100::/64`:

```bash
vagrant ssh client1 -c "ip -6 addr show scope global | grep fd00:100:100 || true"
```

Si no hay IA_NA/IA_PD, revisar `dhcp/kea-dhcp6.conf` y logs. Kea debe anunciar `subnet6` y pools.

**5) Verificar DNS (BIND) — resolución y transferencia por TSIG**

- En `dns-primary` comprobar BIND y zona:

```bash
vagrant ssh dns-primary -c "sudo systemctl status bind9"
vagrant ssh dns-primary -c "sudo named-checkconf /etc/bind/named.conf.local || true"
vagrant ssh dns-primary -c "sudo named-checkzone lab.local /etc/bind/zones/db.lab.local || true"
```

- Probar resolución desde `dns-primary` y desde un cliente:

```bash
vagrant ssh dns-primary -c "dig @127.0.0.1 lab.local A +short"
vagrant ssh client1 -c "dig @192.168.100.10 lab.local A +short"
```

- Forzar una consulta recursiva y comprobar DNSSEC validation en `dns-primary` (resolver recursivo hace validación):

```bash
vagrant ssh dns-primary -c "dig @127.0.0.1 www.example.com A +dnssec"
```

- Comprobar transferencia de zona en `dns-secondary` (debe crear el archivo en `/etc/bind/zones/slaves`):

```bash
vagrant ssh dns-secondary -c "sudo ls -l /etc/bind/zones/slaves || true"
vagrant ssh dns-secondary -c "sudo cat /etc/bind/zones/slaves/db.lab.local | head -n 60 || true"
```

Si la transferencia falla, revisar los logs y la clave TSIG en `dns-primary/tsig.key` está incluida en ambos `named.conf.local`.

**6) Verificar DNSSEC firmado**

- En `dns-primary` el script `generate-dnssec.sh` intenta crear claves y firmar la zona. Si el provisioning no pudo generar la firma, ejecútalo manualmente:

```bash
vagrant ssh dns-primary -c "sudo /vagrant/dns-primary/generate-dnssec.sh"
```

- Comprobar que existe el archivo firmado (ej. `/etc/bind/zones/db.lab.local.signed`) y que `named` lo sirve (ajusta `named.conf.local` si usas la versión `.signed`):

```bash
vagrant ssh dns-primary -c "ls -l /etc/bind/zones"
vagrant ssh dns-primary -c "dig @127.0.0.1 lab.local SOA +dnssec"
```

Nota: DNSSEC en laboratorio está automatizado por el script; revisar permisos y que las utilidades `dnssec-keygen` / `dnssec-signzone` estén instaladas (`apt-get install bind9-dnsutils`).

**7) Probar DNS64 (síntesis AAAA)**

- `dns-primary` tiene una configuración `dns64 64:ff9b:100::/96` en `named.conf.options`. Prueba con un nombre que sólo tenga registro A (ej. `ipv4only.test.` si lo tienes) para ver síntesis AAAA:

```bash
# Simular: consulta una IPv4-only real contra el servidor y ver AAAA sintetizado
vagrant ssh dns-primary -c "dig @127.0.0.1 example.com AAAA +short"
```

Si recibes una AAAA que empieza con `64:ff9b:100::`, la síntesis está activa.

Importante: para completar NAT64 (traducción), debes desplegar un NAT64 como `tayga` o `jool` en una VM router y enrutar la subred IPv6 a través de él. Puedo añadir provisioning para `tayga` si lo deseas.

**8) Verificar servidor de correo (Postfix + Dovecot)**

- En la VM `mail` comprobar servicios:

```bash
vagrant ssh mail -c "sudo systemctl status postfix dovecot"
vagrant ssh mail -c "sudo tail -n 200 /var/log/mail.log || sudo journalctl -u postfix -n 200"
```

- Los usuarios creados por el provisioning son `alice` y `bob` con contraseña `P@ssw0rd` (solo laboratorio). Para enviar/recibir correo desde `client1` usando la herramienta `mutt` o `mail`:

Desde `client1` enviar un correo a `alice`:

```bash
vagrant ssh client1 -c "echo 'Prueba a alice' | mail -s 'Test to alice' alice@lab.local"
```

Comprobar la llegada en `mail` (Maildir) o con `dovecot`:

```bash
vagrant ssh mail -c "sudo ls -R /home/alice/Maildir || true"
vagrant ssh mail -c "sudo tail -n 200 /var/log/mail.log | grep -i alice || true"
```

- Probar envío entre usuarios del servidor (alice -> bob) con `mail` localmente en `mail` VM:

```bash
vagrant ssh mail -c "echo 'Hola Bob' | sudo -u alice mail -s 'Hola' bob@lab.local"
vagrant ssh mail -c "sudo -u bob mail -H || true"
```

Si hay problemas de entrega, revisar `postfix` `main.cf` y que `mynetworks` incluya la LAN `192.168.100.0/24`.

**9) Verificar NTP (chrony)**

- En la VM `ntp`:

```bash
vagrant ssh ntp -c "sudo systemctl status chrony"
vagrant ssh ntp -c "chronyc tracking"
```

- En cualquier VM cliente/verificadora:

```bash
vagrant ssh client1 -c "chronyc sources"
vagrant ssh client1 -c "timedatectl status"
```

Si quieres que `chrony` use un NTP interno, configura `ntp/chrony.conf` en el proyecto y reprovisiona `ntp`.

**10) Verificación de integridad y pruebas automatizadas rápidas**

- Script de verificación general (desde host):

```bash
./scripts/check_dhcp_clients.sh
```

- Comprobar logs de cada servicio si algo falla:

```bash
vagrant ssh dns-primary -c "sudo journalctl -u bind9 -n 200"
vagrant ssh dhcp -c "sudo journalctl -u kea-dhcp4-server -n 200"
vagrant ssh mail -c "sudo journalctl -u postfix -n 200"
```

**11) Comandos útiles para ajustar / depurar**

- Reiniciar un servicio en una VM específica:

```bash
vagrant ssh dns-primary -c "sudo systemctl restart bind9"
vagrant ssh dhcp -c "sudo systemctl restart kea-dhcp4-server kea-dhcp6-server"
vagrant ssh mail -c "sudo systemctl restart postfix dovecot"
```

- Reprovisionar una máquina (sin destruirla):

```bash
vagrant provision dns-primary
```

- Obtener una shell root en una VM:

```bash
vagrant ssh dhcp
sudo -i
```

**12) Tareas adicionales (sugeridas)**
- Añadir NAT64 (`tayga` o `jool`) en una VM router y proveer reglas iptables/ndp para enrutar el prefijo `64:ff9b:100::/96` hacia IPv4. Puedo automatizar esto si lo pides.
- Habilitar DDNS seguro (TSIG) entre Kea y BIND para actualizaciones dinámicas de nombres de host. Requiere claves TSIG y ajustes tanto en Kea como en BIND.

**13) Finalización / limpieza**

- Para apagar todas las máquinas:

```bash
vagrant halt
```

- Para destruir todo el entorno (eliminar VMs):

```bash
vagrant destroy -f
```

---

Si quieres, ahora puedo:
- A) Añadir pruebas automáticas que corran internamente en las VMs (ping, dig, mails de prueba) y devuelvan un reporte.
- B) Proveer provisioning adicional para NAT64 (`tayga`) y pruebas end-to-end IPv6-only -> IPv4-only.
- C) Completar la automatización de DNSSEC (publicación de KSK/ZSK y verificación en el slave) para evitar pasos manuales.

Indícame cuál opción prefieres y continúo con esa iteración.
