# Mejoras propuestas — hogarOS

> Mejoras del portal y nuevas apps del ecosistema.
> Para mejoras internas de ReDo (presencia, tipo/zona), ver `ReDo/mejoras.md`.
> Creado: 2026-03-25
> Estado: borrador para discusión

---

## Índice

1. [MediDo — Métricas y salud del hogar (nueva app)](#1-medido--métricas-y-salud-del-hogar)
2. [Integración en el portal de mejoras de ReDo](#2-integración-en-el-portal-de-mejoras-de-redo)
3. [Otras mejoras aparcadas (no descartadas)](#3-otras-mejoras-aparcadas)

---

## 1. MediDo — Métricas y salud del hogar

### Problema actual

Para saber si el ecosistema funciona bien, hay que mirar en varios sitios:
- **Portainer** → estado de contenedores (n8n, jupyterlab, planka, nodered, nextcloud...)
- **Widget de backup** en el portal → último backup
- **Proxmox** → CPU, RAM, disco de la VM
- **Probar cada servicio manualmente** → ¿responde FiDo? ¿responde HA?

No hay una vista unificada que diga "todo OK" o "atención: el disco está al 90%".

### Qué se gana

| Caso de uso | Valor |
|---|---|
| **Panel de salud** | Un vistazo: todo verde o algo amarillo/rojo |
| **Alertas proactivas** | "Disco al 85%" antes de que sea tarde |
| **Historial** | "¿Cuándo empezó a fallar Nextcloud?" |
| **Diagnóstico** | "FiDo tardó 3s en responder, cuando lo normal es 200ms" |
| **Autonomía** | No depender de Portainer/Proxmox para lo básico |

### Decisión: App nueva independiente

Sigue la filosofía del ecosistema (cada app independiente con su repo, contenedor y base de datos). Se integra en hogarOS igual que las demás: proxy Nginx + endpoint `/api/resumen` + tarjeta en el portal.

Descartado meterlo dentro de hogar-api porque mezclaría responsabilidades y sería más difícil de aislar si falla.

### Arquitectura

```
hogarOS Nginx (puerto 80)
├── /salud/         → MediDo (medido:8084)      ← NUEVO
├── ...demás rutas existentes...
```

```
Docker Compose (hogarOS)
├── nginx (hogar-portal)
├── hogar-api
├── redo
├── fido
└── medido          ← NUEVO (puerto 8084)
    Volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /mnt/datos/medido:/app/data
```

> **Seguridad:** El socket de Docker se monta `:ro`. El código solo hace `client.containers.list()` y `container.stats()`. No ejecuta, crea ni elimina contenedores.

### Stack técnico

| Capa | Tecnología |
|---|---|
| Backend | Python 3.12 + FastAPI |
| Base de datos | SQLite (historial de métricas) |
| Métricas de sistema | **Proxmox API** (CPU, RAM, disco de VMs y host) |
| Acceso a Docker | `docker` SDK para Python (contenedores) |
| Health checks | `httpx` (peticiones HTTP a cada servicio) |
| Scheduler | APScheduler (recolección periódica) |
| Frontend | HTML/CSS/JS vanilla + hogar.css |
| Notificaciones | NTFY (topic `hogaros-3ca6f61b`, igual que ReDo) |

> **Decisión de diseño (2026-03-26):** Se descarta `psutil` para métricas de sistema.
> Dentro de un contenedor Docker, `psutil` ve los recursos del contenedor, no los del
> host. Habría que montar `/proc` y `/sys` del host, lo cual es un hack frágil.
>
> En su lugar se usa la **API REST de Proxmox** (puerto 8006), que ve todo desde arriba:
> el propio host Proxmox, todas las VMs, almacenamiento, etc. Es más limpio, más potente
> y no requiere montar nada especial en el contenedor — solo una petición HTTP con token.

### Qué se monitoriza

#### 1.1 Recursos del sistema — Proxmox API

Mediante la API REST de Proxmox (`https://IP_PROXMOX:8006/api2/json/...`).
Se autentica con un **API Token** (creado en Proxmox, almacenado en `.env`).

**Datos del host Proxmox:**

| Endpoint | Datos |
|---|---|
| `GET /nodes/{node}/status` | CPU, RAM, disco, uptime del servidor físico |

**Datos de cada VM (ej: VM 101):**

| Endpoint | Datos |
|---|---|
| `GET /nodes/{node}/qemu/{vmid}/status/current` | CPU, RAM, disco, estado, uptime |
| `GET /nodes/{node}/qemu` | Lista de todas las VMs con estado |

**Datos de almacenamiento:**

| Endpoint | Datos |
|---|---|
| `GET /nodes/{node}/storage` | Discos, uso, espacio libre (incluye disco externo USB) |

```json
{
  "host": {
    "cpu_percent": 15.2,
    "memoria": { "total_gb": 16.0, "usado_gb": 10.5, "percent": 65.6 },
    "uptime_dias": 90
  },
  "vms": [
    {
      "vmid": 101,
      "nombre": "debian-docker",
      "estado": "running",
      "cpu_percent": 23.5,
      "memoria": { "total_gb": 8.0, "usado_gb": 5.2, "percent": 65.0 },
      "disco": { "total_gb": 100.0, "usado_gb": 62.0, "percent": 62.0 },
      "uptime_dias": 45
    }
  ],
  "almacenamiento": [
    { "nombre": "local-lvm", "total_gb": 200, "usado_gb": 120, "percent": 60.0 },
    { "nombre": "usb1", "total_gb": 117, "usado_gb": 45, "percent": 38.5 }
  ]
}
```

**Ventajas sobre psutil:**
- Ve las métricas **reales** de la VM (no las del contenedor)
- Ve el **host Proxmox** (si el servidor se queda sin RAM, lo sabrías)
- Ve **todas las VMs** (si en el futuro se añade otra VM, se monitoriza automáticamente)
- Ve el **almacenamiento** (incluido disco externo de backups)
- No necesita montar nada especial en el contenedor

**Configuración necesaria:**
1. Crear API Token en Proxmox: Datacenter → Permissions → API Tokens
2. Variables en `.env`: `PVE_HOST`, `PVE_TOKEN_ID`, `PVE_TOKEN_SECRET`, `PVE_NODE`

#### 1.2 Estado de contenedores Docker

Mediante el SDK de Docker (socket montado `:ro`), listar todos los contenedores y su estado:

```json
{
  "contenedores": [
    {
      "nombre": "hogar-portal",
      "imagen": "nginx:alpine",
      "estado": "running",
      "salud": "healthy",
      "inicio": "2026-03-20T10:00:00",
      "uptime_horas": 120,
      "cpu_percent": 0.1,
      "memoria_mb": 12
    }
  ]
}
```

MediDo ve todos los contenedores (el socket de Docker es compartido):
- **Gestionados por hogarOS:** nginx, hogar-api, redo, fido, medido
- **Gestionados por Portainer:** n8n, jupyterlab, planka, nodered, nextcloud, etc.

#### 1.3 Health checks de servicios

Peticiones HTTP periódicas a cada servicio:

| Servicio | URL de comprobación | Respuesta esperada |
|---|---|---|
| Portal | `http://localhost:80/` | HTTP 200 |
| FiDo | `http://fido:8080/api/resumen` | HTTP 200 + JSON |
| ReDo | `http://localhost:8083/api/resumen` | HTTP 200 + JSON |
| hogar-api | `http://hogar-api:8080/lanzador` | HTTP 200 + JSON |
| Home Assistant | `http://192.168.31.132:8123/api/` | HTTP 200/401 |
| Kryptonite | `http://localhost:5000/portafolio` | HTTP 200 + JSON |
| Nextcloud | `http://localhost:8081/status.php` | HTTP 200 |
| Portainer | `http://localhost:9443/api/status` | HTTP 200 |

Se mide **tiempo de respuesta** (latencia) y se almacena para detectar degradación.

#### 1.4 Estado de backups

Consulta el endpoint `/api/backup` de hogar-api o lee `backup_estado.json`. Calcula:
- Días desde último backup
- Tamaño del último backup
- ¿Dumps OK? (PostgreSQL de Planka, MariaDB de Nextcloud)

### Esquema de base de datos

```sql
-- Snapshots periódicos del estado del sistema (Proxmox + Docker)
CREATE TABLE IF NOT EXISTS metricas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha TEXT NOT NULL DEFAULT (datetime('now')),
    -- Host Proxmox
    pve_cpu_percent REAL,
    pve_memoria_percent REAL,
    -- VM 101 (o la que corresponda)
    vm_cpu_percent REAL,
    vm_memoria_percent REAL,
    vm_disco_percent REAL,
    -- Contenedores Docker
    contenedores_total INTEGER,
    contenedores_running INTEGER,
    contenedores_stopped INTEGER
);

-- Historial de health checks
CREATE TABLE IF NOT EXISTS health_checks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha TEXT NOT NULL DEFAULT (datetime('now')),
    servicio TEXT NOT NULL,
    estado TEXT NOT NULL CHECK(estado IN ('ok', 'lento', 'caido', 'error')),
    tiempo_respuesta_ms INTEGER,
    codigo_http INTEGER,
    mensaje TEXT
);

-- Alertas de MediDo
CREATE TABLE IF NOT EXISTS alertas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tipo TEXT NOT NULL,
    mensaje TEXT NOT NULL,
    servicio TEXT,
    fecha TEXT NOT NULL DEFAULT (datetime('now')),
    enviada INTEGER NOT NULL DEFAULT 0,
    resuelta INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_metricas_fecha ON metricas(fecha);
CREATE INDEX IF NOT EXISTS idx_health_fecha ON health_checks(fecha);
CREATE INDEX IF NOT EXISTS idx_health_servicio ON health_checks(servicio);
CREATE INDEX IF NOT EXISTS idx_alertas_fecha ON alertas(fecha);
```

### Intervalos de recolección

| Métrica | Intervalo | Justificación |
|---|---|---|
| Health checks | 60 segundos | Detectar caídas rápido |
| Recursos sistema | 5 minutos | CPU/RAM/disco cambian lento |
| Estado contenedores | 5 minutos | Coincide con recursos |
| Limpieza de historial | 1 vez/día | Mantener solo 90 días de detalle |

### Umbrales de alerta

| Métrica | Warning | Danger | Acción |
|---|---|---|---|
| CPU | > 80% (5 min sostenido) | > 95% (5 min) | NTFY |
| RAM | > 85% | > 95% | NTFY |
| Disco | > 80% | > 90% | NTFY |
| Servicio caído | 1 check fallido | 3 checks consecutivos | NTFY al 3ro |
| Servicio lento | > 2s respuesta | > 5s respuesta | Log |
| Contenedor parado | - | Cualquiera | NTFY (excluir lista de ignorados) |
| Backup antiguo | > 7 días | > 14 días | NTFY |

### Endpoints de la API

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/resumen` | Estado general para la tarjeta del portal |
| GET | `/api/proxmox` | Métricas actuales de Proxmox (host + VMs + almacenamiento) |
| GET | `/api/proxmox/historial?horas=24` | Historial de métricas del sistema |
| GET | `/api/contenedores` | Lista de contenedores Docker con estado |
| GET | `/api/servicios` | Estado de los health checks |
| GET | `/api/servicios/{nombre}/historial` | Historial de un servicio |
| GET | `/api/alertas` | Alertas activas y recientes |
| POST | `/api/alertas/{id}/resolver` | Marcar alerta como resuelta |

**`GET /api/resumen` (para la tarjeta del portal):**

```json
{
  "estado_global": "ok",
  "pve_cpu_percent": 15.2,
  "pve_memoria_percent": 65.6,
  "vm_cpu_percent": 23.5,
  "vm_memoria_percent": 65.0,
  "vm_disco_percent": 62.0,
  "contenedores_running": 12,
  "contenedores_total": 12,
  "servicios_ok": 8,
  "servicios_total": 8,
  "ultimo_backup_dias": 3,
  "alertas_activas": 0
}
```

`estado_global`: `"ok"` si todo verde, `"warning"` si hay algún warning, `"danger"` si hay algún danger.

### Frontend de MediDo (`/salud/`)

1. **Semáforo global** — Indicador grande: verde/amarillo/rojo
2. **Tarjetas de recursos** — CPU, RAM, Disco con gauge circular o barra de progreso
3. **Grid de contenedores** — Nombre + estado (icono verde/rojo) + uptime
4. **Grid de servicios** — Nombre + latencia + estado
5. **Gráfica de historial** — Línea temporal de CPU/RAM últimas 24h (canvas/SVG)
6. **Feed de alertas** — Últimas alertas con botón "resolver"

### Tarjeta en el portal (`index.html`)

Nueva tarjeta "Salud del sistema" mostrando:
- Semáforo global (icono grande verde/amarillo/rojo)
- CPU / RAM / Disco en una línea
- Contenedores: "12/12 running"
- Servicios: "8/8 OK"
- Enlace "Abrir" → `/salud/`

### Estructura de ficheros

```
MediDo/
├── app/
│   ├── principal.py          → FastAPI + APScheduler
│   ├── bd.py                 → Acceso SQLite
│   ├── config.py             → Variables de entorno
│   ├── esquema.sql           → DDL
│   ├── modelos.py            → Pydantic schemas
│   ├── recolector_proxmox.py → Proxmox API (host, VMs, almacenamiento)
│   ├── recolector_docker.py  → Docker SDK (contenedores)
│   ├── health_checker.py     → httpx (health checks)
│   ├── alertador.py          → Lógica de umbrales + NTFY
│   └── rutas/
│       ├── resumen.py
│       ├── proxmox.py
│       ├── contenedores.py
│       ├── servicios.py
│       └── alertas.py
├── static/
│   └── index.html            → SPA (vanilla JS + hogar.css)
├── Dockerfile
├── requirements.txt
└── README.md
```

### Cambios necesarios en hogarOS

| Fichero | Cambio |
|---|---|
| `docker-compose.yml` | Nuevo servicio `medido` con volúmenes y socket |
| `nginx.conf` | Nueva ruta `/salud/` → proxy a medido:8084 |
| `portal/index.html` | Nueva tarjeta "Salud del sistema" |
| `.env.example` | Variables de configuración de MediDo (si las hay) |

### Complejidad estimada

| Componente | Esfuerzo |
|---|---|
| Estructura del proyecto (boilerplate) | Bajo |
| Recolector Proxmox API (host + VMs + storage) | Medio |
| Recolector Docker (SDK) | Medio |
| Health checker (httpx) | Medio |
| Lógica de alertas y NTFY | Medio |
| Endpoints API | Medio |
| Frontend completo | Medio-alto |
| Tarjeta en portal | Bajo |
| Configuración Nginx + compose | Bajo |
| Crear API Token en Proxmox | Bajo (manual, una vez) |
| **Total** | **Medio-alto** |

### Dependencias nuevas (solo para MediDo)

| Paquete Python | Propósito |
|---|---|
| `docker` | SDK para interactuar con el daemon Docker |
| `httpx` | Proxmox API + Health checks HTTP |
| `apscheduler` | Tareas periódicas |

> **Nota:** `psutil` se ha eliminado. Todas las métricas de sistema vienen de Proxmox API.

### Variables de entorno nuevas

| Variable | Descripción | Ejemplo |
|---|---|---|
| `PVE_HOST` | IP o hostname del servidor Proxmox | `192.168.31.100` |
| `PVE_NODE` | Nombre del nodo Proxmox | `pve` |
| `PVE_TOKEN_ID` | ID del token API (usuario!token) | `root@pam!medido` |
| `PVE_TOKEN_SECRET` | Secret del token API | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `PVE_VERIFY_SSL` | Verificar certificado SSL (false para self-signed) | `false` |

### Consideraciones de seguridad

- **Proxmox API Token** con permisos mínimos (solo lectura de estado/métricas)
- **Socket Docker** montado `:ro` — solo lectura, no puede crear/eliminar contenedores
- **SSL self-signed**: Proxmox usa certificado autofirmado por defecto; `PVE_VERIFY_SSL=false` lo acepta
- Health checks internos no necesitan autenticación (red local)
- Home Assistant requiere Bearer token — se reutiliza `HA_TOKEN` del `.env`

### Preparación previa (manual, una sola vez)

1. **Crear API Token en Proxmox:**
   - Panel web de Proxmox → Datacenter → Permissions → API Tokens
   - Usuario: `root@pam` (o crear usuario dedicado `medido@pve`)
   - Token ID: `medido`
   - Desmarcar "Privilege Separation" (hereda permisos del usuario)
   - Copiar el secret (solo se muestra una vez)
2. **Verificar conectividad** desde la VM 101:
   ```bash
   curl -k -H "Authorization: PVEAPIToken=root@pam!medido=SECRET" \
     https://192.168.31.103:8006/api2/json/nodes
   ```
3. **Añadir variables** al `.env` de hogarOS

**Datos reales (configurados 2026-03-26):**

| Variable | Valor |
|---|---|
| `PVE_HOST` | `192.168.31.103` |
| `PVE_NODE` | `deeloco` |
| `PVE_TOKEN_ID` | `root@pam!medido` |
| `PVE_TOKEN_SECRET` | *(almacenado en `.env`, no en este fichero)* |
| `PVE_VERIFY_SSL` | `false` |

✅ API Token creado en Proxmox (2026-03-26)

---

## 2. Integración en el portal de mejoras de ReDo

Las mejoras internas de ReDo (presencia, tipo/zona) se documentan en `ReDo/mejoras.md`. Aquí se describe lo que afecta al portal de hogarOS:

### Tarjeta de ReDo con desglose por tipo

Cuando ReDo amplíe su `/api/resumen` con el campo `por_tipo`, la tarjeta en el portal puede mostrar un desglose visual:

```
┌─────────────────────────────────────┐
│  📡 Red Doméstica                   │
│                                     │
│  15 activos · 2 desconocidos        │
│                                     │
│  📱 4  💻 3  📺 2  🔌 5  ❓ 1      │
│                                     │
│  Último escaneo: hace 3 min         │
│                               Abrir →│
└─────────────────────────────────────┘
```

**Cambio necesario:** Modificar el JS de `index.html` que consume `/red/api/resumen` para renderizar los iconos por tipo. Es un cambio menor en el frontend del portal.

### Navegación a nueva sección de presencia

Si ReDo implementa una vista de presencia, se puede añadir un enlace rápido en los accesos rápidos del portal:
- "Ver timeline de presencia" → `/red/#presencia`

---

## 3. Otras mejoras aparcadas (no descartadas)

| Mejora | Proyecto | Descripción breve |
|---|---|---|
| Web Push / Service Worker | hogarOS | Notificaciones push nativas en el navegador |
| PWA con modo offline | hogarOS | Instalar portal como app, caché offline |
| Widget consumo eléctrico | hogarOS | Integración con HA + enchufe con medición |
| Presupuestos por categoría | FiDo | Definir límites mensuales y alertar |
| Informe mensual automático | FiDo | PDF/HTML generado el día 1, enviado por NTFY |
| Movimientos recurrentes | FiDo | Detección de suscripciones y gasto fijo |
| TareDo | Nueva app | Tareas domésticas compartidas tipo Kanban |

Se pueden retomar en cualquier momento.

---

## Orden global de implementación

| Prioridad | Mejora | Proyecto | Esfuerzo | Valor | Estado |
|---|---|---|---|---|---|
| 1 | Tipo y zona | ReDo | Bajo-medio | Alto | **Completado** (2026-03-26) |
| 2 | Presencia + detalle | ReDo | Medio | Alto | **Completado** (2026-03-26) |
| 3 | Auto-detección tipo | ReDo | Bajo | Medio | **Completado** (2026-03-26) |
| 4 | MediDo (Proxmox API) | Nueva app + hogarOS | Medio-alto | Muy alto | **Completado** (2026-03-27) |
| 5 | Estandarizar drawers | ReDo + FiDo + MediDo | Bajo | Medio | **Completado** (2026-03-27) |
