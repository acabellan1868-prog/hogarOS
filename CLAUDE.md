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

| Ruta local | GitHub | Propósito |
|---|---|---|
| `E:\Documentos\Desarrollo\claude\hogarOS\` | acabellan1868-prog/hogarOS | Este repo |
| `E:\Documentos\Desarrollo\claude\ReDo\` | acabellan1868-prog/ReDo | Monitor de red |
| `E:\Documentos\Desarrollo\claude\FiDo\` | acabellan1868-prog/FiDo | Finanzas domésticas |

> ⚠️ **`E:\Documentos\Desarrollo\claude\network-monitor\` es una carpeta OBSOLETA** (Node.js, sin git).
> No tiene nada que ver con ReDo. Ignorarla siempre.

### Repos en el servidor (VM 101, `/mnt/datos/`)

```
/mnt/datos/
├── hogarOS/        → git clone de este repo (fuente del docker-compose)
├── redo-build/     → git clone de ReDo     (build context del contenedor redo)
├── fido-build/     → git clone de FiDo     (build context del contenedor fido)
├── redo/           → datos persistentes ReDo  (redo.db)
├── fido/           → datos persistentes FiDo  (fido.db)
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
        ├── /red/               → proxy → ReDo   (host:8083, network_mode: host)
        ├── /finanzas/          → proxy → FiDo   (contenedor fido:8080)
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
3. El script hace `git pull` de los 3 repos → `docker compose down` → `build` → `up -d`

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
