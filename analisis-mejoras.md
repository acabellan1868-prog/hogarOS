# Mejoras propuestas — hogarOS

> Mejoras del portal y nuevas apps del ecosistema.
> Para mejoras internas de ReDo (presencia, tipo/zona), ver `ReDo/mejoras.md`.
> Creado: 2026-03-25
> Estado: borrador para discusión

---

## Índice

1. [MediDo — Métricas y salud del hogar (nueva app)](#1-medido--métricas-y-salud-del-hogar)
2. [Integración en el portal de mejoras de ReDo](#2-integración-en-el-portal-de-mejoras-de-redo)
3. [Centro de Alertas — Gestión unificada de alertas del ecosistema](#3-centro-de-alertas--gestión-unificada-de-alertas)
4. [Otras mejoras aparcadas (no descartadas)](#4-otras-mejoras-aparcadas)
5. [Monitor de uso de Claude — Tarjeta en el portal](#5-monitor-de-uso-de-claude--tarjeta-en-el-portal)
6. [Propuestas de evolución del ecosistema](#6-propuestas-de-evolución-del-ecosistema)

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

## 3. Centro de Alertas — Gestión unificada de alertas

### Problema actual

Cada app del ecosistema gestiona sus alertas de forma independiente:

| App | Guarda en BD | API alertas | UI alertas | NTFY | Gestión |
|---|---|---|---|---|---|
| **MediDo** | ✅ SQLite (8 tipos) | ✅ GET + resolver | ✅ Tab dedicado | ✅ Solo danger | Resolver |
| **ReDo** | ✅ SQLite (3 tipos) | ❌ No hay endpoints | ❌ No hay UI | ✅ dispositivo_nuevo | Ninguna |
| **FiDo** | ❌ Sin alertas (v2) | ❌ | ❌ | ❌ | — |
| **Portal** | ❌ | ❌ | ⚠️ Solo en memoria JS | ❌ | Ninguna |

**Consecuencias:**
- Para ver alertas hay que ir a la app NTFY en el móvil (sin gestión posible)
- MediDo tiene su propio tab de alertas, pero solo muestra las suyas
- ReDo guarda alertas en BD pero no tiene forma de verlas ni gestionarlas
- No hay un lugar unificado para ver, filtrar, agrupar y gestionar alertas de todo el ecosistema

### Qué se gana

| Caso de uso | Valor |
|---|---|
| **Vista unificada** | Todas las alertas del ecosistema en un solo sitio |
| **Gestión** | Resolver, eliminar, filtrar, agrupar por módulo |
| **Histórico** | "¿Qué alertas hubo esta semana?" sin depender de NTFY |
| **Agrupación** | Ver alertas por app (ReDo, MediDo, FiDo...) |
| **Escalabilidad** | App nueva → expone `/api/alertas` → aparece automáticamente |

### Investigación previa: ¿Por qué no usar NTFY como fuente central?

Se investigó si la API de NTFY podía servir como almacén central de alertas (evitando duplicar datos). Resultado:

- **NTFY es un canal de envío, no un gestor.** Su API permite:
  - ✅ Enviar notificaciones (POST)
  - ✅ Leer mensajes en caché con `?poll=1&since=all` (solo unas pocas horas)
  - ❌ No permite eliminar, marcar como leída, ni gestionar estados
  - ❌ No tiene histórico persistente
- **Conclusión:** NTFY sigue siendo el "timbre" al móvil. La gestión real debe vivir en las BDs de cada app.

### Decisión de diseño: Opción A — Agregación desde el portal

Se evaluaron tres opciones:

| Opción | Descripción | Pros | Contras |
|---|---|---|---|
| **A — Agregador** | Cada app expone `/api/alertas`. El portal consulta y agrega | Sin duplicar datos, cada app es dueña de sus alertas | Si app caída, no se ven sus alertas |
| **B — Hub central** | Apps envían alertas a hogar-api. BD central | Independiente de apps, gestión unificada | Duplica datos, problemas de sincronización |
| **A+ — Híbrida** | Apps envían a hogar-api + guardan local | Sin repetir lógica de gestión | Duplica almacenamiento |

**Decisión: Opción A**, por las siguientes razones:
1. No duplica datos — cada app es la fuente de verdad de sus alertas
2. MediDo ya tiene casi todo implementado (API + UI + gestión)
3. ReDo ya tiene la BD, solo falta exponer un API mínima
4. Sigue la filosofía del ecosistema: apps independientes con contrato estándar
5. La lógica compleja (agrupar, filtrar, ordenar, UI rica) se implementa una sola vez en el portal

**Sobre la repetición de código en cada app:** Cada app solo necesita implementar un API REST mínima sobre su tabla de alertas existente (~30 líneas). La lógica de gestión rica (filtros, agrupación, ordenación, UI) vive exclusivamente en el portal y se implementa una sola vez. No se justifica una librería compartida para tan poco código por app.

### Contrato API estándar para alertas

Todas las apps que generen alertas deben exponer estos endpoints:

#### `GET /api/alertas`

Devuelve las alertas ordenadas por fecha descendente.

```json
{
  "modulo": "redo",
  "activas": 2,
  "alertas": [
    {
      "id": 1,
      "tipo": "dispositivo_nuevo",
      "mensaje": "Nuevo dispositivo: 192.168.31.45 (mi-telefono) - Xiaomi",
      "servicio": null,
      "fecha": "2026-03-31T14:23:45",
      "enviada": 1,
      "resuelta": 0
    }
  ]
}
```

Campos obligatorios:
- `modulo` — Identificador de la app (redo, medido, fido...)
- `activas` — Contador de alertas no resueltas
- `alertas[]` — Array con: `id`, `tipo`, `mensaje`, `fecha`, `resuelta`

Campos opcionales:
- `servicio` — Recurso afectado (nombre de contenedor, IP, etc.)
- `enviada` — Si se notificó por NTFY

#### `POST /api/alertas/{id}/resolver`

Marca una alerta como resuelta. Respuesta: `{ "ok": true, "id": 1 }`

#### `DELETE /api/alertas/{id}`

Elimina una alerta. Respuesta: `{ "ok": true, "id": 1 }`

### Cambios necesarios por app

#### ReDo (no tiene API de alertas)

- Añadir `app/rutas/alertas.py` con los 3 endpoints del contrato
- Añadir campo `resuelta` a la tabla `alertas` (migración: `ALTER TABLE alertas ADD COLUMN resuelta INTEGER NOT NULL DEFAULT 0`)
- ~30 líneas de código nuevo

#### MediDo (ya tiene GET + resolver)

- Añadir campo `modulo` en la respuesta de `GET /api/alertas` → `"modulo": "medido"`
- Añadir endpoint `DELETE /api/alertas/{id}`
- ~10 líneas de código nuevo

#### FiDo (sin alertas por ahora)

- Sin cambios hasta que implemente alertas en v2
- Cuando lo haga, seguirá el contrato estándar

### Centro de alertas en el portal

El portal (`index.html`) tendrá una sección "Centro de Alertas" que:

1. **Consulta** periódicamente `GET /api/alertas` de cada app (via sus proxies: `/red/api/alertas`, `/salud/api/alertas`, etc.)
2. **Agrega** todas las alertas en una lista unificada
3. **Agrupa** por módulo (tabs o filtros: Todas / ReDo / MediDo / ...)
4. **Ordena** por fecha (más recientes primero), con activas antes que resueltas
5. **Permite gestionar:**
   - Resolver → `POST /{modulo}/api/alertas/{id}/resolver`
   - Eliminar → `DELETE /{modulo}/api/alertas/{id}`
   - Filtrar por estado (activas / resueltas / todas)
   - Filtrar por módulo
6. **Refresco automático** cada 60 segundos

La sección de alertas puede vivir como:
- **Opción 1:** Nueva sección en `index.html` (como las tarjetas actuales)
- **Opción 2:** Página propia (`alertas.html`) enlazada desde el portal

> Decidir durante la implementación según el tamaño del código.

### Diagrama del flujo

```
App detecta problema (MediDo, ReDo, ...)
  ├── Guarda en su BD local (ya lo hace)
  └── Envía NTFY al móvil (ya lo hace)

Usuario abre el portal
  └── Centro de Alertas
       ├── GET /salud/api/alertas  → alertas de MediDo
       ├── GET /red/api/alertas    → alertas de ReDo
       ├── GET /finanzas/api/alertas → alertas de FiDo (futuro)
       └── Agrega, agrupa, ordena → UI unificada
            ├── Resolver → POST /{modulo}/api/alertas/{id}/resolver
            └── Eliminar → DELETE /{modulo}/api/alertas/{id}
```

### Impacto en la sección "Alertas recientes" del portal

Actualmente `index.html` tiene una sección "Alertas recientes" que funciona solo en memoria del cliente (JavaScript). Esta sección se **sustituirá** por el nuevo Centro de Alertas con datos reales de las BDs de cada app.

---

## 5. Monitor de uso de Claude — Tarjeta en el portal

### Contexto y limitaciones

Se analizó la posibilidad de integrar datos de uso de Claude en el portal hogarOS.

**Lo que ofrece Anthropic oficialmente:**

| Endpoint | Qué da | Requisito |
|---|---|---|
| `/v1/organizations/usage_report/messages` | Tokens por modelo, workspace, clave API (granularidad 1m/1h/1d) | Admin API key + cuenta de organización |
| `/v1/organizations/cost_report` | Coste en USD por workspace/descripción | Ídem |

**Problema:** Estas APIs requieren un **Admin API key** (`sk-ant-admin...`) que solo está disponible para cuentas de **organización** en `console.anthropic.com`. Con una **suscripción Claude.ai Pro/Max** (que es el caso actual), no existe ninguna API oficial para consultar el uso del plan.

**Lo que NO es posible:**
- Conocer el límite real del plan (Anthropic no lo expone vía API)
- Saber la fecha exacta de reseteo del plan sin configuración manual
- Obtener datos de sesiones de Claude.ai (web) sin scraping (frágil y contra ToS)

**Alternativa viable:** Usar el sistema de **hooks de Claude Code** para capturar el uso de tokens de cada sesión y construir un tracker local completo.

---

### Alcance: Claude Code, no Claude Chat

> ⚠️ **Importante:** Esta solución captura **únicamente el uso de Claude Code** (el CLI). Las conversaciones en **claude.ai web** (chat en el navegador) no tienen hooks ni API accesible para cuentas Pro, por lo que quedan **fuera del seguimiento**.

### Solución: hook POST a MediDo con cola offline

Claude Code ejecuta hooks (scripts externos) en eventos del ciclo de vida de cada sesión. El hook `Stop` se dispara al terminar la sesión e incluye datos de uso. El hook hace un **POST directo a MediDo**, que guarda los datos en su propia BD (SQLite en la VM 101). No hay ficheros compartidos entre Windows y la VM.

Para que funcione **fuera de la red local** (trabajo desde otro lugar), el hook usa una estrategia **offline-first**: siempre guarda en una cola local primero y luego intenta el POST. Si no hay conexión, los datos quedan en la cola y se sincronizan automáticamente la próxima vez que haya acceso.

#### Arquitectura

```
Claude Code termina sesión (en cualquier equipo)
  └── Hook "Stop"
       1. Escribe en cola local: ~/.claude/cola_sync.jsonl   ← siempre funciona
       2. Intenta POST a http://192.168.31.131/salud/api/claude/sesion
            ├── OK → marca entrada como sincronizada
            └── Sin red → queda pendiente (se reintentará)
       3. Reintenta entradas pendientes de la cola (si las hay)

MediDo (VM 101, contenedor Docker)
  └── POST /api/claude/sesion → guarda en medido.db
  └── GET  /api/claude/resumen → datos agregados para el portal

hogarOS portal
  └── Tarjeta "Asistente IA"
       └── fetch("/salud/api/claude/resumen")
```

**Ventajas de este enfoque:**
- Sin ficheros compartidos entre Windows y la VM
- Funciona desde cualquier equipo (PC de casa, portátil, etc.)
- Funciona offline: los datos nunca se pierden, se sincronizan al volver a la red
- MediDo es la fuente de verdad (su BD ya está respaldada por la política de backup)

---

### Cómo funcionan los hooks de Claude Code

Los hooks se configuran en `~/.claude/settings.json` (global) o `.claude/settings.json` (por proyecto). Ejemplo para el hook `Stop`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "python C:/ruta/claude-tracker.py"
          }
        ]
      }
    ]
  }
}
```

El hook `Stop` recibe por stdin un JSON con información de la sesión, incluyendo uso de tokens. Ejemplo del payload:

```json
{
  "session_id": "abc123",
  "transcript_path": "C:/Users/.../conversation.jsonl",
  "usage": {
    "input_tokens": 15420,
    "output_tokens": 3210,
    "cache_read_input_tokens": 8500,
    "cache_creation_input_tokens": 2100
  }
}
```

> **Nota:** La estructura exacta del payload del hook `Stop` debe verificarse durante la implementación. Los campos de usage pueden variar entre versiones de Claude Code.

---

### Datos que se pueden capturar y calcular

#### Datos directos del hook

| Campo | Fuente |
|---|---|
| `session_id` | Hook payload |
| `fecha_inicio` / `fecha_fin` | Fichero de transcripción (primer y último mensaje) |
| `input_tokens` | Hook payload |
| `output_tokens` | Hook payload |
| `cache_read_tokens` | Hook payload |
| `cache_creation_tokens` | Hook payload |
| `directorio_trabajo` | Variable de entorno `$CWD` en el hook |
| `modelo` | Parsear transcripción o variable de entorno |

#### Datos calculados

| Métrica | Cálculo |
|---|---|
| **Coste estimado (input)** | `input_tokens / 1_000_000 * 3.0` (Sonnet 4.6: $3/Mtok) |
| **Coste estimado (output)** | `output_tokens / 1_000_000 * 15.0` (Sonnet 4.6: $15/Mtok) |
| **Coste estimado (cache read)** | `cache_read_tokens / 1_000_000 * 0.30` ($0.30/Mtok) |
| **Coste estimado (cache creation)** | `cache_creation_tokens / 1_000_000 * 3.75` ($3.75/Mtok) |
| **Coste total sesión** | Suma de los anteriores |
| **Tokens totales día/semana/mes** | Suma agrupada por fecha |
| **Coste acumulado mes** | Suma desde inicio de mes |
| **% del presupuesto** | `coste_mes / presupuesto_configurado * 100` |
| **Duración sesión** | `fecha_fin - fecha_inicio` |
| **Proyecto activo** | Basename del `directorio_trabajo` |

---

### Esquema de base de datos

```sql
-- Sesiones de Claude Code
CREATE TABLE IF NOT EXISTS claude_sesiones (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT UNIQUE NOT NULL,
    fecha_inicio TEXT,
    fecha_fin TEXT NOT NULL DEFAULT (datetime('now')),
    duracion_segundos INTEGER,
    directorio TEXT,
    proyecto TEXT,                    -- basename del directorio
    modelo TEXT DEFAULT 'claude-sonnet-4-6',
    -- Tokens
    input_tokens INTEGER DEFAULT 0,
    output_tokens INTEGER DEFAULT 0,
    cache_read_tokens INTEGER DEFAULT 0,
    cache_creation_tokens INTEGER DEFAULT 0,
    tokens_totales INTEGER GENERATED ALWAYS AS
        (input_tokens + output_tokens + cache_read_tokens + cache_creation_tokens) STORED,
    -- Coste estimado (USD)
    coste_input_usd REAL DEFAULT 0.0,
    coste_output_usd REAL DEFAULT 0.0,
    coste_cache_usd REAL DEFAULT 0.0,
    coste_total_usd REAL GENERATED ALWAYS AS
        (coste_input_usd + coste_output_usd + coste_cache_usd) STORED
);

CREATE INDEX IF NOT EXISTS idx_claude_fecha ON claude_sesiones(fecha_fin);
CREATE INDEX IF NOT EXISTS idx_claude_proyecto ON claude_sesiones(proyecto);
```

---

### Script del hook: `claude-tracker.py`

El script recibe el payload, calcula costes, guarda en cola local y hace POST a MediDo. Si el POST falla (sin red), reintenta las entradas pendientes de la cola en la misma ejecución.

```python
#!/usr/bin/env python3
"""
Hook 'Stop' de Claude Code — envía uso de tokens a MediDo.
Offline-first: guarda en cola local y hace POST. Si falla, reintenta al volver a la red.
Ruta: C:/Users/familiaAlvarezBascon/.claude/claude-tracker.py
"""
import json, sys, os
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import URLError

MEDIDO_URL = "http://192.168.31.131/salud/api/claude/sesion"
COLA_PATH  = Path.home() / ".claude" / "cola_sync.jsonl"

# Precios Claude Sonnet 4.6 (USD por millón de tokens)
PRECIOS = {"input": 3.0, "output": 15.0, "cache_read": 0.30, "cache_creation": 3.75}

def calcular_coste(input_tok, output_tok, cache_read, cache_crea):
    return {
        "coste_input_usd":  input_tok  / 1_000_000 * PRECIOS["input"],
        "coste_output_usd": output_tok / 1_000_000 * PRECIOS["output"],
        "coste_cache_usd":  (cache_read / 1_000_000 * PRECIOS["cache_read"] +
                             cache_crea / 1_000_000 * PRECIOS["cache_creation"]),
    }

def post_a_medido(entrada):
    """Intenta POST a MediDo. Devuelve True si OK, False si sin red."""
    try:
        req = Request(
            MEDIDO_URL,
            data=json.dumps(entrada).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        urlopen(req, timeout=5)
        return True
    except (URLError, OSError):
        return False

def guardar_cola(entrada):
    with open(COLA_PATH, "a", encoding="utf-8") as f:
        f.write(json.dumps({**entrada, "sincronizado": False}) + "\n")

def reintentar_cola():
    """Reenvía entradas pendientes. Reescribe el fichero con las que siguen fallando."""
    if not COLA_PATH.exists():
        return
    pendientes = []
    with open(COLA_PATH, encoding="utf-8") as f:
        for linea in f:
            linea = linea.strip()
            if not linea:
                continue
            entrada = json.loads(linea)
            if not entrada.get("sincronizado"):
                pendientes.append(entrada)
    if not pendientes:
        return
    restantes = []
    for entrada in pendientes:
        payload = {k: v for k, v in entrada.items() if k != "sincronizado"}
        if not post_a_medido(payload):
            restantes.append(entrada)
    with open(COLA_PATH, "w", encoding="utf-8") as f:
        for entrada in restantes:
            f.write(json.dumps(entrada) + "\n")

def main():
    data = json.load(sys.stdin)
    uso  = data.get("usage", {})

    input_tok  = uso.get("input_tokens", 0)
    output_tok = uso.get("output_tokens", 0)
    cache_read = uso.get("cache_read_input_tokens", 0)
    cache_crea = uso.get("cache_creation_input_tokens", 0)

    directorio = os.getcwd()
    entrada = {
        "session_id":          data.get("session_id", "desconocido"),
        "fecha_fin":           datetime.now(timezone.utc).isoformat(),
        "directorio":          directorio,
        "proyecto":            Path(directorio).name,
        "input_tokens":        input_tok,
        "output_tokens":       output_tok,
        "cache_read_tokens":   cache_read,
        "cache_creation_tokens": cache_crea,
        **calcular_coste(input_tok, output_tok, cache_read, cache_crea),
    }

    guardar_cola(entrada)           # 1. Guardar siempre en cola local
    ok = post_a_medido(entrada)     # 2. Intentar POST a MediDo
    if ok:
        reintentar_cola()           # 3. Si hay red, reintentar pendientes anteriores

if __name__ == "__main__":
    main()
```

> **Nota de CRLF:** Si este script se edita en Windows, ejecutar con `python claude-tracker.py` o convertir con `sed -i 's/\r$//' claude-tracker.py` antes de usarlo directamente.

---

### Módulo en MediDo: endpoints de Claude

MediDo añade dos endpoints: uno para recibir sesiones (POST del hook) y otro para exponer el resumen (GET para el portal).

```
POST /api/claude/sesion   ← recibe datos del hook
GET  /api/claude/resumen  ← devuelve datos agregados para el portal
```

```json
{
  "hoy": {
    "sesiones": 3,
    "tokens": 42500,
    "coste_usd": 0.48
  },
  "semana": {
    "sesiones": 12,
    "tokens": 185000,
    "coste_usd": 2.15
  },
  "mes": {
    "sesiones": 38,
    "tokens": 620000,
    "coste_usd": 7.30,
    "presupuesto_usd": 20.0,
    "porcentaje_presupuesto": 36.5,
    "reseteo_estimado": "2026-05-01"
  },
  "ultima_sesion": {
    "proyecto": "hogarOS",
    "fecha": "2026-04-02T18:45:00",
    "tokens": 18200,
    "coste_usd": 0.22
  },
  "por_proyecto": [
    { "proyecto": "hogarOS", "sesiones": 15, "coste_usd": 3.10 },
    { "proyecto": "MediDo",  "sesiones": 10, "coste_usd": 2.40 },
    { "proyecto": "FiDo",    "sesiones":  8, "coste_usd": 1.50 }
  ]
}
```

**Variables de entorno nuevas para MediDo:**

| Variable | Descripción | Ejemplo |
|---|---|---|
| `CLAUDE_PRESUPUESTO_USD` | Presupuesto mensual configurado por el usuario | `20.0` |
| `CLAUDE_DIA_RESETEO` | Día del mes en que se renueva el plan | `1` |

---

### Tarjeta en el portal

Nueva tarjeta "Asistente IA" en `portal/index.html`:

```
┌─────────────────────────────────────┐
│  🤖 Asistente IA                    │
│                                     │
│  Este mes: $7.30 / $20.00  (36%)   │
│  ████████░░░░░░░░░░░░░░  36%        │
│                                     │
│  Hoy: 3 sesiones · 42.5K tokens    │
│  Último: hogarOS · hace 23 min     │
│                                     │
│  Reseteo: en 29 días                │
└─────────────────────────────────────┘
```

Datos mostrados:
- Coste acumulado del mes / presupuesto configurado + barra de progreso
- Sesiones y tokens del día
- Última sesión: proyecto + tiempo transcurrido
- Días hasta el próximo reseteo

---

### Flujo completo de la información

```
Claude Code termina sesión (cualquier equipo, dentro o fuera de la red)
  └── Hook "Stop" → claude-tracker.py
       ├── Guarda en cola local: ~/.claude/cola_sync.jsonl
       ├── Intenta POST → http://192.168.31.131/salud/api/claude/sesion
       │    ├── En red local: OK, MediDo guarda en medido.db
       │    └── Sin red: falla silenciosamente, dato queda en cola
       └── Si hay red: reintenta entradas pendientes de la cola

hogarOS Nginx
  └── POST /salud/api/claude/sesion → proxifica a medido:8084/api/claude/sesion
  └── GET  /salud/api/claude/resumen → proxifica a medido:8084/api/claude/resumen

portal/index.html
  └── Tarjeta "Asistente IA" → fetch("/salud/api/claude/resumen")
```

---

### Lo que se puede mostrar vs. lo que no

| Métrica | Disponible | Cómo |
|---|---|---|
| Tokens por sesión | ✅ | Hook `Stop` |
| Coste estimado | ✅ | Calculado con precios oficiales |
| Sesiones del día/semana/mes | ✅ | Agrupación en SQLite |
| Proyecto más activo | ✅ | Directorio de trabajo del hook |
| % del presupuesto | ✅ | Con presupuesto configurado manualmente |
| Fecha de reseteo | ✅ (aproximada) | Día del mes configurado manualmente |
| Límite real del plan Pro | ❌ | Anthropic no lo expone via API |
| Sesiones de Claude.ai web | ❌ | Sin API oficial |
| Histórico antes de activar el hook | ❌ | Solo desde que se instala el hook |

---

### Pasos de implementación

| Paso | Qué | Dónde | Esfuerzo |
|---|---|---|---|
| 1 | Crear `claude-tracker.py` con cola offline + POST | Windows: `~/.claude/` | Bajo |
| 2 | Configurar hook `Stop` en `~/.claude/settings.json` | Windows | Bajo |
| 3 | Verificar que el hook funciona (test manual: terminar sesión y revisar cola) | Test | Bajo |
| 4 | Añadir tabla `claude_sesiones` a MediDo + endpoint `POST /api/claude/sesion` | MediDo | Bajo-medio |
| 5 | Añadir endpoint `GET /api/claude/resumen` a MediDo | MediDo | Bajo |
| 6 | Añadir rutas `/salud/api/claude/` en `nginx.conf` | hogarOS | Bajo |
| 7 | Añadir tarjeta "Asistente IA" en `portal/index.html` | hogarOS | Bajo |
| **Total** | | | **Bajo-medio** |

---

## 4. Otras mejoras aparcadas (no descartadas)

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

## 6. Propuestas de evolución del ecosistema

> Ideas candidatas para próximas fases de hogarOS y aplicaciones satélite.
> No son tareas comprometidas todavía; sirven como cartera de evolución para discutir
> y priorizar antes de pasarlas a `roadmap.md`.

### 6.1 FiDo — Sistema serio de transferencias internas

**Problema:** las transferencias entre cuentas propias duplican ingresos y gastos cuando los informes agregan todas las cuentas.

**Propuesta:** modelar explícitamente las transferencias internas, con relación entre movimiento origen y movimiento destino. Una transferencia interna no debería contar como ingreso/gasto real en informes operativos, aunque sí debe conservarse en el histórico contable.

**Cómo podría hacerse:**
- Campo o tabla específica para marcar movimientos como `transferencia_interna`.
- Vinculación opcional entre dos movimientos por importe, fecha cercana y cuentas distintas.
- Exclusión automática de informes de gastos/ingresos cuando el movimiento esté conciliado.
- Vista de revisión para confirmar emparejamientos dudosos.

**Valor:** corrige la base de lectura financiera y evita decisiones basadas en datos inflados.

### 6.2 FiDo — Presupuesto mensual por categoría

**Problema:** FiDo muestra lo gastado, pero todavía no contrasta contra límites definidos.

**Propuesta:** permitir presupuestos mensuales por categoría padre o subcategoría. El panel y la portada podrían mostrar el consumo del presupuesto en porcentaje.

**Cómo podría hacerse:**
- Tabla `presupuestos` con categoría, importe, mes de inicio y activo.
- Endpoint de resumen presupuestario.
- Alertas cuando una categoría supere el 75%, 90% y 100%.
- Tarjeta compacta en hogarOS: categorías en riesgo del mes.

**Valor:** convierte FiDo en una herramienta de control, no solo de registro.

### 6.3 FiDo — Movimientos recurrentes y suscripciones

**Problema:** los gastos fijos se mezclan con los variables y cuesta saber qué parte del mes ya está comprometida.

**Propuesta:** detectar movimientos recurrentes como hipoteca, seguros, suscripciones, Internet, móvil, colegio o servicios digitales.

**Cómo podría hacerse:**
- Detección por descripción similar, importe parecido y periodicidad mensual/anual.
- Marca `recurrente` y grupo de recurrencia.
- Vista de “gasto fijo mensual”.
- Aviso si una suscripción sube de precio o aparece duplicada.

**Valor:** separa gasto fijo y gasto variable, una de las lecturas más útiles para finanzas domésticas.

### 6.4 hogarOS — Briefing diario del hogar

**Problema:** el portal tiene tarjetas útiles, pero no una síntesis diaria accionable.

**Propuesta:** crear una sección “Hoy” o “Briefing” con el parte de situación: salud del sistema, backup, alertas, gasto del mes, dispositivos nuevos, próximas tareas o anomalías.

**Cómo podría hacerse:**
- Endpoint agregador en `hogar-api` o composición directa en el frontend.
- Reglas simples primero: no hace falta IA para la v1.
- Texto corto, priorizado y con enlaces a cada módulo.

**Valor:** reduce el tiempo de inspección: en un vistazo se sabe qué requiere atención.

### 6.5 hogarOS / MediDo — Estado real de backups con detalle

**Problema:** la tarjeta de backup indica antigüedad, pero el diagnóstico puede ser más rico.

**Propuesta:** convertir el resultado del backup en datos estructurados: duración, tamaño, destino, dumps OK/error, VMs incluidas, ruta del manifiesto y último error.

**Cómo podría hacerse:**
- Hacer que `backup.sh` genere un JSON además de `MANIFIESTO.txt`.
- `hogar-api` expone ese JSON vía `/api/backup`.
- Portal muestra estado resumido y enlace a detalle.
- MediDo puede alertar por fallos concretos, no solo por antigüedad.

**Valor:** aumenta la confianza en la recuperación, que es lo que de verdad importa en backups.

### 6.6 MediDo — Panel de degradación, no solo caídas

**Problema:** un servicio puede estar “vivo” pero ir cada vez peor.

**Propuesta:** detectar degradación por latencia, errores intermitentes o consumo anómalo antes de que haya caída total.

**Cómo podría hacerse:**
- Guardar línea base de latencia por servicio.
- Alertar si un servicio supera varias veces su media histórica.
- Detectar patrones horarios: picos recurrentes, backups, tareas cron.
- Vista de “servicios degradados”.

**Valor:** permite anticiparse a problemas en lugar de reaccionar cuando algo ya se ha roto.

### 6.7 ReDo — Mapa de presencia familiar/doméstica

**Problema:** ReDo ya guarda presencia, pero puede evolucionar de dato técnico a lectura doméstica.

**Propuesta:** vista de patrones de presencia por dispositivos principales: horarios habituales, ausencias raras, dispositivos IoT que desaparecen, actividad nocturna sospechosa.

**Cómo podría hacerse:**
- Marcar dispositivos principales del hogar.
- Resumen diario/semanal de primera y última presencia.
- Detección de presencia fuera de patrón.
- Vista por zonas y tipos usando los datos ya existentes.

**Valor:** aprovecha una capacidad ya implementada y la convierte en información útil.

### 6.8 hogarOS — Centro de Alertas 2.0

**Problema:** el centro de alertas unifica avisos, pero puede crecer hacia gestión real.

**Propuesta:** añadir severidad, agrupación, silenciado temporal, histórico por módulo y reglas de escalado.

**Cómo podría hacerse:**
- Campos estándar: severidad, origen, recurso afectado, silenciada_hasta.
- Acción “silenciar 24h”.
- Agrupar alertas repetidas en una sola entrada con contador.
- Filtro por módulo, severidad y estado.

**Valor:** evita ruido y mejora la capacidad de respuesta cuando haya más módulos.

### 6.9 Kryptonite — Integración Revolut X

**Problema:** las recompensas de staking de DOT y ADA requieren registro manual o quedan fuera de la cartera.

**Propuesta:** implementar la integración con Revolut X para importar recompensas automáticamente hacia la tabla `operaciones`.

**Cómo podría hacerse:**
- Autenticación Ed25519.
- Módulo `app/revolut_x.py`.
- Endpoint `/revolut/sincronizar`.
- Carga histórica inicial y flujo semanal en Node-RED.

**Valor:** mejora la calidad de datos del portfolio y reduce trabajo manual.

### 6.10 Nueva app — Inventario doméstico ligero

**Problema:** información doméstica útil como garantías, números de serie, manuales o fechas de compra suele estar dispersa.

**Propuesta:** crear una app sencilla de inventario del hogar: electrodomésticos, dispositivos, garantías, coste, ubicación, manuales y próxima revisión.

**Cómo podría hacerse:**
- FastAPI + SQLite + frontend vanilla.
- Entidades: objeto, categoría, ubicación, fecha de compra, garantía, documento asociado.
- Integración con hogarOS mediante tarjeta de resumen.
- Relación futura con ReDo para dispositivos detectados en red.

**Valor:** encaja con la filosofía hogarOS: convertir información doméstica dispersa en gestión tranquila y accesible.

---

## Orden global de implementación

| Prioridad | Mejora | Proyecto | Esfuerzo | Valor | Estado |
|---|---|---|---|---|---|
| 1 | Tipo y zona | ReDo | Bajo-medio | Alto | **Completado** (2026-03-26) |
| 2 | Presencia + detalle | ReDo | Medio | Alto | **Completado** (2026-03-26) |
| 3 | Auto-detección tipo | ReDo | Bajo | Medio | **Completado** (2026-03-26) |
| 4 | MediDo (Proxmox API) | Nueva app + hogarOS | Medio-alto | Muy alto | **Completado** (2026-03-27) |
| 5 | Estandarizar drawers | ReDo + FiDo + MediDo | Bajo | Medio | **Completado** (2026-03-27) |
| 6 | Centro de Alertas | hogarOS + ReDo + MediDo | Medio | Alto | Pendiente |
| 7 | Monitor de uso de Claude | Windows hook + MediDo + hogarOS | Bajo-medio | Medio | Pendiente |
