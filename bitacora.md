# Bitácora — hogarOS

## 2026-04-02 (tarde)

### Fase 13a: Hook verificado e instalación de Python

**Problema:** El hook "Stop" no se ejecutaba porque `python` no estaba disponible en Windows.
Se intentó con bash (dentro de Git Bash/WSL) pero los alias de Microsoft Store interferían.

**Solución:**
1. Instalación: Python 3.14.3 desde Microsoft Store (ejecutando `python` en PowerShell)
2. Cambio del hook: `python` → `py` (lanzador estándar de Python en Windows que no tiene conflictos)
3. Test manual: Script probado con JSON de prueba, creación de `cola_sync.jsonl` verificada

**Cambios en `~/.claude/settings.json`:**
```json
"command": "py C:\\Users\\familiaAlvarezBascon\\.claude\\claude-tracker.py"
```

**Verificación:**
- Hook funciona: ejecutado manualmente con `py claude-tracker.py` → cola creada correctamente
- Estructura correcta: session_id, tokens, costes (input/output/cache), sincronizado: false
- Listo para próxima sesión: al cerrar sesión de Claude Code, hook capturará datos reales

---

## 2026-04-02 (tarde anterior)

### Fase 13a: Hook de Claude Code implementado

Se implementó el sistema de tracking de sesiones de Claude Code. El objetivo es capturar
tokens y coste de cada sesión para mostrar en una tarjeta del portal (Fase 13).

**Limitaciones y alcance:**
- Solo captura Claude Code (CLI). Claude Chat web no tiene hooks accesibles.
- Las APIs oficiales de Anthropic requieren Admin API key (solo organizaciones), no aplica a Pro/Max.
- Solución: hooks locales de Claude Code + envío a MediDo.

**Arquitectura offline-first:**
```
Claude Code termina sesión (cualquier equipo)
  └─ Hook "Stop" ejecuta claude-tracker.py
      ├─ Guarda en cola local: ~/.claude/cola_sync.jsonl (siempre funciona)
      ├─ Intenta POST a MediDo (http://192.168.31.131/salud/api/claude/sesion)
      └─ Si falla → reintenta entradas pendientes al volver a red
```

**Cambios realizados:**

**Script local** (`~/.claude/claude-tracker.py`):
- Recibe JSON del hook por stdin (session_id, input/output/cache tokens)
- Calcula coste en USD según precios Sonnet 4.6:
  - Input: $3.0/Mtok, Output: $15.0/Mtok
  - Cache read: $0.30/Mtok, Cache creation: $3.75/Mtok
- Guarda en cola JSONL con estructura completa
- Intenta POST a MediDo; si falla, queda en cola para sincronizar después
- Si POST OK → reintenta entradas pendientes (sincronización retroactiva)

**Hook configurado** (`~/.claude/settings.json`):
- Sección `hooks.Stop[]` con comando: `python ~/.claude/claude-tracker.py`
- Se dispara al terminar cualquier sesión de Claude Code

**Estructura de datos guardada:**
```json
{
  "session_id": "abc123",
  "fecha_fin": "2026-04-02T15:30:45.123456+00:00",
  "directorio": "C:\\...",
  "proyecto": "Desarrollo",
  "input_tokens": 15420,
  "output_tokens": 3210,
  "cache_read_tokens": 8500,
  "cache_creation_tokens": 2100,
  "coste_input_usd": 0.04626,
  "coste_output_usd": 0.04815,
  "coste_cache_usd": 0.00825,
  "sincronizado": false
}
```

**Próxima fase (13b):** Crear tabla `claude_sesiones` en MediDo e implementar
endpoints POST (recibir del hook) y GET (exponer resumen para el portal).

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
