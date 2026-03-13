#!/bin/bash

# actualizar.sh — Actualiza todos los proyectos de hogarOS desde GitHub
# Uso: ./actualizar.sh [--reiniciar]
#
# Sin argumentos: solo hace pull de los repos
# Con --reiniciar: hace pull y reinicia los contenedores Docker

set -e

DIRECTORIO_BASE="$(cd "$(dirname "$0")/.." && pwd)"
PROYECTOS=("hogarOS" "netsentinel" "FiDo")
REINICIAR=false

if [[ "$1" == "--reiniciar" ]]; then
  REINICIAR=true
fi

echo "================================================"
echo "  hogarOS — Actualizando proyectos"
echo "  Base: $DIRECTORIO_BASE"
echo "================================================"

for proyecto in "${PROYECTOS[@]}"; do
  ruta="$DIRECTORIO_BASE/$proyecto"

  if [ -d "$ruta/.git" ]; then
    echo ""
    echo "► $proyecto"
    cd "$ruta"
    rama_actual=$(git branch --show-current)
    git pull origin "$rama_actual"
  else
    echo ""
    echo "⚠ $proyecto — directorio no encontrado o no es un repo git: $ruta"
  fi
done

echo ""
echo "================================================"
echo "  Pull completado"
echo "================================================"

if [ "$REINICIAR" = true ]; then
  echo ""
  echo "► Reiniciando contenedores Docker..."
  cd "$DIRECTORIO_BASE/hogarOS"
  docker compose restart
  echo "  Contenedores reiniciados."
fi

echo ""
echo "✓ Listo"
