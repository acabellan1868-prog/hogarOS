# Política de Backup — Análisis

> Estado: en discusión
> Fecha inicio: 2026-03-20

---

## Objetivo

Definir una estrategia de backup integral para todo el entorno hogarOS y servicios asociados, que permita recuperarse ante fallos de hardware, corrupción de datos o errores humanos.

---

## Inventario de lo que hay que proteger

### 1. Máquinas virtuales (Proxmox)

Nodo: **deeloco** (Proxmox VE 8.3.0, autónomo, sin cluster)
Almacenamiento: `local`, `local-lvm`, `localnetwork`

| VM | SO | Función | Estado |
|----|----|---------|--------|
| 101 | Debian 12.8 | hogarOS, FiDo, ReDo, Portainer, n8n, JupyterLab, Planka, NodeRed, Nextcloud... | Ejecutándose |
| 102 | HAOS 14.0 | Home Assistant | Ejecutándose |
| 103 | Lubuntu | _(sin uso, candidata a eliminar)_ | Parada |

### 2. Bases de datos

| App | Tipo | Ubicación |
|-----|------|-----------|
| FiDo | SQLite | /mnt/datos/fido/fido.db |
| ReDo | SQLite | /mnt/datos/redo/redo.db |
| Kryptonite | SQLite | Volumen Docker (JupyterLab) |
| Planka | PostgreSQL | Volumen Docker (planka-db, user: planka, db: planka) |
| Nextcloud | MariaDB | /mnt/datos/mariadb/ (montado como /var/lib/mysql) |
| n8n | SQLite | Volumen Docker |

### 3. Datos de aplicaciones

| Datos | Ubicación |
|-------|-----------|
| Configuración hogarOS | /mnt/datos/hogarOS/ |
| Código fuente | GitHub (ya respaldado) |
| Configuración lanzador | /mnt/datos/hogar-api/ |
| Datos Nextcloud (ficheros) | Volumen Docker |
| Workflows n8n | Volumen Docker |
| Notebooks JupyterLab | Volumen Docker |

### 4. Configuración del sistema

- docker-compose.yml y ficheros de configuración
- Configuración de Proxmox
- Configuración de red / Tailscale

---

## Preguntas — Respondidas

1. **¿Qué VMs hay en Proxmox?** → 3 VMs: 101 (Debian, producción), 102 (HAOS, producción), 103 (Lubuntu, parada, a eliminar). Efectivamente **2 VMs activas**.
2. **¿Destino de backups?** → **Disco externo USB** (~500 GB) conectado al servidor.
3. **¿Backup en la nube?** → No contemplado por ahora. Disco externo es suficiente.
4. **¿RPO (cuánto se puede perder)?** → **1 semana**. Entorno doméstico, no se mueven grandes cantidades de datos.
5. **¿RTO (cuánto sin servicio)?** → Por determinar.
6. **¿Nextcloud y Planka, qué BD usan?** → Planka: **PostgreSQL** (user: planka, db: planka). Nextcloud: **MariaDB** (volumen en `/mnt/datos/mariadb/`).
7. **¿Dónde están los volúmenes Docker?** → Los volúmenes externos están en `/mnt/datos/`, fuera de los contenedores.
8. **¿Kryptonite tiene datos persistentes?** → Sí, base de datos SQLite.
9. **¿Disco externo?** → Se monta bajo demanda (conectar → montar → backup → desmontar). ~500 GB de capacidad.
10. **¿Disco conectado a Proxmox o a la VM?** → Se monta **a nivel de Proxmox** (host). Desde ahí se hacen ambas cosas.

---

## Procedimiento actual (manual)

El usuario ya hace backups manuales con este flujo:

1. Conectar disco externo USB al servidor
2. Montar el disco desde Proxmox (host)
3. **Backup de VMs**: copiar las máquinas virtuales con herramientas de Proxmox (`vzdump` o copia de imágenes)
4. **Backup de datos**: montar `/mnt/datos/` de la VM 101 y copiar todos los directorios (volúmenes Docker con datos persistentes)
5. Desmontar disco externo

### Qué cubre

| Elemento | ¿Cubierto? |
|----------|------------|
| VMs completas (SO + config) | ✅ Copia de VMs desde Proxmox |
| Datos de apps (`/mnt/datos/`) | ✅ Copia directa de directorios |
| Bases de datos SQLite | ⚠️ Copia de ficheros (no backup caliente — riesgo de corrupción si la app está escribiendo) |
| Bases de datos PostgreSQL/MySQL | ⚠️ Copia de ficheros del volumen (mismo riesgo) |
| Código fuente | ✅ GitHub |
| Config Proxmox | ❓ No mencionado |

### Puntos débiles

1. **Proceso manual sin frecuencia fija** — se hace "cuando me acuerdo"
2. **No hay dump de BDs** — copiar el fichero SQLite/PostgreSQL mientras la app escribe puede dar una copia corrupta. Lo correcto es hacer `sqlite3 db ".backup destino"` o `pg_dump` antes de copiar
3. **Sin rotación** — solo se mantiene una copia, se sobrescribe cada vez
4. **Sin verificación** — no se comprueba que el backup sea restaurable

---

## Propuesta de mejora — Backup asistido por script

Filosofía: **el proceso sigue siendo manual** (conectar disco, lanzar, desconectar), pero un script hace todo el trabajo pesado de forma segura y consistente. Cuando conectes el disco, ejecutas un comando y te vas a tomar un café.

### Flujo propuesto

```
1. Conectar disco externo USB al servidor
2. Montar el disco en Proxmox
3. Ejecutar script de backup (desde Proxmox):
   a) vzdump de VM 101 y VM 102 → disco externo
   b) SSH a VM 101 → dump seguro de BDs → copiar /mnt/datos/ al disco
   c) Rotación: mantener backup actual + anterior (2 copias)
   d) Generar manifiesto con fecha, tamaños y estado
4. Revisar el resumen que imprime el script
5. Desmontar y desconectar disco externo
```

### Paso 3a — Backup de VMs (vzdump)

- `vzdump 101 102 --dumpdir <disco_externo>/vms/ --compress zstd --mode snapshot`
- Modo snapshot: no para las VMs, backup en caliente
- Compresión zstd: rápido y eficiente
- Resultado: un fichero `.vma.zst` por VM, restaurable desde la GUI de Proxmox con un clic

### Paso 3b — Backup de datos (SSH a VM 101)

El script se conecta por SSH a la VM 101 y ejecuta:

1. **Dump seguro de SQLite** (antes de copiar):
   - `sqlite3 /mnt/datos/fido/fido.db ".backup /mnt/datos/fido/fido.db.bak"`
   - `sqlite3 /mnt/datos/redo/redo.db ".backup /mnt/datos/redo/redo.db.bak"`
   - Idem para Kryptonite y n8n (una vez localicemos las rutas exactas)
2. **Dump de PostgreSQL** (Planka):
   - `docker exec planka-db pg_dump -U planka planka > /mnt/datos/planka/planka_dump.sql`
3. **Dump de MariaDB** (Nextcloud):
   - `docker exec <contenedor_mariadb> mariadb-dump -u root -p<password> --all-databases > /mnt/datos/mariadb/nextcloud_dump.sql`
3. **Snapshot Docker** (informativo):
   - `docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"` → `/mnt/datos/docker_estado.txt`
   - `docker volume ls` → `/mnt/datos/docker_volumenes.txt`

Después, desde Proxmox se copia `/mnt/datos/` completo al disco externo con `rsync`:
- `rsync -av --delete /mnt/vm101/datos/ <disco_externo>/datos/`

### Paso 3c — Rotación

- Directorio en disco externo: `backup_actual/` y `backup_anterior/`
- Antes de cada backup: renombrar `backup_actual/` → `backup_anterior/` (la anterior se pierde)
- Resultado: siempre **2 copias** (la de hoy y la de la vez anterior)
- Con 500 GB y 2 copias, hay margen de sobra para un entorno doméstico

### Paso 3d — Manifiesto

El script genera `backup_actual/MANIFIESTO.txt`:
```
Fecha: 2026-03-20 18:30
VM 101: vzdump-qemu-101-2026_03_20.vma.zst (12.3 GB) ✅
VM 102: vzdump-qemu-102-2026_03_20.vma.zst (4.1 GB) ✅
Datos /mnt/datos/: 8.2 GB copiados ✅
SQLite dumps: fido.db.bak ✅ | redo.db.bak ✅
Último backup anterior: 2026-03-06
```

### Recordatorio de backup — Tarjeta en el portal + NTFY

#### Tarjeta "Estado del Backup" en hogarOS

Nueva tarjeta en el dashboard que muestra la fecha del último backup y cambia de color según la antigüedad:

| Antigüedad | Color | Mensaje |
|------------|-------|---------|
| < 7 días | 🟢 Verde | "Último backup: hace X días" |
| 7–14 días | 🟠 Naranja | "Último backup: hace X días — toca hacer copia" |
| > 14 días | 🔴 Rojo fuego | "⚠️ SIN BACKUP DESDE HACE X DÍAS" |

**Implementación:**

1. El script de backup, al terminar con éxito, hace un `POST /api/backup` a hogar-api con la fecha y un resumen
2. hogar-api guarda la fecha en un fichero JSON (`/mnt/datos/hogar-api/backup_estado.json`)
3. El portal lee `GET /api/backup` y pinta la tarjeta con el color correspondiente
4. La tarjeta se refresca cada vez que se carga el portal (no necesita refresco periódico, no cambia mientras miras)

Ejemplo de `backup_estado.json`:
```json
{
  "ultima_fecha": "2026-03-20T18:30:00",
  "vms": ["101", "102"],
  "datos_ok": true,
  "dumps_ok": ["fido.db", "redo.db"],
  "tamano_total": "24.6 GB"
}
```

#### Notificación NTFY (complementaria)

Además, un cron semanal (o workflow n8n) que lea `backup_estado.json` y envíe una notificación push al móvil si han pasado más de 7 días:

> "Hace X días del último backup. ¿Toca conectar el disco?"

Así tienes el recordatorio incluso si no abres el portal.

---

## Prerequisitos — Estado

| Prerequisito | Estado |
|-------------|--------|
| Usuario `antonio` en grupo `docker` | ✅ Configurado (2026-03-20) |
| SSH desde Proxmox a VM 101 (antonio) | ❓ Pendiente de configurar clave pública |
| Todas las preguntas respondidas | ✅ Completado |

**Nota sobre permisos en VM 101:**
- No hay `sudo` instalado, se usa `su` para root
- `antonio` ya puede ejecutar `docker exec`, `docker ps`, etc. sin privilegios extra
- Para `sqlite3` sobre ficheros de root, puede hacer falta `su` o ajustar permisos de los `.db`

---

## Próximos pasos

1. ✅ Análisis y diseño completado
2. Configurar SSH sin contraseña desde Proxmox → VM 101 (antonio)
3. Añadir endpoint `GET/POST /api/backup` a hogar-api
4. Añadir tarjeta "Estado del Backup" en el portal
5. Escribir `backup_dumps.sh` (VM 101) — dumps de BDs
6. Escribir `backup.sh` (Proxmox) — orquestador: vzdump + SSH + rsync + rotación + manifiesto
7. Probar todo junto con el disco externo conectado
8. Documentar procedimiento de restauración
9. (Opcional) Configurar recordatorio NTFY semanal
