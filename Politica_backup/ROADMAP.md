# Política de Backup — Hoja de ruta

> Estado actual: análisis completado, pendiente de implementación.
> Última actualización: 2026-03-20

### Leyenda

| Icono | Significado |
|-------|-------------|
| 🤖 | Tarea de Claude (código, configuración, documentación) |
| 👤 | Tarea manual (requiere acceso a Proxmox, VM, disco externo, etc.) |

---

## Fase 1 — Prerequisitos

### 1a — Usuario antonio en grupo docker ✅

- [x] 👤 Añadir `antonio` al grupo `docker` en VM 101 (`/usr/sbin/usermod -aG docker antonio`)
- [x] 👤 Cerrar sesión y verificar con `groups`

### 1b — SSH sin contraseña (Proxmox → VM 101) ✅

- [x] 👤 Clave SSH ya existía en Proxmox (`/root/.ssh/id_rsa.pub`)
- [x] 👤 Copiar clave pública a VM 101: `ssh-copy-id antonio@192.168.31.131`
- [x] 👤 Verificar conexión sin contraseña: `ssh antonio@192.168.31.131 'hostname'` → `debian12`

---

## Fase 2 — Endpoint de backup en hogar-api

### 2a — Endpoint GET/POST /api/backup ✅

- [x] 🤖 Añadir ruta `POST /api/backup` que reciba fecha y resumen, y guarde en `backup_estado.json`
- [x] 🤖 Añadir ruta `GET /api/backup` que devuelva el estado del último backup (devuelve `{"ultima_fecha": null}` si no hay backup)

### 2b — Proxy en nginx ✅

- [x] 🤖 Añadir regla `/api/backup` → `hogar-api/backup` en `nginx.conf`

### 2c — Despliegue

- [ ] 👤 Ejecutar `actualizar.sh` en la VM para desplegar los cambios
- [ ] 👤 Verificar que `GET /api/backup` responde correctamente

---

## Fase 3 — Tarjeta "Estado del Backup" en el portal

### 3a — Tarjeta en el dashboard ✅

- [x] 🤖 Añadir tarjeta en `portal/index.html` que consuma `GET /api/backup`
- [x] 🤖 Mostrar fecha del último backup y días transcurridos
- [x] 🤖 Colores según antigüedad:
  - Verde (< 7 días): "Hace X días"
  - Naranja (7–14 días): "Hace X días — toca hacer copia"
  - Rojo fuego (> 14 días): "SIN BACKUP DESDE HACE X DIAS"
- [x] 🤖 Estado especial si no hay backup registrado: "Nunca se ha registrado un backup"
- [x] 🤖 Alimenta alertas si backup > 7 días o nunca registrado

### 3b — Despliegue y verificación

- [ ] 👤 Ejecutar `actualizar.sh` en la VM
- [ ] 👤 Verificar que la tarjeta aparece en el portal (inicialmente en rojo, sin backup registrado)

---

## Fase 4 — Script de dumps (VM 101)

### 4a — Script backup_dumps.sh

- [ ] 🤖 Crear `scripts/backup_dumps.sh` que ejecute dentro de la VM 101:
  - Dump SQLite de FiDo: `sqlite3 /mnt/datos/fido/fido.db ".backup /mnt/datos/fido/fido.db.bak"`
  - Dump SQLite de ReDo: `sqlite3 /mnt/datos/redo/redo.db ".backup /mnt/datos/redo/redo.db.bak"`
  - Dump PostgreSQL de Planka: `docker exec planka-db pg_dump -U planka planka > /mnt/datos/planka/planka_dump.sql`
  - Dump MariaDB de Nextcloud: `docker exec <contenedor_mariadb> mariadb-dump ...`
  - Snapshot Docker: `docker ps -a` y `docker volume ls` → ficheros informativos en `/mnt/datos/`
- [ ] 🤖 Notificar estado del backup a hogar-api: `curl -X POST /api/backup`
- [ ] 🤖 Log de salida con resultado de cada dump (OK/ERROR)

### 4b — Permisos y pruebas

- [ ] 👤 Copiar `backup_dumps.sh` a `/mnt/datos/hogarOS/scripts/` en la VM
- [ ] 👤 Dar permisos de ejecución: `chmod +x backup_dumps.sh`
- [ ] 👤 Ejecutar manualmente y verificar que genera los `.bak` y `.sql`
- [ ] 👤 Verificar que la tarjeta del portal cambia a verde

> **Nota:** Las rutas exactas de las BDs de Kryptonite y n8n se determinarán durante la implementación (están en volúmenes Docker gestionados por Portainer).

---

## Fase 5 — Script orquestador (Proxmox)

### 5a — Script backup.sh

- [ ] 🤖 Crear `scripts/backup.sh` para ejecutar desde la consola de Proxmox:
  1. Verificar que el disco externo está montado
  2. Rotación: renombrar `backup_actual/` → `backup_anterior/`
  3. SSH a VM 101 → ejecutar `backup_dumps.sh` (dumps de BDs)
  4. `vzdump 101 102` → disco externo (snapshot + compresión zstd)
  5. `rsync` de `/mnt/datos/` de la VM 101 → disco externo
  6. Generar `MANIFIESTO.txt` con fecha, tamaños y estado de cada paso
  7. Mostrar resumen por pantalla

### 5b — Prueba completa

- [ ] 👤 Conectar disco externo USB al servidor
- [ ] 👤 Montar disco en Proxmox
- [ ] 👤 Ejecutar `backup.sh` y verificar que completa sin errores
- [ ] 👤 Revisar `MANIFIESTO.txt` en el disco externo
- [ ] 👤 Verificar que la tarjeta del portal está en verde
- [ ] 👤 Desmontar y desconectar disco

---

## Fase 6 — Documentación de restauración

- [ ] 🤖 Crear `Politica_backup/restauracion.md` con instrucciones paso a paso:
  - Cómo restaurar una VM completa desde vzdump (GUI de Proxmox)
  - Cómo restaurar `/mnt/datos/` (rsync inverso)
  - Cómo restaurar una BD SQLite desde `.bak`
  - Cómo restaurar PostgreSQL desde `planka_dump.sql`
  - Cómo restaurar MariaDB desde `nextcloud_dump.sql`
- [ ] 🤖 Generar `README_backup.txt` para incluir en el disco externo (instrucciones básicas de restauración)

---

## Fase 7 — Recordatorio NTFY (opcional)

- [ ] 🤖 Crear script o workflow n8n que lea `backup_estado.json` y envíe notificación push si han pasado más de 7 días
- [ ] 👤 Programar ejecución semanal (cron o n8n)
- [ ] 👤 Verificar que llega la notificación al móvil

---

## Resumen de dependencias

```
Fase 1 (Prerequisitos)
    ↓
Fase 2 (Endpoint hogar-api)
    ↓
Fase 3 (Tarjeta portal)
    ↓
Fase 4 (Script dumps VM 101)
    ↓
Fase 5 (Script orquestador Proxmox)
    ↓
Fase 6 (Documentación restauración)
    ↓
Fase 7 (Recordatorio NTFY — opcional)
```
