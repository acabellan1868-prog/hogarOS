# CLAUDE.md — hogarOS

## Qué es este repo

**hogarOS** es el repositorio central del ecosistema domótico. Contiene:
- El portal web (frontend HTML/CSS/JS vanilla)
- La configuración de Nginx (reverse proxy)
- El `docker-compose.yml` que orquesta **todos** los servicios
- La API de gestión del lanzador (`hogar-api`)
- Los scripts de backup (`Politica_backup/`)

No contiene el código de ReDo ni FiDo — esos tienen repos propios.

---

## Estructura del ecosistema completo

### Repos locales (Windows)

Los repos se clonan en el mismo directorio padre. La ruta concreta varía según el equipo.

| Carpeta | GitHub | Propósito |
|---|---|---|
| `hogarOS/` | acabellan1868-prog/hogarOS | Este repo |
| `ReDo/` | acabellan1868-prog/ReDo | Monitor de red |
| `FiDo/` | acabellan1868-prog/FiDo | Finanzas domésticas |
| `MediDo/` | acabellan1868-prog/MediDo | Métricas y salud del hogar |
| `kryptonite/` | acabellan1868-prog/kryptonite | Crypto portfolio |

### Repos en el servidor (VM 101, `/mnt/datos/`)

```
/mnt/datos/
├── hogarOS/        → git clone de este repo (fuente del docker-compose)
├── redo-build/     → git clone de ReDo     (build context del contenedor redo)
├── fido-build/     → git clone de FiDo     (build context del contenedor fido)
├── redo/           → datos persistentes ReDo  (redo.db)
├── fido/           → datos persistentes FiDo  (fido.db)
├── medido-build/   → git clone de MediDo  (build context del contenedor medido)
├── medido/         → datos persistentes MediDo (medido.db)
└── hogar-api/      → datos persistentes hogar-api (lanzador.json)
```

---

## Arquitectura de red

```
Usuario → http://192.168.31.131 (VM 101 Debian 12 en Proxmox)
           ↓
        Nginx — contenedor hogar-portal (puerto 80)
        │
        ├── /                   → portal/index.html (estático)
        ├── /lanzador.html      → portal/lanzador.html
        ├── /static/            → portal/static/  (hogar.css, favicon, etc.)
        ├── /red/static/        → portal/static/  (misma carpeta — ver nota sub_filter)
        ├── /finanzas/static/   → portal/static/  (misma carpeta — ver nota sub_filter)
        ├── /salud/static/      → portal/static/  (misma carpeta — ver nota sub_filter)
        ├── /red/               → proxy → ReDo   (host:8083, network_mode: host)
        ├── /finanzas/          → proxy → FiDo   (contenedor fido:8080)
        ├── /salud/             → proxy → MediDo (contenedor medido:8084)
        ├── /api/lanzador       → proxy → hogar-api
        ├── /api/backup         → proxy → hogar-api
        ├── /crypto/api/        → proxy → Kryptonite (host:5000)
        └── /domotica/api/      → proxy → Home Assistant (192.168.31.132:8123)
```

### ⚠️ Nota importante: sub_filter y hogar.css

Nginx usa `sub_filter` para reescribir rutas en el HTML de ReDo y FiDo:
- `href="/static/..."` → `href="/red/static/..."` (en ReDo)
- `href="/static/..."` → `href="/finanzas/static/..."` (en FiDo)

Por eso existen `location /red/static/` y `location /finanzas/static/` que sirven
desde `portal/static/` (no proxifican a las apps). Sin estos blocks, `hogar.css`
daría 404 en ReDo y FiDo.

---

## Estructura de este repo

```
hogarOS/
├── portal/
│   ├── index.html              → Dashboard principal
│   ├── lanzador.html           → Lanzador de apps
│   ├── admin-lanzador.html     → Admin del lanzador
│   └── static/
│       ├── hogar.css           → Design system compartido (Living Sanctuary)
│       ├── favicon.svg
│       └── site.webmanifest
├── hogar-api/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app/principal.py        → FastAPI: endpoints /lanzador y /backup
├── Politica_backup/
│   ├── backup.sh               → Orquestador principal de backup
│   ├── backup_dumps.sh         → Dumps de bases de datos
│   ├── ROADMAP.md
│   └── analisis.md
├── nginx.conf                  → Procesado con envsubst (variable $HA_TOKEN)
├── docker-compose.yml          → Orquesta nginx, hogar-api, redo, fido
├── actualizar.sh               → Script de despliegue (ver abajo)
├── ROADMAP.md
└── .env.example                → Variables de entorno necesarias
```

---

## Flujo de despliegue

1. Cambios locales → `git push` al repo correspondiente (hogarOS / ReDo / FiDo)
2. En el servidor: ejecutar `./actualizar.sh` desde `/mnt/datos/hogarOS/`
3. El script hace `git pull` de los 4 repos (hogarOS, ReDo, FiDo, MediDo) → `docker compose down` → `build` → `up -d`

No hay CI/CD automático. El despliegue siempre es manual con `actualizar.sh`.

---

## Design system — Living Sanctuary

- **Archivo:** `portal/static/hogar.css`
- **Todas las apps** cargan este CSS con `<link rel="stylesheet" href="/static/hogar.css">`
- **Fuentes:** Plus Jakarta Sans + Be Vietnam Pro + Material Symbols Outlined (Google Fonts, cargadas desde hogar.css — no hace falta añadirlas en cada HTML)
- **Modo oscuro:** `data-tema="oscuro"` en el elemento `<html>`
- **Toggle tema:** botón `.hogar-toggle-tema` que guarda en `localStorage('hogar-tema')`
- **Componentes principales:** `.hogar-header`, `.hogar-lumina`, `.hogar-tarjeta`, `.hogar-contenedor`

---

## Convenciones de código

- Todo en español: variables, funciones, clases, comentarios, nombres de ficheros
- HTML/CSS/JS vanilla (sin frameworks en el frontend)
- Python + FastAPI en los backends
- Sin TypeScript, sin npm, sin bundlers

---

## Integración con Claude Code — Monitor de uso (Fase 13)

### Script de tracking: `~/.claude/claude-tracker.py`

**Ubicación:** `C:\Users\familiaAlvarezBascon\.claude\claude-tracker.py` (no está en el repo, vive en la máquina local)

**Propósito:** Capturar uso de tokens y coste estimado cada vez que se cierra una sesión de Claude Code.

**Configuración:**
- Hook `Stop` en `~/.claude/settings.json` → ejecuta `py ~/.claude/claude-tracker.py`
- El script recibe JSON del hook con: session_id, input_tokens, output_tokens, cache_read_input_tokens, cache_creation_input_tokens
- Calcula coste en USD según precios Sonnet 4.6 (input $3/Mtok, output $15/Mtok, cache $0.30+$3.75/Mtok)

**Almacenamiento offline-first:**
- Guarda siempre en `~/.claude/cola_sync.jsonl` (cola local de sesiones)
- Intenta POST a MediDo (`http://192.168.31.131/salud/api/claude/sesion`)
- Si falla (sin red) → entrada queda en cola para sincronizar después
- Si POST OK → reintenta enviar entradas pendientes de sesiones anteriores

**Próxima fase (13b):**
- Crear tabla `claude_sesiones` en MediDo BD
- Implementar endpoint `POST /api/claude/sesion` (recibe del hook)
- Implementar endpoint `GET /api/claude/resumen` (agrega datos por período)
- Tarjeta "Asistente IA" en portal (coste/presupuesto, sesiones del día, última sesión)
