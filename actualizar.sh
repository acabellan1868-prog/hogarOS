#!/bin/bash

# actualizar.sh — Actualiza hogarOS y todas sus apps desde GitHub
#
# Qué hace:
#   1. Descarga los últimos cambios de GitHub (git pull) en los 3 repos
#   2. Para todos los contenedores
#   3. Reconstruye las imágenes (por si cambió código de ReDo o FiDo)
#   4. Levanta todo de nuevo
#
# Uso: ./actualizar.sh
# Ejecutar desde cualquier sitio — las rutas son absolutas.

set -e

DIRECTORIO_BASE="/mnt/datos"
PROYECTOS=("hogarOS" "redo-build" "fido-build" "medido-build")

echo "================================================"
echo "  hogarOS — Actualizando ecosistema"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================"

# ── Paso 1: Descargar cambios de GitHub ──
echo ""
echo "── Paso 1/4: Descargando cambios de GitHub ──"

for proyecto in "${PROYECTOS[@]}"; do
  ruta="$DIRECTORIO_BASE/$proyecto"

  if [ -d "$ruta/.git" ]; then
    echo ""
    echo "  ► $proyecto"
    cd "$ruta"
    rama_actual=$(git branch --show-current)
    git pull origin "$rama_actual" 2>&1 | sed 's/^/    /'
  else
    echo ""
    echo "  ⚠ $proyecto — no encontrado en $ruta"
  fi
done

# ── Paso 2: Parar contenedores ──
echo ""
echo "── Paso 2/4: Parando contenedores ──"
cd "$DIRECTORIO_BASE/hogarOS"
docker compose down 2>&1 | sed 's/^/    /'

# ── Paso 3: Reconstruir imágenes ──
echo ""
echo "── Paso 3/4: Reconstruyendo imágenes ──"
docker compose build 2>&1 | sed 's/^/    /'

# ── Paso 4: Levantar contenedores ──
echo ""
echo "── Paso 4/4: Levantando contenedores ──"
docker compose up -d 2>&1 | sed 's/^/    /'

# ── Resultado ──
echo ""
echo "================================================"
echo "  ✓ Actualización completada"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================"
echo ""
docker compose ps
