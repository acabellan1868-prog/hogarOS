#!/bin/bash
# =============================================================================
# backup.sh — Script orquestador de backup (ejecutar desde Proxmox)
#
# Uso: bash /ruta/backup.sh
#
# Pasos:
#   1. Verificar que el disco externo está montado
#   2. Rotación: backup_actual → backup_anterior
#   3. SSH a VM 101 → ejecutar backup_dumps.sh (dumps de BDs)
#   4. Copiar dumps de VMs (vzdump semanal de Proxmox) → disco externo
#   5. rsync de /mnt/datos/ de la VM 101 → disco externo
#   6. Generar MANIFIESTO.txt
#   7. Mostrar resumen por pantalla
# =============================================================================

set -euo pipefail

# --- Configuración -----------------------------------------------------------

DISCO="/mnt/usb1"
BACKUP_DIR="${DISCO}/bakup_proxmox"
DIR_ACTUAL="${BACKUP_DIR}/backup_actual"
DIR_ANTERIOR="${BACKUP_DIR}/backup_anterior"
DIR_DUMP="${BACKUP_DIR}/dump"

VM_101_IP="192.168.31.131"
VM_101_USER="antonio"
DUMPS_SCRIPT="/mnt/datos/hogarOS/Politica_backup/backup_dumps.sh"

VMS="101 102"
VZDUMP_DIR="/var/lib/vz/dump"

FECHA=$(date '+%Y-%m-%d %H:%M:%S')
FECHA_CORTA=$(date '+%Y_%m_%d')
ERRORES=0
RESUMEN=""

# --- Funciones ---------------------------------------------------------------

log() {
    echo "[$(date '+%H:%M:%S')] $1"
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

# --- 1. Verificar disco externo ----------------------------------------------

log "=========================================="
log "Inicio de backup — $FECHA"
log "=========================================="

log "Verificando disco externo en $DISCO..."
if ! mountpoint -q "$DISCO"; then
    log "ERROR: $DISCO no está montado."
    log "Monta el disco primero: mount /dev/sdb1 /mnt/usb1"
    exit 1
fi
log "  → Disco montado correctamente"

# Crear estructura si no existe
mkdir -p "$DIR_ACTUAL" "$DIR_DUMP"

# --- 2. Rotación --------------------------------------------------------------

log "Rotación de backups..."
if [ -d "$DIR_ANTERIOR" ]; then
    log "  → Eliminando backup anterior..."
    rm -rf "$DIR_ANTERIOR"
fi
if [ -d "$DIR_ACTUAL" ] && [ "$(ls -A "$DIR_ACTUAL" 2>/dev/null)" ]; then
    log "  → Moviendo backup actual → anterior..."
    mv "$DIR_ACTUAL" "$DIR_ANTERIOR"
    mkdir -p "$DIR_ACTUAL"
    log "  → Rotación completada"
else
    log "  → No hay backup actual previo, saltando rotación"
fi

# --- 3. Dumps de BDs (SSH a VM 101) ------------------------------------------

log "Ejecutando dumps de BDs en VM 101..."
ssh "${VM_101_USER}@${VM_101_IP}" "bash ${DUMPS_SCRIPT}" && {
    registrar "Dumps BDs (VM 101)" 0
    log "  → Dumps completados"
} || {
    # Se ejecuta como antonio — algunos dumps pueden fallar por permisos (warning, no error)
    RESUMEN="${RESUMEN}  Dumps BDs (VM 101): WARNING (permisos)\n"
    log "  → AVISO: algunos dumps fallaron por permisos (ver log en VM 101)"
}

# --- 4. Copiar dumps de VMs (generados por el vzdump semanal de Proxmox) -----

log "Copiando dumps de VMs desde $VZDUMP_DIR..."

# Limpiar dumps anteriores del disco externo
rm -f "${DIR_DUMP}"/*.vma.zst "${DIR_DUMP}"/*.log "${DIR_DUMP}"/*.notes 2>/dev/null

for VMID in $VMS; do
    # Buscar el dump más reciente de esta VM
    FICHERO=$(ls -t "${VZDUMP_DIR}"/vzdump-qemu-${VMID}-*.vma.zst 2>/dev/null | head -1)
    if [ -n "$FICHERO" ]; then
        TAMANO=$(du -h "$FICHERO" | cut -f1)
        log "  → VM $VMID: $(basename "$FICHERO") ($TAMANO)"
        cp "$FICHERO" "$DIR_DUMP/" && {
            # Copiar también el .log y .notes si existen
            cp "${FICHERO%.vma.zst}.log" "$DIR_DUMP/" 2>/dev/null || true
            cp "${FICHERO}.notes" "$DIR_DUMP/" 2>/dev/null || true
            registrar "Copia VM $VMID" 0
            log "  → Copiada correctamente"
        } || {
            registrar "Copia VM $VMID" 1
            log "  → ERROR copiando VM $VMID"
        }
    else
        log "  → AVISO: no se encontró dump de VM $VMID en $VZDUMP_DIR"
        registrar "Copia VM $VMID" 1
    fi
done

# --- 5. rsync de /mnt/datos/ -------------------------------------------------

log "Copiando /mnt/datos/ desde VM 101..."
mkdir -p "${DIR_ACTUAL}/datos"
rsync -av --delete \
    "${VM_101_USER}@${VM_101_IP}:/mnt/datos/" \
    "${DIR_ACTUAL}/datos/"
RSYNC_EXIT=$?
if [ "$RSYNC_EXIT" -eq 0 ]; then
    registrar "rsync /mnt/datos/" 0
    log "  → Copia de datos completada"
elif [ "$RSYNC_EXIT" -eq 23 ]; then
    # Code 23 = algunos ficheros no se pudieron copiar (permisos) — warning, no error
    RESUMEN="${RESUMEN}  rsync /mnt/datos/: WARNING (algunos ficheros sin permisos)\n"
    log "  → Copia completada con avisos (algunos ficheros sin permisos de lectura)"
else
    registrar "rsync /mnt/datos/" 1
    log "  → ERROR copiando /mnt/datos/ (rsync exit code: $RSYNC_EXIT)"
fi

# --- 6. Generar MANIFIESTO.txt -----------------------------------------------

log "Generando manifiesto..."

MANIFIESTO="${DIR_ACTUAL}/MANIFIESTO.txt"

{
    echo "=========================================="
    echo "MANIFIESTO DE BACKUP"
    echo "Fecha: $FECHA"
    echo "=========================================="
    echo ""

    # Tamaño de los dumps de VMs
    for VMID in $VMS; do
        FICHERO=$(ls -t "${DIR_DUMP}"/vzdump-qemu-${VMID}-*.vma.zst 2>/dev/null | head -1)
        if [ -n "$FICHERO" ]; then
            TAMANO=$(du -h "$FICHERO" | cut -f1)
            echo "VM $VMID: $(basename "$FICHERO") ($TAMANO) ✅"
        else
            echo "VM $VMID: NO ENCONTRADO ❌"
        fi
    done

    echo ""

    # Tamaño de datos copiados
    if [ -d "${DIR_ACTUAL}/datos" ]; then
        TAMANO_DATOS=$(du -sh "${DIR_ACTUAL}/datos" | cut -f1)
        echo "Datos /mnt/datos/: $TAMANO_DATOS copiados ✅"
    else
        echo "Datos /mnt/datos/: NO COPIADOS ❌"
    fi

    echo ""

    # Estado de dumps de BDs
    echo "Dumps de bases de datos:"
    for F in fido/fido.db.bak redo/redo.db.bak planka/planka_dump.sql mariadb/nextcloud_dump.sql; do
        RUTA="${DIR_ACTUAL}/datos/${F}"
        NOMBRE=$(basename "$F")
        if [ -f "$RUTA" ]; then
            TAMANO=$(du -h "$RUTA" | cut -f1)
            echo "  $NOMBRE ($TAMANO) ✅"
        else
            echo "  $NOMBRE: NO ENCONTRADO ❌"
        fi
    done

    echo ""

    # Backup anterior
    if [ -d "$DIR_ANTERIOR" ] && [ -f "${DIR_ANTERIOR}/MANIFIESTO.txt" ]; then
        FECHA_ANT=$(grep "^Fecha:" "${DIR_ANTERIOR}/MANIFIESTO.txt" | head -1)
        echo "Backup anterior: $FECHA_ANT"
    else
        echo "Backup anterior: no disponible"
    fi

    echo ""
    echo "Errores totales: $ERRORES"
    echo "=========================================="
} > "$MANIFIESTO"

log "  → Manifiesto generado en $MANIFIESTO"

# --- 7. Resumen final --------------------------------------------------------

echo ""
log "=========================================="
log "RESUMEN DEL BACKUP"
log "=========================================="
echo -e "$RESUMEN"
cat "$MANIFIESTO"
echo ""

if [ "$ERRORES" -eq 0 ]; then
    log "✅ BACKUP COMPLETADO SIN ERRORES"
else
    log "⚠️  BACKUP COMPLETADO CON $ERRORES ERROR(ES)"
fi

log ""
log "Puedes desmontar el disco con: umount /mnt/usb1"
log "=========================================="

exit $ERRORES
