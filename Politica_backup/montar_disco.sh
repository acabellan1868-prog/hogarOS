#!/bin/bash
# =============================================================================
# montar_disco.sh — Detecta y monta automáticamente el disco externo USB
#
# Uso: bash /ruta/montar_disco.sh
#
# Busca particiones de discos USB (hotplug) que no estén montadas y las
# monta en /mnt/usb1. Si hay más de una, muestra una lista para elegir.
# Tras montar, verifica que el disco contiene la carpeta de backups esperada.
# =============================================================================

PUNTO_MONTAJE="/mnt/usb1"
CARPETA_BACKUP="bakup_proxmox"   # creada por backup.sh en el disco externo

echo "=========================================="
echo "Detección de disco externo USB"
echo "=========================================="

# Buscar particiones de discos hotplug (USB) no montadas
mapfile -t CANDIDATOS < <(lsblk -rno NAME,TYPE,HOTPLUG,MOUNTPOINT | awk '$2=="part" && $3=="1" && $4=="" {print "/dev/"$1}')

# --- Sin candidatos -----------------------------------------------------------

if [ ${#CANDIDATOS[@]} -eq 0 ]; then
    echo ""
    echo "❌ No se encontró ningún disco USB sin montar."
    echo ""
    echo "Discos conectados actualmente:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,HOTPLUG,VENDOR
    exit 1
fi

# --- Un solo candidato: montar directamente -----------------------------------

if [ ${#CANDIDATOS[@]} -eq 1 ]; then
    DISPOSITIVO="${CANDIDATOS[0]}"
    echo ""
    echo "Dispositivo encontrado: $DISPOSITIVO"
    INFO=$(lsblk -rno SIZE,VENDOR,LABEL "$DISPOSITIVO" 2>/dev/null | head -1)
    echo "Info: $INFO"
fi

# --- Varios candidatos: elegir ------------------------------------------------

if [ ${#CANDIDATOS[@]} -gt 1 ]; then
    echo ""
    echo "Se encontraron varios discos USB sin montar:"
    echo ""
    for i in "${!CANDIDATOS[@]}"; do
        INFO=$(lsblk -rno SIZE,VENDOR,LABEL "${CANDIDATOS[$i]}" 2>/dev/null | head -1)
        echo "  [$((i+1))] ${CANDIDATOS[$i]}  $INFO"
    done
    echo ""
    read -r -p "Elige el número del disco a montar: " ELECCION
    INDICE=$((ELECCION - 1))
    if [ -z "${CANDIDATOS[$INDICE]+x}" ]; then
        echo "❌ Opción no válida."
        exit 1
    fi
    DISPOSITIVO="${CANDIDATOS[$INDICE]}"
fi

# --- Montar -------------------------------------------------------------------

mkdir -p "$PUNTO_MONTAJE"

echo ""
echo "Montando $DISPOSITIVO en $PUNTO_MONTAJE..."
if ! mount "$DISPOSITIVO" "$PUNTO_MONTAJE"; then
    echo ""
    echo "❌ Error al montar $DISPOSITIVO"
    echo "   Prueba a identificar el sistema de ficheros con: blkid $DISPOSITIVO"
    exit 1
fi

# --- Confirmar montaje --------------------------------------------------------

if ! mountpoint -q "$PUNTO_MONTAJE"; then
    echo "❌ El montaje falló por razón desconocida."
    exit 1
fi

echo ""
echo "✅ Disco montado correctamente en $PUNTO_MONTAJE"
echo ""
df -h "$PUNTO_MONTAJE"

# --- Verificar que es el disco de backups -------------------------------------

echo ""
echo "Verificando que es el disco de backups..."

if [ -d "${PUNTO_MONTAJE}/${CARPETA_BACKUP}" ]; then
    # Carpeta de backups encontrada — mostrar info del último backup
    MANIFIESTO="${PUNTO_MONTAJE}/${CARPETA_BACKUP}/backup_actual/MANIFIESTO.txt"
    if [ -f "$MANIFIESTO" ]; then
        FECHA_ULT=$(grep "^Fecha:" "$MANIFIESTO" | head -1 | cut -d' ' -f2-)
        echo "✅ Disco de backups reconocido."
        echo "   Último backup: $FECHA_ULT"
    else
        echo "✅ Disco de backups reconocido (aún sin backup registrado)."
    fi
else
    # Carpeta no encontrada — puede ser primer uso o disco equivocado
    echo ""
    echo "⚠️  AVISO: no se encontró la carpeta '${CARPETA_BACKUP}/' en el disco."
    echo "   Puede ser la primera vez que se usa este disco,"
    echo "   o puede ser un disco incorrecto."
    echo ""
    echo "Contenido raíz del disco:"
    ls -lh "$PUNTO_MONTAJE" 2>/dev/null || echo "  (vacío)"
    echo ""
    read -r -p "¿Continuar igualmente? [s/N]: " CONFIRMACION
    if [[ ! "$CONFIRMACION" =~ ^[sS]$ ]]; then
        echo ""
        echo "Desmontando disco..."
        umount "$PUNTO_MONTAJE"
        echo "Disco desmontado. Conecta el disco correcto y vuelve a intentarlo."
        exit 1
    fi
    echo "Continuando. backup.sh creará la carpeta '${CARPETA_BACKUP}/' en el primer uso."
fi

echo ""
echo "Cuando termines el backup, desmonta con:"
echo "  umount $PUNTO_MONTAJE"
