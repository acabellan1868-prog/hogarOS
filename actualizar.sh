#!/bin/bash

# actualizar.sh — Actualiza hogarOS y todas sus apps desde GitHub
#
# Qué hace:
#   1. Descarga los últimos cambios de GitHub (git pull) en los repos
#   2. Solo para los repos con cambios: para, reconstruye y levanta sus contenedores
#   3. Los repos sin cambios no se tocan — sin interrupción de servicio
#
# Uso: ./actualizar.sh
# Ejecutar desde cualquier sitio — las rutas son absolutas.

set -e

DIRECTORIO_BASE="/mnt/datos"
COMPOSE_DIR="$DIRECTORIO_BASE/hogarOS"

# Mapeo repo → servicios docker-compose (separados por espacio si hay varios)
declare -A SERVICIOS
SERVICIOS["hogarOS"]="nginx hogar-api"
SERVICIOS["redo-build"]="redo"
SERVICIOS["fido-build"]="fido"
SERVICIOS["medido-build"]="medido"
SERVICIOS["kryptonite-build"]="kryptonite"

PROYECTOS=("hogarOS" "redo-build" "fido-build" "medido-build" "kryptonite-build")

echo "================================================"
echo "  hogarOS — Actualizando ecosistema"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================"

# ── Paso 1: Descargar cambios y detectar qué repos cambiaron ──
echo ""
echo "── Paso 1/2: Descargando cambios de GitHub ──"

declare -A TIENE_CAMBIOS

for proyecto in "${PROYECTOS[@]}"; do
  ruta="$DIRECTORIO_BASE/$proyecto"

  if [ ! -d "$ruta/.git" ]; then
    echo ""
    echo "  ⚠ $proyecto — no encontrado en $ruta"
    TIENE_CAMBIOS[$proyecto]=0
    continue
  fi

  echo ""
  echo "  ► $proyecto"
  cd "$ruta"
  rama_actual=$(git branch --show-current)
  salida=$(git pull origin "$rama_actual" 2>&1)
  echo "$salida" | sed 's/^/    /'

  if echo "$salida" | grep -q "Already up to date."; then
    TIENE_CAMBIOS[$proyecto]=0
  else
    TIENE_CAMBIOS[$proyecto]=1
  fi
done

# ── Paso 2: Reconstruir y reiniciar solo los servicios con cambios ──
echo ""
echo "── Paso 2/2: Actualizando servicios con cambios ──"

alguno_actualizado=0

for proyecto in "${PROYECTOS[@]}"; do
  if [ "${TIENE_CAMBIOS[$proyecto]}" -eq 0 ]; then
    echo ""
    echo "  ✓ $proyecto — sin cambios, no se reinicia"
    continue
  fi

  servicios="${SERVICIOS[$proyecto]}"
  echo ""
  echo "  ► $proyecto — reconstruyendo: $servicios"

  cd "$COMPOSE_DIR"

  for servicio in $servicios; do
    echo "    Parando $servicio..."
    docker compose stop "$servicio" 2>&1 | sed 's/^/    /'
    echo "    Reconstruyendo $servicio..."
    docker compose build "$servicio" 2>&1 | sed 's/^/    /'
    echo "    Levantando $servicio..."
    docker compose up -d "$servicio" 2>&1 | sed 's/^/    /'
  done

  alguno_actualizado=1
done

# ── Resultado ──
echo ""
echo "================================================"
if [ "$alguno_actualizado" -eq 0 ]; then
  echo "  ✓ Todo estaba al día — ningún servicio reiniciado"
else
  echo "  ✓ Actualización completada"
fi
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================"
echo ""
cd "$COMPOSE_DIR"
docker compose ps
