#!/bin/bash
# =============================================================================
# backup_dumps.sh — Dumps seguros de bases de datos (VM 101)
#
# Este script se ejecuta DENTRO de la VM 101 (Debian 12).
# Genera dumps consistentes de todas las BDs antes de copiar ficheros.
#
# Uso: bash /mnt/datos/hogarOS/scripts/backup_dumps.sh
# =============================================================================

set -uo pipefail

# --- Configuración -----------------------------------------------------------

HOGAR_API="http://localhost/api/backup"
LOG="/mnt/datos/backup_dumps.log"
FECHA=$(date '+%Y-%m-%d %H:%M:%S')

# Bases de datos SQLite
FIDO_DB="/mnt/datos/fido/fido.db"
REDO_DB="/mnt/datos/redo/redo.db"

# PostgreSQL (Planka)
PLANKA_CONTAINER="planka-db"
PLANKA_DUMP="/mnt/datos/planka/planka_dump.sql"

# MariaDB (Nextcloud)
MARIADB_CONTAINER="next-cloud-db-1"
MARIADB_DUMP="/mnt/datos/mariadb/nextcloud_dump.sql"

# Snapshot Docker (informativo)
DOCKER_ESTADO="/mnt/datos/docker_estado.txt"
DOCKER_VOLUMENES="/mnt/datos/docker_volumenes.txt"

# --- Funciones ---------------------------------------------------------------

ERRORES=0
RESUMEN=""

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"
}

registrar() {
    # $1 = nombre, $2 = código de salida
    if [ "$2" -eq 0 ]; then
        RESUMEN="${RESUMEN}  $1: OK\n"
    else
        RESUMEN="${RESUMEN}  $1: ERROR\n"
        ERRORES=$((ERRORES + 1))
    fi
}

# --- Inicio ------------------------------------------------------------------

echo "" >> "$LOG"
log "=========================================="
log "Inicio de backup_dumps.sh — $FECHA"
log "=========================================="

# --- 1. Dump SQLite de FiDo --------------------------------------------------

log "Dump SQLite de FiDo..."
if [ -f "$FIDO_DB" ]; then
    sqlite3 "$FIDO_DB" ".backup ${FIDO_DB}.bak"
    registrar "FiDo (SQLite)" $?
    log "  → ${FIDO_DB}.bak generado"
else
    log "  → AVISO: $FIDO_DB no encontrado, saltando"
    registrar "FiDo (SQLite)" 1
fi

# --- 2. Dump SQLite de ReDo --------------------------------------------------

log "Dump SQLite de ReDo..."
if [ -f "$REDO_DB" ]; then
    sqlite3 "$REDO_DB" ".backup ${REDO_DB}.bak"
    registrar "ReDo (SQLite)" $?
    log "  → ${REDO_DB}.bak generado"
else
    log "  → AVISO: $REDO_DB no encontrado, saltando"
    registrar "ReDo (SQLite)" 1
fi

# --- 3. Dump PostgreSQL de Planka --------------------------------------------

log "Dump PostgreSQL de Planka..."
if docker ps --format '{{.Names}}' | grep -q "^${PLANKA_CONTAINER}$"; then
    docker exec "$PLANKA_CONTAINER" pg_dump -U planka planka > "$PLANKA_DUMP"
    registrar "Planka (PostgreSQL)" $?
    log "  → $PLANKA_DUMP generado"
else
    log "  → AVISO: contenedor $PLANKA_CONTAINER no está corriendo, saltando"
    registrar "Planka (PostgreSQL)" 1
fi

# --- 4. Dump MariaDB de Nextcloud --------------------------------------------

log "Dump MariaDB de Nextcloud..."
if docker ps --format '{{.Names}}' | grep -q "^${MARIADB_CONTAINER}$"; then
    docker exec "$MARIADB_CONTAINER" mariadb-dump -u root -p'hscmgajc:MySql' --no-tablespaces nextcloud > "$MARIADB_DUMP"
    registrar "Nextcloud (MariaDB)" $?
    log "  → $MARIADB_DUMP generado"
else
    log "  → AVISO: contenedor $MARIADB_CONTAINER no está corriendo, saltando"
    registrar "Nextcloud (MariaDB)" 1
fi

# --- 5. Snapshot Docker (informativo) ----------------------------------------

log "Snapshot Docker..."
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" > "$DOCKER_ESTADO" 2>/dev/null
docker volume ls > "$DOCKER_VOLUMENES" 2>/dev/null
registrar "Snapshot Docker" $?
log "  → $DOCKER_ESTADO y $DOCKER_VOLUMENES generados"

# --- 6. Notificar a hogar-api ------------------------------------------------

log "Notificando a hogar-api..."

DUMPS_OK=""
[ -f "${FIDO_DB}.bak" ] && DUMPS_OK="${DUMPS_OK}\"fido.db\","
[ -f "${REDO_DB}.bak" ] && DUMPS_OK="${DUMPS_OK}\"redo.db\","
[ -f "$PLANKA_DUMP" ] && DUMPS_OK="${DUMPS_OK}\"planka\","
[ -f "$MARIADB_DUMP" ] && DUMPS_OK="${DUMPS_OK}\"nextcloud\","
DUMPS_OK="[${DUMPS_OK%,}]"

curl -s -X POST "$HOGAR_API" \
    -H "Content-Type: application/json" \
    -d "{
        \"ultima_fecha\": \"$(date -Iseconds)\",
        \"dumps_ok\": ${DUMPS_OK},
        \"errores\": ${ERRORES}
    }" > /dev/null 2>&1 && {
    log "  → Notificación enviada a hogar-api"
} || {
    log "  → AVISO: no se pudo notificar a hogar-api (¿nginx caído?)"
}

# --- Resumen -----------------------------------------------------------------

log "------------------------------------------"
log "Resumen:"
echo -e "$RESUMEN" | tee -a "$LOG"

if [ "$ERRORES" -eq 0 ]; then
    log "Resultado: TODO OK"
else
    log "Resultado: $ERRORES error(es)"
fi

log "=========================================="
log "Fin de backup_dumps.sh"
log "=========================================="

exit $ERRORES
