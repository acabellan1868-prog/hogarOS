# Bitácora — hogarOS

## 2026-04-25

### Portada — tesela de Finanzas Domésticas filtrada

La tesela de Finanzas Domésticas del portal deja de consumir el resumen global de FiDo
y pasa a pedir `GET /finanzas/api/resumen?cuenta_nombre=Cuenta%20Antonio&banco=caixa`.

Motivo: el resumen global suma movimientos de todas las cuentas, incluyendo transferencias
entre cuentas propias, por lo que ingresos/gastos aparecen duplicados. De momento se usa
`Cuenta Antonio (Caixa)` como cuenta operativa principal para la lectura mensual.

Ficheros modificados: `portal/index.html`

---

## 2026-04-18

### Fase 13 completada — despliegue en VM 101

Ejecutado `actualizar.sh` en VM 101. Portal y MediDo desplegados con la tarjeta
"Asistente IA" funcionando. Fase 13d verificada en producción — todas las tareas manuales completadas.

---

## 2026-04-07

### Gestión de datos sensibles — convención .env para todo el ecosistema

Los repositorios del ecosistema son públicos en GitHub. Había valores sensibles
(topics NTFY, rango de red doméstica) escritos directamente en los
`docker-compose.yml`. Se establece una convención uniforme para todos los proyectos.

**Convención:**
- `.env` — valores reales, nunca en git (ya estaba en `.gitignore` en todos los proyectos)
- `.env.example` — plantilla pública con nombres de variables y descripciones, sin valores reales
- `docker-compose.yml` — usa `${VARIABLE}` para todos los valores sensibles

**Cambios en hogarOS:**
- `docker-compose.yml`: `NTFY_TOPIC=hogaros-3ca6f61b` → `${NTFY_TOPIC_ALERTAS}` (servicios redo y medido)
- `docker-compose.yml`: `REDO_NETWORK=192.168.31.0/24` → `${REDO_NETWORK}`
- `docker-compose.yml`: añadidas variables NTFY al servicio fido (`${NTFY_TOPIC_FIDO}`)
- `.env.example`: reescrito completamente con todas las variables del ecosistema y sin valores reales (el anterior tenía `PVE_HOST`, `PVE_NODE`, `PVE_TOKEN_ID` con valores reales)

**Nota sobre nomenclatura en hogarOS/.env:**
En el `.env` del orquestador los topics NTFY tienen nombres distintos para evitar
colisión entre los dos canales:
- `NTFY_TOPIC_FIDO` → topic de movimientos bancarios (solo FiDo)
- `NTFY_TOPIC_ALERTAS` → topic de alertas del sistema (ReDo y MediDo)

Cada servicio recibe la variable internamente como `NTFY_TOPIC` — sin cambios en el código.

**Aplicado también en:** FiDo, ReDo, MediDo (ver bitácoras respectivas)

---

### Listener NTFY en FiDo — captura automática de movimientos desde el móvil

Ver bitácora de FiDo (2026-04-06) para el detalle técnico completo.

El topic `fido-mov-ea3172c15373bf4a` es exclusivo para movimientos financieros,
separado del topic de alertas del ecosistema (`hogaros-3ca6f61b`).

---

## 2026-04-04

### Alertas: página propia + tarjeta compacta en portal

Se separa la gestión de alertas del portal principal.

**Nueva página `portal/alertas.html`:**
- Listado completo con filtros por estado (todas/activas/resueltas) y módulo (ReDo/MediDo)
- Botones resolver y eliminar por alerta
- Refresco automático cada 30 segundos
- Accesible desde el drawer y desde la tarjeta del portal

**Cambios en `portal/index.html`:**
- Eliminado el bloque "Centro de Alertas" (sección completa con listado)
- Nueva tarjeta compacta: nº activas (rojo/verde), nº resueltas, última alerta con mensaje y fecha
- Enlace "Gestionar alertas" → `/alertas.html`
- Drawer: nuevo enlace a Alertas
- Fila 2 del bento pasa a 4 tarjetas span 3: Salud + IA + Backup + Alertas

**Push:** Commit 4d16938 en acabellan1868-prog/hogarOS

---

### Fix tarjeta Asistente IA: sesiones y tokens incorrectos

El endpoint `/api/claude/resumen` de MediDo contaba filas individuales en lugar de sesiones únicas.

**Causa:** `COUNT(*)` contaba cada respuesta del hook como una sesión distinta. `SUM(tokens)` sumaba acumulados parciales en lugar del valor final por sesión.

**Fix en `MediDo/app/rutas/claude.py`:**
- La query de agregación ahora agrupa por `session_id` usando `MAX()` por campo (igual que `/sesiones`)
- `sesiones_totales` devuelve sesiones únicas reales
- Tokens y coste reflejan el valor final de cada sesión, sin duplicados

**Push:** Commit 78b9278 en acabellan1868-prog/MediDo

---

### Reorganización bento grid: 3 tarjetas por fila

Se reorganiza el layout del portal para distribuir las 6 tarjetas en 2 filas de 3.

**Cambios en portal/index.html:**
- Fila 1: Domótica(5) + Finanzas Domésticas(4) + Red Doméstica(3) = 12 columnas
- Fila 2: Salud del Sistema(4) + Asistente IA(4) + Estado Backup(4) = 12 columnas
- Antes: Domótica(7) + Finanzas(5) en fila 1, resto distribuido en filas 2 y 3

**Push:** Commit a89aade en acabellan1868-prog/hogarOS

---

## 2026-04-02 (noche II)

### Fase 13d: Limites de tokens en tarjeta Claude

Se actualiza tarjeta "Asistente IA" para mostrar limites de tokens con barras de progreso.

**Cambios en portal/index.html:**
- Función cargarClaude(): renderiza limites_tokens (últimas 5h y última semana)
- Nuevas barras: `[████░░] 45k/200k` para 5h, `[██░░░░] 1.2M/4M` para semana
- Colores condicionales: warning (>=75%), danger (>=90%)
- Números formateados con formatearNumero(): 200000 → 200k, 1000000 → 1M
- Reorganización: limites > resumen > presupuesto > última sesión

**Arquitectura:**
- Ventanas móviles (rolling windows) sin reseteo manual
- Limites: 200k tokens (5h), 4M tokens (1 semana)
- Configurables por env: CLAUDE_LIMITE_5H_TOKENS, CLAUDE_LIMITE_SEMANA_TOKENS

**Push:** Commit 515b058 en acabellan1868-prog/hogarOS

**Próxima fase:** 13e (verificación offline + despliegue en VM 101)

---

## 2026-04-02 (noche)

### Fase 13c: Tarjeta "Asistente IA" implementada

Se completó la implementación de la tarjeta en el portal que consume datos de Claude Code desde MediDo.

**Cambios en portal/index.html:**
- Grid CSS: nueva tarjeta Asistente IA (span 4 columnas), Backup ajustado (span 3)
- HTML: tarjeta con icono smart_toy, contenedor claudeContenido
- Función JS cargarClaude(): fetch a /salud/api/claude/resumen
- Renderiza: barra presupuesto, coste/presupuesto, sesiones, tokens, días reseteo, última sesión
- Helper formatearNumero(): formatea 1000000 → 1M, 15000 → 15k
- Inicialización: cargarClaude() al cargar + en setInterval (cada 60s)

**Características:**
- Presupuesto opcional: si no está configurado, solo muestra coste en grande
- Fallback offline: clase hogar-tarjeta--offline si MediDo no responde
- Responsivo: 100% ancho móvil, 4/12 columnas desktop
- Colores: primario (teal) + aviso (naranja) para presupuesto alto
- Reutiliza clases existentes: no necesita CSS nuevo

**Push:** Commit 1dcb2f2 en acabellan1868-prog/hogarOS

**Próxima fase:** 13d (verificación offline + despliegue en VM 101)

---

## 2026-04-02 (tarde II)

### Fase 13b: Endpoints en MediDo implementados

Se completó la implementación de endpoints en MediDo para recolectar datos de Claude Code.

**Cambios en MediDo:**
- Tabla `tracking_claude`: almacena eventos del hook con UNIQUE en session_id (idempotencia)
- Router `app/rutas/claude.py`: POST /sesion (recibe evento), GET /resumen (agrega por período)
- Config: variables `CLAUDE_PRESUPUESTO_USD`, `CLAUDE_DIA_RESETEO`
- Integración: registrado router en principal.py
- Documentación: actualizado CLAUDE.md, roadmap.md, bitacora.md de MediDo

**Arquitectura:**
- POST idempotente: UNIQUE en session_id previene duplicados en reintentos del hook
- GET /resumen: agrega tokens por período (día/semana/mes)
- Presupuesto opcional: calcula saldo, porcentaje, días restantes
- Reseteo flexible: día configurable (no siempre el 1ro del mes)

**Push:** Commit 46c3e08 en acabellan1868-prog/MediDo

**Próxima fase:** 13c (tarjeta portal consumiendo GET /resumen)

---

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
