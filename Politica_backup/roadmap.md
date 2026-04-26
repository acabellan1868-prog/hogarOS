# Política de Backup — Hoja de ruta

> Estado actual: todas las fases completadas. Pendiente solo verificar NTFY en producción.
> Última actualización: 2026-04-01

### Leyenda

| Icono | Significado |
|-------|-------------|
| 🤖 | Tarea de Claude (código, configuración, documentación) |
| 👤 | Tarea manual (requiere acceso a Proxmox, VM, disco externo, etc.) |

---

## Fase 1 — Prerequisitos ✅

### 1a — Usuario antonio en grupo docker ✅

- [x] 👤 Añadir `antonio` al grupo `docker` en VM 101 (`/usr/sbin/usermod -aG docker antonio`)
- [x] 👤 Cerrar sesión y verificar con `groups`

### 1b — SSH sin contraseña (Proxmox → VM 101) ✅

- [x] 👤 Clave SSH ya existía en Proxmox (`/root/.ssh/id_rsa.pub`)
- [x] 👤 Copiar clave pública a VM 101: `ssh-copy-id antonio@192.168.31.131`
- [x] 👤 Verificar conexión sin contraseña: `ssh antonio@192.168.31.131 'hostname'` → `debian12`

---

## Fase 2 — Endpoint de backup en hogar-api ✅

### 2a — Endpoint GET/POST /api/backup ✅

- [x] 🤖 Añadir ruta `POST /api/backup` que reciba fecha y resumen, y guarde en `backup_estado.json`
- [x] 🤖 Añadir ruta `GET /api/backup` que devuelva el estado del último backup (devuelve `{"ultima_fecha": null}` si no hay backup)

### 2b — Proxy en nginx ✅

- [x] 🤖 Añadir regla `/api/backup` → `hogar-api/backup` en `nginx.conf`

### 2c — Despliegue ✅

- [x] 👤 Ejecutar `actualizar.sh` en la VM para desplegar los cambios
- [x] 👤 Verificar que `GET /api/backup` responde correctamente

---

## Fase 3 — Tarjeta "Estado del Backup" en el portal ✅

### 3a — Tarjeta en el dashboard ✅

- [x] 🤖 Añadir tarjeta en `portal/index.html` que consuma `GET /api/backup`
- [x] 🤖 Mostrar fecha del último backup y días transcurridos
- [x] 🤖 Colores según antigüedad:
  - Verde (< 7 días): "Hace X días"
  - Naranja (7–14 días): "Hace X días — toca hacer copia"
  - Rojo fuego (> 14 días): "SIN BACKUP DESDE HACE X DIAS"
- [x] 🤖 Estado especial si no hay backup registrado: "Nunca se ha registrado un backup"
- [x] 🤖 Alimenta alertas si backup > 7 días o nunca registrado

### 3b — Despliegue y verificación ✅

- [x] 👤 Ejecutar `actualizar.sh` en la VM
- [x] 👤 Verificar que la tarjeta aparece en el portal (inicialmente en rojo, sin backup registrado)

---

## Fase 4 — Script de dumps (VM 101) ✅

### 4a — Script backup_dumps.sh ✅

- [x] 🤖 Crear `Politica_backup/backup_dumps.sh` que ejecute dentro de la VM 101:
  - Dump SQLite de FiDo: `sqlite3 /mnt/datos/fido/fido.db ".backup /mnt/datos/fido/fido.db.bak"`
  - Dump SQLite de ReDo: `sqlite3 /mnt/datos/redo/redo.db ".backup /mnt/datos/redo/redo.db.bak"`
  - Dump PostgreSQL de Planka: `docker exec planka-db pg_dump -U planka planka > /mnt/datos/planka/planka_dump.sql`
  - Dump MariaDB de Nextcloud: `docker exec next-cloud-db-1 mariadb-dump -u root -p'...' --all-databases > /mnt/datos/mariadb/nextcloud_dump.sql`
  - Snapshot Docker: `docker ps -a` y `docker volume ls` → ficheros informativos en `/mnt/datos/`
- [x] 🤖 Notificar estado del backup a hogar-api: `curl -X POST /api/backup`
- [x] 🤖 Log de salida con resultado de cada dump (OK/ERROR)

### 4b — Permisos y pruebas ✅

- [x] 👤 Hacer `git pull` en la VM 101 para obtener el script
- [x] 👤 Instalar `sqlite3` y `rsync` en la VM 101: `apt install sqlite3 rsync`
- [x] 👤 Ejecutar manualmente como root: `bash /mnt/datos/hogarOS/Politica_backup/backup_dumps.sh` → TODO OK
- [x] 👤 Verificar que genera los `.bak` y `.sql` en `/mnt/datos/`
- [x] 👤 Verificar que la tarjeta del portal cambia a verde
- [x] 👤 Dar permisos a `antonio` sobre `/mnt/datos/fido` y `/mnt/datos/redo` para dumps SQLite

> **Nota:** Como `antonio`, los dumps de Planka (PostgreSQL) y Nextcloud (MariaDB) dan warning por permisos, pero los ficheros `.sql` se generan correctamente ya que `docker exec` los ejecuta dentro del contenedor. El script trata estos casos como WARNING.

---

## Fase 5 — Script orquestador (Proxmox) ✅

### 5a — Script backup.sh ✅

- [x] 🤖 Crear `Politica_backup/backup.sh` para ejecutar desde la consola de Proxmox:
  1. Verificar que el disco externo está montado en `/mnt/usb1`
  2. Rotación: renombrar `backup_actual/` → `backup_anterior/`
  3. SSH a VM 101 → ejecutar `backup_dumps.sh` (dumps de BDs)
  4. Copiar dumps de VMs más recientes de `/var/lib/vz/dump/` → disco externo (VM 101: ~23 GB, VM 102: ~2 GB)
  5. `rsync` de `/mnt/datos/` (~1.8 GB) de la VM 101 → disco externo
  6. Generar `MANIFIESTO.txt` con fecha, tamaños y estado de cada paso
  7. Mostrar resumen por pantalla

### 5b — Prueba completa ✅

- [x] 👤 Conectar disco externo USB al servidor
- [x] 👤 Montar disco: `mount /dev/sdb1 /mnt/usb1`
- [x] 👤 Copiar `backup.sh` a Proxmox: `scp antonio@192.168.31.131:/mnt/datos/hogarOS/Politica_backup/backup.sh /root/backup.sh`
- [x] 👤 Ejecutar `bash /root/backup.sh` → BACKUP COMPLETADO SIN ERRORES (con warnings de permisos)
- [x] 👤 Revisar `MANIFIESTO.txt`: VMs ✅, datos 2.1 GB ✅, 4 dumps de BDs ✅
- [x] 👤 Verificar que la tarjeta del portal está en verde
- [ ] 👤 Desmontar y desconectar disco: `umount /mnt/usb1`

### Capacidad del disco externo

| Elemento | Tamaño |
|----------|--------|
| Disco externo | 117 GB (84 GB libres) |
| VM 101 dump | ~23 GB |
| VM 102 dump | ~2 GB |
| /mnt/datos/ | ~1.8 GB |
| **Total por backup** | **~27 GB** |
| **2 copias (rotación)** | **~54 GB** |
| **Margen libre** | **~30 GB** |

---

## Fase 6 — Documentación de restauración ✅

- [x] 🤖 Crear `Politica_backup/restauracion.md` con instrucciones paso a paso:
  - Restaurar VM completa desde vzdump (GUI de Proxmox y CLI)
  - Restaurar `/mnt/datos/` (rsync inverso)
  - Restaurar BD SQLite desde `.bak` (FiDo, ReDo, MediDo)
  - Restaurar PostgreSQL desde `planka_dump.sql`
  - Restaurar MariaDB desde `nextcloud_dump.sql`
  - Restauración solo de código (git pull)
  - Restauración completa desde cero
  - Checklist de verificación post-restauración

---

## Fase 7 — Notificación NTFY ✅

- [x] 🤖 Añadir notificación NTFY al final de `backup.sh` (topic `hogaros-3ca6f61b`)
  - Sin errores: prioridad normal, check verde
  - Con errores: prioridad alta, warning
  - Incluye resumen de pasos en el cuerpo del mensaje
- [ ] 👤 Ejecutar un backup y verificar que llega la notificación al móvil
- [ ] 👤 Actualizar `backup.sh` en Proxmox:
  ```bash
  wget -O /root/backup.sh https://raw.githubusercontent.com/acabellan1868-prog/hogarOS/main/Politica_backup/backup.sh
  chmod +x /root/backup.sh
  ```

---

## Fase 8 — Estado estructurado para portal ✅

Mejora rápida para que el backup no solo registre fecha, sino también detalle básico
del resultado en `hogar-api`.

- [x] 🤖 `backup.sh` genera `backup_estado.json` al final del proceso
- [x] 🤖 `backup.sh` verifica de forma básica los dumps esperados tras el `rsync`:
  - `fido/fido.db.bak`
  - `redo/redo.db.bak`
  - `medido/medido.db.bak`
  - `planka/planka_dump.sql`
  - `mariadb/nextcloud_dump.sql`
- [x] 🤖 `backup.sh` cuenta VMs copiadas y tamaño de `backup_actual`
- [x] 🤖 `backup.sh` envía el JSON final a `POST /api/backup`
- [x] 🤖 `hogar-api` mantiene compatibilidad con el formato antiguo y normaliza la respuesta
- [x] 🤖 La tarjeta del portal muestra dumps, VMs, tamaño y duración si esos datos existen
- [x] 🤖 `backup_dumps.sh` no da por bueno un dump si el comando falla o el fichero queda vacío
- [ ] 👤 Copiar/actualizar `backup.sh` en Proxmox y ejecutar backup real
- [ ] 👤 Verificar en portada que aparecen los datos enriquecidos
- [ ] 👤 Verificar que la VM 101 tiene actualizado `backup_dumps.sh` (`grep validar_generado`)
- [ ] 👤 Revisar permisos de MariaDB/Nextcloud si `mariadb-dump` sigue fallando:
  - proceso MariaDB observado como `mysql` UID/GID `999:999`
  - `/var/lib/mysql` y `/var/lib/mysql/nextcloud` observados como `1000:1000`
  - revisar también escritura en `/mnt/datos/mariadb/nextcloud_dump.sql`

---

## Resumen de dependencias

```
Fase 1 (Prerequisitos)              ✅
    ↓
Fase 2 (Endpoint hogar-api)         ✅
    ↓
Fase 3 (Tarjeta portal)             ✅
    ↓
Fase 4 (Script dumps VM 101)        ✅ probado
    ↓
Fase 5 (Script orquestador Proxmox) ✅ probado
    ↓
Fase 6 (Documentación restauración) ✅
    ↓
Fase 7 (Notificación NTFY)          ✅ (pendiente verificar en producción)
    ↓
Fase 8 (Estado estructurado)        ✅ (pendiente verificar con backup real)
```
