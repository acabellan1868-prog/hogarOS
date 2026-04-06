# CLAUDE.md — hogarOS

## Qué contiene este repo
- Portal web (frontend HTML/CSS/JS vanilla)
- Nginx: reverse proxy + `sub_filter` para reescribir rutas de sub-apps
- `docker-compose.yml`: orquesta nginx, hogar-api, redo, fido, medido
- `hogar-api`: FastAPI, endpoints `/lanzador` y `/backup`
- `Politica_backup/`: scripts de backup

## Rutas en el servidor (VM 101)

```
/mnt/datos/
├── hogarOS/        ← este repo (docker-compose + .env con HA_TOKEN)
├── redo-build/     ← git clone ReDo
├── fido-build/     ← git clone FiDo
├── medido-build/   ← git clone MediDo
├── redo/           ← redo.db
├── fido/           ← fido.db
├── medido/         ← medido.db
└── hogar-api/      ← lanzador.json
```

## Arquitectura Nginx

```
192.168.31.131:80 (hogar-portal)
├── /                   → portal/index.html (estático)
├── /static/            → portal/static/
├── /red/               → host.docker.internal:8083 (ReDo, network_mode:host)
├── /finanzas/          → fido:8080
├── /salud/             → medido:8084
├── /api/lanzador       → hogar-api
├── /api/backup         → hogar-api
├── /crypto/api/        → host.docker.internal:5000 (Kryptonite)
└── /domotica/api/      → 192.168.31.132:8123 (Home Assistant, Bearer token)
```

## Gotcha: sub_filter y hogar.css

Nginx usa `sub_filter` para reescribir rutas en el HTML de las sub-apps:
- `href="/static/"` → `href="/red/static/"` (ReDo), `/finanzas/static/` (FiDo), `/salud/static/` (MediDo)

Por eso existen `location /red/static/`, `/finanzas/static/`, `/salud/static/` que sirven desde `portal/static/` — las sub-apps no sirven `hogar.css` por sí mismas. Si `hogar.css` da 404, el problema está en nginx, no en la sub-app.

## Estructura del repo

```
hogarOS/
├── portal/
│   ├── index.html
│   ├── lanzador.html
│   ├── admin-lanzador.html
│   └── static/
│       ├── hogar.css           ← design system compartido (Living Sanctuary)
│       └── favicon.svg
├── hogar-api/
│   └── app/principal.py
├── Politica_backup/
│   ├── backup.sh               ← orquestador principal (Proxmox)
│   ├── backup_dumps.sh         ← dumps BD (VM 101)
│   └── restauracion.md
├── nginx.conf                  ← usa envsubst para $HA_TOKEN
├── docker-compose.yml
├── actualizar.sh               ← pull × 4 repos → down → build → up -d
└── .env.example
```

## Variables de entorno — convención del ecosistema

Todos los repos son públicos. Los valores sensibles van en `.env` (nunca en git).

| Archivo | Dónde | Propósito |
|---------|-------|-----------|
| `.env` | Solo en la VM, nunca en git | Valores reales |
| `.env.example` | En git, sin valores reales | Plantilla para saber qué configurar |

**Variables en hogarOS/.env** (orquestador — contiene las de todos los servicios):

| Variable | Servicio | Descripción |
|----------|----------|-------------|
| `HA_TOKEN` | Nginx, MediDo | Token de Home Assistant |
| `REDO_NETWORK` | ReDo | Red doméstica a escanear (ej: `192.168.31.0/24`) |
| `NTFY_TOPIC_FIDO` | FiDo | Topic NTFY (intermediario de transporte) para movimientos bancarios |
| `NTFY_TOPIC_ALERTAS` | ReDo, MediDo | Topic NTFY para alertas del sistema |
| `NTFY_CUENTA_DEFAULT` | FiDo | ID de cuenta por defecto para movimientos NTFY |
| `PVE_HOST` | MediDo | IP del servidor Proxmox (hipervisor de virtualización) |
| `PVE_NODE` | MediDo | Nombre del nodo Proxmox |
| `PVE_TOKEN_ID` | MediDo | ID del token de API (Interfaz de Programación) de Proxmox |
| `PVE_TOKEN_SECRET` | MediDo | Secreto del token de Proxmox |
| `PVE_VERIFY_SSL` | MediDo | Verificar certificado SSL (Capa de Conexión Segura) |

Nota: en los `docker-compose.yml` individuales (desarrollo local) cada proyecto
usa solo sus propias variables con el nombre `NTFY_TOPIC` (sin sufijo).

## Despliegue

1. `git push` al repo correspondiente
2. En VM 101: `./actualizar.sh` desde `/mnt/datos/hogarOS/`

Sin CI/CD (Integración y Despliegue Continuo). Siempre manual.

## Design system — Living Sanctuary

- **Archivo:** `portal/static/hogar.css` (todas las apps lo cargan desde `/static/hogar.css`)
- **Fuentes:** Plus Jakarta Sans + Be Vietnam Pro + Material Symbols Outlined (cargadas desde hogar.css)
- **Modo oscuro:** `data-tema="oscuro"` en `<html>`
- **Toggle:** botón `.hogar-toggle-tema`, guarda en `localStorage('hogar-tema')`
- **Componentes:** `.hogar-header`, `.hogar-lumina`, `.hogar-tarjeta`, `.hogar-contenedor`
- **Header:** lumina + `hogar-header__barra` + marca izquierda + hamburguesa derecha
- **Drawer sub-apps:** app activa → separador → otras apps → Ir al Portal → Cambiar tema
- **Enlaces drawer:** usar `window.location.origin` (evita conflictos con sub_filter)

## Monitor de Claude

- Hook `Stop` en `~/.claude/settings.json` ejecuta `py ~/.claude/claude-tracker.py`
- El script guarda uso en cola local (`~/.claude/cola_sync.jsonl`) y hace POST a MediDo
- Endpoint receptor: `POST /salud/api/claude/sesion` (ver API de MediDo)
