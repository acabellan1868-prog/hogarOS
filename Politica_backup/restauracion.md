# Guía de restauración

> Este documento explica cómo restaurar cada componente del entorno hogarOS
> a partir de los backups generados por `backup.sh`.
>
> **Ubicación del backup:** disco externo USB montado en `/mnt/usb1/bakup_proxmox/`

---

## Estructura del backup en disco

```
/mnt/usb1/bakup_proxmox/
├── backup_actual/
│   ├── MANIFIESTO.txt
│   ├── datos/                    ← copia de /mnt/datos/ de VM 101
│   │   ├── hogarOS/             (código portal + docker-compose)
│   │   ├── fido-build/          (código FiDo)
│   │   ├── fido/fido.db.bak    (dump SQLite)
│   │   ├── redo-build/          (código ReDo)
│   │   ├── redo/redo.db.bak    (dump SQLite)
│   │   ├── medido-build/        (código MediDo)
│   │   ├── medido/medido.db.bak (dump SQLite)
│   │   ├── planka/planka_dump.sql
│   │   ├── mariadb/nextcloud_dump.sql
│   │   ├── hogar-api/           (lanzador.json)
│   │   ├── docker_estado.txt
│   │   └── docker_volumenes.txt
│   └── *.log                    (logs del proceso de backup)
├── backup_anterior/              ← copia previa (rotación)
└── dump/
    ├── vzdump-qemu-101-*.vma.zst  (imagen completa VM 101)
    └── vzdump-qemu-102-*.vma.zst  (imagen completa VM 102)
```

---

## 1. Restaurar una VM completa desde vzdump

**Cuándo:** la VM está corrupta, no arranca, o se quiere volver a un estado anterior completo.

### Pasos (desde la GUI de Proxmox)

1. Conectar y montar el disco externo:
   ```bash
   bash /root/montar_disco.sh
   ```

2. Copiar el dump de la VM al directorio de Proxmox:
   ```bash
   cp /mnt/usb1/bakup_proxmox/dump/vzdump-qemu-101-*.vma.zst /var/lib/vz/dump/
   ```

3. En la **interfaz web de Proxmox** (`https://192.168.31.103:8006`):
   - Ir a **Datacenter → Storage → local → Content**
   - Aparecerá el fichero `.vma.zst` como "VZDump backup file"
   - Click en **Restore**
   - Seleccionar el VM ID destino (101 para restaurar sobre la misma, o uno nuevo)
   - Marcar **Start after restore** si se desea arrancar inmediatamente
   - Click en **Restore** y esperar (~10-15 minutos para VM 101 de 23 GB)

4. Si se restauró con un VM ID diferente, ajustar la IP estática de la VM para que sea `192.168.31.131`.

### Alternativa por línea de comandos

```bash
# Restaurar sobre VM 101 existente (la VM debe estar apagada)
qmrestore /var/lib/vz/dump/vzdump-qemu-101-FECHA.vma.zst 101

# Restaurar como nueva VM con ID 201
qmrestore /var/lib/vz/dump/vzdump-qemu-101-FECHA.vma.zst 201
```

---

## 2. Restaurar /mnt/datos/ completo (rsync inverso)

**Cuándo:** se ha perdido o corrompido el contenido de `/mnt/datos/` en la VM 101, pero la VM sigue funcionando.

### Pasos (desde Proxmox)

1. Montar disco externo:
   ```bash
   bash /root/montar_disco.sh
   ```

2. Parar los contenedores en la VM 101 (para evitar escrituras durante la copia):
   ```bash
   ssh antonio@192.168.31.131 "cd /mnt/datos/hogarOS && docker compose down"
   ```

3. Restaurar con rsync:
   ```bash
   rsync -av --no-owner --no-group \
       /mnt/usb1/bakup_proxmox/backup_actual/datos/ \
       antonio@192.168.31.131:/mnt/datos/
   ```

   > **Nota:** no se usa `--delete` para evitar borrar ficheros nuevos que no estuvieran
   > en el backup. Si se quiere una restauración exacta, añadir `--delete`.

4. Volver a arrancar los contenedores:
   ```bash
   ssh antonio@192.168.31.131 "cd /mnt/datos/hogarOS && docker compose up -d"
   ```

---

## 3. Restaurar una base de datos SQLite (FiDo, ReDo, MediDo)

**Cuándo:** la base de datos está corrupta pero el resto del servicio funciona.

Los dumps SQLite se generan con `sqlite3 <db> ".backup <destino>"`, que produce una copia
consistente incluso si la BD está en uso.

### Desde el backup en disco externo (Proxmox → VM 101)

```bash
# Ejemplo para FiDo
scp /mnt/usb1/bakup_proxmox/backup_actual/datos/fido/fido.db.bak \
    antonio@192.168.31.131:/mnt/datos/fido/fido.db.bak
```

### Desde la VM 101

```bash
# 1. Parar el contenedor
cd /mnt/datos/hogarOS && docker compose stop fido

# 2. Hacer copia de seguridad del fichero actual (por si acaso)
cp /mnt/datos/fido/fido.db /mnt/datos/fido/fido.db.roto

# 3. Restaurar desde el backup
cp /mnt/datos/fido/fido.db.bak /mnt/datos/fido/fido.db

# 4. Arrancar el contenedor
docker compose start fido
```

**Mismo procedimiento para ReDo y MediDo**, cambiando las rutas:

| App | BD original | Backup |
|-----|-------------|--------|
| FiDo | `/mnt/datos/fido/fido.db` | `fido.db.bak` |
| ReDo | `/mnt/datos/redo/redo.db` | `redo.db.bak` |
| MediDo | `/mnt/datos/medido/medido.db` | `medido.db.bak` |

---

## 4. Restaurar PostgreSQL de Planka

**Cuándo:** la base de datos de Planka está corrupta.

### Desde la VM 101

```bash
# 1. Copiar el dump desde el disco externo (si no está ya en la VM)
#    Si se hizo rsync inverso (sección 2), ya estará en /mnt/datos/planka/

# 2. Restaurar dentro del contenedor
#    Primero borrar la BD actual y recrearla limpia, luego importar el dump

docker exec -i planka-db psql -U planka -c "DROP DATABASE IF EXISTS planka;"
docker exec -i planka-db psql -U planka -d postgres -c "CREATE DATABASE planka OWNER planka;"
docker exec -i planka-db psql -U planka -d planka < /mnt/datos/planka/planka_dump.sql
```

> **Nota:** si Planka está corriendo y conectada a la BD, puede que el `DROP DATABASE`
> falle por conexiones activas. En ese caso, parar primero el contenedor de Planka
> (no el de planka-db):
> ```bash
> docker stop planka
> # ejecutar los comandos de arriba
> docker start planka
> ```

---

## 5. Restaurar MariaDB de Nextcloud

**Cuándo:** la base de datos de Nextcloud está corrupta.

### Desde la VM 101

```bash
# 1. El dump está en /mnt/datos/mariadb/nextcloud_dump.sql

# 2. Importar dentro del contenedor
docker exec -i next-cloud-db-1 mariadb -u root -p'hscmgajc:MySql' nextcloud < /mnt/datos/mariadb/nextcloud_dump.sql
```

> **Nota:** si da error por tablas existentes, vaciar primero la BD:
> ```bash
> docker exec -i next-cloud-db-1 mariadb -u root -p'hscmgajc:MySql' -e "DROP DATABASE nextcloud; CREATE DATABASE nextcloud;"
> docker exec -i next-cloud-db-1 mariadb -u root -p'hscmgajc:MySql' nextcloud < /mnt/datos/mariadb/nextcloud_dump.sql
> ```

---

## 6. Restaurar solo el código (sin datos)

**Cuándo:** se ha roto algo en el código pero los datos están bien.

El código de cada app está en GitHub. Simplemente hacer un clone o pull limpio:

```bash
# Desde la VM 101
cd /mnt/datos/hogarOS && git pull
cd /mnt/datos/redo-build && git pull
cd /mnt/datos/fido-build && git pull
cd /mnt/datos/medido-build && git pull

# Reconstruir y arrancar
cd /mnt/datos/hogarOS && bash actualizar.sh
```

---

## 7. Restauración completa desde cero

**Cuándo:** se ha perdido todo (VM destruida, disco del servidor muerto, etc.)

### Paso 1 — Restaurar la VM en Proxmox

Seguir la sección 1 de este documento. Esto restaura la VM completa con su sistema
operativo, Docker, y toda la configuración.

### Paso 2 — Verificar servicios

```bash
ssh antonio@192.168.31.131
cd /mnt/datos/hogarOS
docker compose ps
```

Si todos los contenedores están `Up`, la restauración está completa.

### Paso 3 — Si la VM arranca pero /mnt/datos/ está vacío

Esto puede pasar si el disco de datos es un volumen separado. En ese caso:

1. Restaurar `/mnt/datos/` desde el backup (sección 2)
2. Reclonar los repos si es necesario (sección 6)
3. Arrancar los contenedores: `cd /mnt/datos/hogarOS && docker compose up -d`

---

## Verificación post-restauración

Después de cualquier restauración, comprobar:

- [ ] Portal accesible: `http://192.168.31.131`
- [ ] Tarjeta ReDo muestra datos: `http://192.168.31.131/red/`
- [ ] Tarjeta FiDo muestra datos: `http://192.168.31.131/finanzas/`
- [ ] MediDo responde: `http://192.168.31.131/salud/`
- [ ] Lanzador funciona: `http://192.168.31.131/lanzador.html`
- [ ] Home Assistant accesible via proxy: tarjeta Domótica en el portal
- [ ] Tarjeta de backup en el portal (verde si se hizo backup reciente)
