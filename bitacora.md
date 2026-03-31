# Bitácora — hogarOS

## 2026-03-31

### Centro de Alertas unificado (Fase 12)

Problema detectado: las alertas de cada app (ReDo, MediDo) estaban aisladas.
ReDo las guardaba en BD pero no las mostraba. MediDo tenía su propio tab.
Para verlas había que ir a la app NTFY del móvil. Sin gestión posible.

Se investigó si NTFY podía servir como fuente central, pero su API no permite
eliminar, marcar como leída ni consultar histórico persistente. Solo caché de
unas pocas horas. Conclusión: NTFY sigue como "timbre", la gestión vive en las BDs.

Se evaluaron tres opciones (A: agregador, B: hub central, A+: híbrida).
Se eligió la **Opción A** (agregación desde el portal) para no duplicar datos
y mantener cada app como fuente de verdad de sus alertas.

**Cambios realizados:**

**ReDo** (`app/rutas/alertas.py` nuevo):
- Migración: campo `resuelta` en tabla `alertas`
- 3 endpoints: `GET /api/alertas`, `POST /api/alertas/{id}/resolver`, `DELETE /api/alertas/{id}`
- Respuesta incluye `modulo: "redo"` para el contrato estándar

**MediDo** (`app/rutas/alertas.py` modificado):
- Campo `modulo: "medido"` en la respuesta de `GET /api/alertas`
- Nuevo endpoint `DELETE /api/alertas/{id}`

**Portal** (`portal/index.html`):
- Sustituida sección "Alertas recientes" (solo memoria JS) por Centro de Alertas real
- Consulta `GET /red/api/alertas` y `GET /salud/api/alertas` cada 60 segundos
- Agrega, ordena (activas primero + fecha desc) y renderiza lista unificada
- Filtros por estado (todas/activas/resueltas) y por módulo (todos/ReDo/MediDo)
- Botones Resolver y Eliminar que llaman al API de cada app via proxy
- Etiqueta visual por módulo con colores del design system
- Si una app no responde, muestra aviso sin bloquear las demás

**Documentación:** `analisis-mejoras.md` sección 3, `roadmap.md` Fase 12.

## 2026-03-28

### Correcciones en scripts de backup

Detectados y corregidos tres errores tras ejecutar el backup completo:
- `rsync`: añadido `--no-owner --no-group` (disco USB en FAT32/exFAT no soporta propietarios Unix)
- `rsync`: excluido directorio `dockmon` (no legible por antonio)
- `backup_dumps.sh`: cambiado `--all-databases` por `nextcloud` en mariadb-dump (fallo de permisos en tablas del sistema)

Añadido script `montar_disco.sh` para detección y montaje automático del USB,
con verificación de que es el disco de backups correcto.

El MANIFIESTO ahora captura el detalle completo de errores de cada paso.

### Tarjeta MediDo en el portal

Añadida tarjeta "Salud del Sistema" al grid bento del portal. Consume
`/salud/api/resumen` y muestra semáforo de estado global (ok/warning/danger),
barras de CPU/RAM/disco del host Proxmox, conteo de contenedores y servicios,
y alertas activas. El grid bento pasa de 4 a 5 tarjetas (distribución 7+5 / 4+5+3).
Refresco automático cada 60 segundos junto al resto de datos operacionales.

## 2026-03-27

### Despliegue de MediDo en el ecosistema

Se añadió MediDo como nuevo módulo de monitorización del ecosistema hogarOS.
Integrado en el portal via proxy Nginx en `/salud/`.

### Reorganización de documentación

Se adoptó la estructura de documentación estándar del ecosistema:
- `ROADMAP.md` renombrado a `roadmap.md`
- `mejoras.md` renombrado a `analisis-mejoras.md`
- `Politica_backup/ROADMAP.md` renombrado a `Politica_backup/roadmap.md`
- Creada `bitacora.md` (este fichero)
