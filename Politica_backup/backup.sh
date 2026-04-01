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
#   6. Generar MANIFIESTO.txt con resumen + detalle de errores
#   7. Mostrar resumen por pantalla
#
# Logs generados en backup_actual/:
#   dumps.log   → salida completa del script de dumps de BDs
#   rsync.log   → salida completa del rsync de /mnt/datos/
#   vms.log     → errores al copiar dumps de VMs
#   MANIFIESTO.txt → resumen ejecutivo + detalle de todos los errores
# =============================================================================

set -uo pipefail

# --- Configuración -----------------------------------------------------------

NTFY_TOPIC="hogaros-3ca6f61b"
NTFY_URL="https://ntfy.sh/${NTFY_TOPIC}"

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
ERRORES=0
RESUMEN=""

# --- Funciones ---------------------------------------------------------------

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# Registra resultado de un paso en el resumen
registrar() {
    # $1 = descripción, $2 = código de salida
    if [ "$2" -eq 0 ]; then
        RESUMEN="${RESUMEN}  ✅ $1\n"
    else
        RESUMEN="${RESUMEN}  ❌ $1\n"
        ERRORES=$((ERRORES + 1))
    fi
}

# Registra un aviso (no cuenta como error)
registrar_aviso() {
    RESUMEN="${RESUMEN}  ⚠️  $1\n"
}

# Extrae líneas de error de un log y las imprime con título
errores_de_log() {
    local fichero="$1"
    local titulo="$2"
    if [ ! -f "$fichero" ] || [ ! -s "$fichero" ]; then
        return
    fi
    local lineas
    lineas=$(grep -niE "error|failed|permission denied|cannot open|no such file|rsync:|bash:" "$fichero" 2>/dev/null || true)
    if [ -n "$lineas" ]; then
        echo ""
        echo "  ── $titulo ──"
        echo "$lineas" | head -100 | sed 's/^/    /'
    fi
}

# --- 1. Verificar disco externo ----------------------------------------------

log "=========================================="
log "Inicio de backup — $FECHA"
log "=========================================="

log "Verificando disco externo en $DISCO..."
if ! mountpoint -q "$DISCO"; then
    log "ERROR: $DISCO no está montado."
    log "Monta el disco primero con: bash /root/montar_disco.sh"
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

# Definir y crear ficheros de log (siempre tras la rotación)
LOG_DUMPS="${DIR_ACTUAL}/dumps.log"
LOG_RSYNC="${DIR_ACTUAL}/rsync.log"
LOG_VMS="${DIR_ACTUAL}/vms.log"
> "$LOG_DUMPS"
> "$LOG_RSYNC"
> "$LOG_VMS"

# --- 3. Dumps de BDs (SSH a VM 101) ------------------------------------------

log "Ejecutando dumps de BDs en VM 101..."
log "  (salida completa → $LOG_DUMPS)"

ssh "${VM_101_USER}@${VM_101_IP}" "bash ${DUMPS_SCRIPT}" 2>&1 | tee "$LOG_DUMPS"
DUMPS_EXIT="${PIPESTATUS[0]}"

if [ "$DUMPS_EXIT" -eq 0 ]; then
    registrar "Dumps BDs (VM 101)" 0
    log "  → Dumps completados"
else
    registrar_aviso "Dumps BDs (VM 101): algunos dumps fallaron por permisos"
    log "  → AVISO: algunos dumps fallaron. Ver $LOG_DUMPS"
fi

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
        if cp "$FICHERO" "$DIR_DUMP/" 2>>"$LOG_VMS"; then
            cp "${FICHERO%.vma.zst}.log" "$DIR_DUMP/" 2>/dev/null || true
            cp "${FICHERO}.notes" "$DIR_DUMP/" 2>/dev/null || true
            registrar "Copia VM $VMID" 0
            log "  → Copiada correctamente"
        else
            registrar "Copia VM $VMID" 1
            log "  → ERROR copiando VM $VMID. Ver $LOG_VMS"
        fi
    else
        echo "VM $VMID: dump no encontrado en $VZDUMP_DIR" >> "$LOG_VMS"
        registrar "Copia VM $VMID" 1
        log "  → AVISO: no se encontró dump de VM $VMID en $VZDUMP_DIR"
    fi
done

# --- 5. rsync de /mnt/datos/ -------------------------------------------------

log "Copiando /mnt/datos/ desde VM 101..."
log "  (salida completa → $LOG_RSYNC)"
mkdir -p "${DIR_ACTUAL}/datos"

rsync -av --delete \
    --no-owner --no-group \
    --exclude=dockmon \
    "${VM_101_USER}@${VM_101_IP}:/mnt/datos/" \
    "${DIR_ACTUAL}/datos/" \
    2>&1 | tee "$LOG_RSYNC"
RSYNC_EXIT="${PIPESTATUS[0]}"

if [ "$RSYNC_EXIT" -eq 0 ]; then
    registrar "rsync /mnt/datos/" 0
    log "  → Copia de datos completada"
elif [ "$RSYNC_EXIT" -eq 23 ]; then
    # Código 23 = algunos ficheros no copiados por permisos — aviso, no error
    registrar_aviso "rsync /mnt/datos/: completado con avisos de permisos"
    log "  → Copia completada con avisos de permisos. Ver $LOG_RSYNC"
else
    registrar "rsync /mnt/datos/ (exit code: $RSYNC_EXIT)" 1
    log "  → ERROR en rsync. Ver $LOG_RSYNC"
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

    # --- Resumen por pasos ---
    echo "RESUMEN:"
    echo -e "$RESUMEN"

    # --- Dumps de VMs ---
    echo "DUMPS DE VMs:"
    for VMID in $VMS; do
        FICHERO=$(ls -t "${DIR_DUMP}"/vzdump-qemu-${VMID}-*.vma.zst 2>/dev/null | head -1)
        if [ -n "$FICHERO" ]; then
            TAMANO=$(du -h "$FICHERO" | cut -f1)
            echo "  VM $VMID: $(basename "$FICHERO") ($TAMANO) ✅"
        else
            echo "  VM $VMID: NO ENCONTRADO ❌"
        fi
    done

    echo ""

    # --- Datos copiados ---
    echo "DATOS COPIADOS:"
    if [ -d "${DIR_ACTUAL}/datos" ]; then
        TAMANO_DATOS=$(du -sh "${DIR_ACTUAL}/datos" | cut -f1)
        echo "  /mnt/datos/: $TAMANO_DATOS ✅"
    else
        echo "  /mnt/datos/: NO COPIADO ❌"
    fi

    echo ""

    # --- Estado de cada BD ---
    echo "BASES DE DATOS:"
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

    # --- Backup anterior ---
    if [ -d "$DIR_ANTERIOR" ] && [ -f "${DIR_ANTERIOR}/MANIFIESTO.txt" ]; then
        FECHA_ANT=$(grep "^Fecha:" "${DIR_ANTERIOR}/MANIFIESTO.txt" | head -1 | cut -d' ' -f2-)
        echo "Backup anterior: $FECHA_ANT"
    else
        echo "Backup anterior: no disponible"
    fi

    echo ""
    echo "Logs de detalle:"
    echo "  $LOG_DUMPS  (dumps de BDs)"
    echo "  $LOG_RSYNC  (rsync /mnt/datos/)"
    echo "  $LOG_VMS    (copia de VMs)"

    echo ""
    echo "=========================================="
    echo "DETALLE DE ERRORES"
    echo "=========================================="

    # Errores extraídos de cada log
    HAY_ERRORES=0
    for LOG_FICHERO in "$LOG_DUMPS" "$LOG_RSYNC" "$LOG_VMS"; do
        TITULO=""
        [ "$LOG_FICHERO" = "$LOG_DUMPS" ] && TITULO="dumps de BDs (dumps.log)"
        [ "$LOG_FICHERO" = "$LOG_RSYNC" ] && TITULO="rsync /mnt/datos/ (rsync.log)"
        [ "$LOG_FICHERO" = "$LOG_VMS"   ] && TITULO="copia de VMs (vms.log)"
        if [ -f "$LOG_FICHERO" ] && grep -qiE "error|failed|permission denied|cannot open|no such file|rsync:|bash:" "$LOG_FICHERO" 2>/dev/null; then
            HAY_ERRORES=1
            errores_de_log "$LOG_FICHERO" "$TITULO"
        fi
    done

    if [ "$HAY_ERRORES" -eq 0 ]; then
        echo ""
        echo "  Sin errores detectados en los logs."
    fi

    echo ""
    echo "=========================================="
    echo "Errores totales: $ERRORES"
    echo "=========================================="
} > "$MANIFIESTO"

log "  → Manifiesto generado: $MANIFIESTO"

# --- 7. Resumen final --------------------------------------------------------

echo ""
log "=========================================="
log "RESUMEN DEL BACKUP"
log "=========================================="
echo -e "$RESUMEN"

if [ "$ERRORES" -eq 0 ]; then
    log "✅ BACKUP COMPLETADO SIN ERRORES"
else
    log "⚠️  BACKUP COMPLETADO CON $ERRORES ERROR(ES)"
fi

log ""
log "Ver detalle completo: cat $MANIFIESTO"
log "Puedes desmontar el disco con: umount $DISCO"
log "=========================================="

# --- 8. Notificación NTFY ----------------------------------------------------

log "Enviando notificación NTFY..."

if [ "$ERRORES" -eq 0 ]; then
    NTFY_TITULO="Backup completado sin errores"
    NTFY_PRIORIDAD="default"
    NTFY_TAGS="white_check_mark,floppy_disk"
else
    NTFY_TITULO="Backup completado con ${ERRORES} error(es)"
    NTFY_PRIORIDAD="high"
    NTFY_TAGS="warning,floppy_disk"
fi

NTFY_CUERPO="Fecha: ${FECHA}
$(echo -e "$RESUMEN")"

curl -s \
    -H "Title: ${NTFY_TITULO}" \
    -H "Priority: ${NTFY_PRIORIDAD}" \
    -H "Tags: ${NTFY_TAGS}" \
    -d "${NTFY_CUERPO}" \
    "${NTFY_URL}" > /dev/null 2>&1 && {
    log "  → Notificación enviada a NTFY"
} || {
    log "  → AVISO: no se pudo enviar notificación NTFY"
}

exit $ERRORES
