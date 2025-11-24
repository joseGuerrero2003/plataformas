Este directorio contiene el Dockerfile y el entrypoint para los servicios DNS.

Notas:
- Por defecto el `docker-compose.yml` expone los servicios en puertos alternativos
  (`5353`) para evitar conflictos en hosts donde el puerto 53 ya esté ocupado.
- Si quieres que los servicios DNS atiendan la interfaz host, usa el override
  `docker-compose.override-host.yml` y levanta con `docker compose -f docker-compose.yml -f docker-compose.override-host.yml up -d`.
