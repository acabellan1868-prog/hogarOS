# HogarOS — Hoja de ruta

> Estado actual: Fase 10 completa (código). Nuevo header drawer + ApexCharts + fix enlaces subidos a GitHub.
> Pendiente: ejecutar `actualizar.sh` en la VM para desplegar y verificar en producción.
> Última actualización: 2026-03-21 (noche)

### Leyenda

| Icono | Significado |
|-------|-------------|
| 🤖 | Tarea de Claude (código, configuración, documentación) |
| 👤 | Tarea manual (requiere acceso a GitHub, VM, móvil, etc.) |

---

## Fase 0 — Preparación de repositorios

- [x] 👤 Crear repositorio `ReDo` en GitHub (`acabellan1868-prog/ReDo`)
- [x] 👤 Verificar que el repositorio `FiDo` está actualizado en GitHub ✅

> **Nota:** El código actual de ReDo (`network-monitor/`) es una versión muy básica sin Docker ni frontend.
> Se construye desde cero en la Fase 1. Sirve solo como referencia de la lógica de escaneo existente.

---

## Fase 1 — ReDo: construcción desde cero ✅

ReDo construido como app completa e independiente. Completado 2026-03-15.

### Estructura final
```
ReDo/
├── app/
│   ├── principal.py     ← FastAPI app
│   ├── escaner.py       ← lógica de escaneo con python-nmap
│   ├── notificador.py   ← integración NTFY
│   ├── modelos.py       ← modelos Pydantic
│   ├── bd.py            ← acceso a SQLite
│   ├── config.py        ← configuración
│   ├── esquema.sql      ← esquema de la BD
│   └── rutas/
│       ├── resumen.py
│       ├── dispositivos.py
│       └── escaneos.py
├── static/index.html    ← frontend
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
└── README.md
```

### Tareas
- [x] 🤖 Definir y crear la estructura del proyecto
- [x] 🤖 Migrar/reescribir la lógica de escaneo existente
- [x] 🤖 Integrar notificaciones via NTFY (topic: `hogaros-3ca6f61b`)
- [x] 👤 Suscribirse al topic `hogaros-3ca6f61b` en la app NTFY del móvil
- [x] 🤖 Implementar escaneos periódicos con APScheduler
- [x] 🤖 Crear frontend propio (aplicando el design system de hogarOS)
- [x] 🤖 Dockerizar la aplicación
- [x] 🤖 Implementar `GET /api/resumen` que devuelva:
  ```json
  {
    "dispositivos_activos": 12,
    "dispositivos_confiables": 11,
    "dispositivos_desconocidos": 1,
    "ultimo_escaneo": "2026-03-13T18:30:00"
  }
  ```
- [x] 🤖 Verificar que el endpoint responde correctamente
- [ ] 👤 Probar la app de forma independiente antes de integrar en hogarOS

## Fase 2 — FiDo: endpoint de resumen ✅

FiDo ya está en Docker y funcionando. Endpoint añadido. Completado 2026-03-16.

### FiDo
- [x] 🤖 Implementar `GET /api/resumen` que devuelva:
  ```json
  {
    "mes": "Marzo 2026",
    "ingresos": 2100.00,
    "gastos": 1258.50,
    "balance": 841.50
  }
  ```
- [x] 🤖 Verificar que el endpoint responde correctamente

---

## Fase 3 — Design System (hogar.css) ✅

Completado 2026-03-16.

- [x] 🤖 Crear `portal/static/hogar.css` con todas las variables CSS del design system:
  - Paleta Índigo y Arena (modo claro y oscuro)
  - Tipografía System UI
  - Variables de border-radius, espaciado, sombras
- [x] 🤖 Crear componentes base documentados:
  - Header con navegación entre apps
  - Tarjeta de módulo
  - Botones (primario y secundario)
  - Alerta / notificación
  - Toggle claro/oscuro

---

## Fase 4 — Portal HTML ✅

Completado 2026-03-16.

- [x] 🤖 Crear `portal/index.html` con la estructura principal:
  - Header con logo hogarOS y navegación
  - Grid de tarjetas de módulos
  - Feed de alertas unificado
  - Sección de accesos rápidos
- [x] 🤖 Tarjeta ReDo: consumir `/api/resumen` de ReDo y mostrar datos en tiempo real
- [x] 🤖 Tarjeta FiDo: consumir `/api/resumen` de FiDo y mostrar datos en tiempo real
- [x] 🤖 Tarjeta Home Assistant: enlace directo (Nivel 1)
- [x] 🤖 Implementar toggle claro/oscuro con persistencia en localStorage
- [x] 🤖 Manejo de errores: mostrar estado "sin conexión" si una app no responde

---

## Fase 5 — Infraestructura ✅

Completado 2026-03-17.

### Nginx
- [x] 🤖 Crear `nginx.conf` con las reglas de reverse proxy:
  - `/` → portal HTML estático
  - `/red/` → ReDo (host.docker.internal:8083)
  - `/finanzas/` → FiDo (fido:8080 red Docker interna)
  - `/static/` → ficheros compartidos (hogar.css, etc.)
- [x] 🤖 Añadir `sub_filter` para reescribir rutas absolutas en HTML/JS de las apps

### Docker Compose
- [x] 🤖 Crear `docker-compose.yml` con los tres servicios:
  - `hogar-portal` (Nginx + extra_hosts para alcanzar host)
  - `redo` (build desde /mnt/datos/redo-build, network_mode: host)
  - `fido` (build desde /mnt/datos/fido-build, puerto 8082:8080)
- [x] 🤖 Configurar variables de entorno y volúmenes
- [x] 🤖 Configurar reinicio automático (`restart: unless-stopped`)
- [x] 👤 Verificar comunicación entre contenedores

### Ajustes de despliegue
- [x] 🤖 Cambiar ReDo de puerto 8081 a 8083 (conflicto con Nextcloud)
- [x] 🤖 Hacer puerto de ReDo configurable via variable `REDO_PORT`
- [x] 🤖 FiDo: autodetectar prefijo en api.js para funcionar bajo reverse proxy
- [x] 🤖 FiDo: rutas relativas en index.html (estilos.css, api.js, app.js)
- [x] 🤖 Portal: corregir URL de Home Assistant (192.168.31.132:8123)
- [x] 👤 Eliminar stack FiDo de Portainer (ahora lo gestiona hogarOS)

### Despliegue en VM 101 (Debian 12)

```
/mnt/datos/
├── fido-build/        ← código FiDo        ✅
├── fido/              ← datos FiDo (fido.db) ✅
├── hogarOS/           ← código hogarOS      ✅
├── redo-build/        ← código ReDo         ✅
└── redo/              ← datos ReDo          ✅
```

- [x] 👤 Clonar hogarOS en `/mnt/datos/hogarOS/`
- [x] 👤 Clonar redo en `/mnt/datos/redo-build/`
- [x] 👤 Crear `/mnt/datos/redo/` para datos persistentes
- [x] 🤖 Mejorar `actualizar.sh`: pull + down + build + up en un solo comando
- [x] 👤 Ejecutar `docker compose up -d` desde `/mnt/datos/hogarOS/`
- [x] 👤 Probar acceso desde la red local: `http://192.168.31.131` ✅

---

## Fase 6 — Pulido y estabilización ✅

Completado 2026-03-17.

- [x] 👤 Probar en móvil (diseño responsive) ✅
- [x] 🤖 Ajustar tiempos de refresco de los widgets (60s, adecuado para uso doméstico)
- [x] 🤖 Documentar en README cómo añadir una nueva app al portal
- [x] 🤖 Actualizar README con captura real del portal en funcionamiento

---

## Fase 7 — Estrategia de backups

Prioridad inmediata tras el despliegue. No solo bases de datos — backup integral de todo el entorno.

### Alcance

| Qué | Cómo | Frecuencia prevista |
|-----|------|---------------------|
| VMs Proxmox | Snapshots/backups programados de Proxmox | Semanal |
| Volúmenes Docker (`/mnt/datos/`) | Script de copia a destino externo (NAS, disco, nube) | Diario |
| Bases de datos SQLite | `sqlite3 <db> ".backup <destino>"` | Diario |
| Código fuente | Ya en GitHub (repos) | Automático con cada push |

### Tareas
- [ ] 🤖 Diseñar estrategia de backup integral
- [ ] 🤖 Crear script de backup automatizado para volúmenes y bases de datos
- [ ] 👤 Configurar backups programados de VMs en Proxmox
- [ ] 👤 Definir destino de los backups (NAS, disco externo, nube)
- [ ] 👤 Programar cron de ejecución del script de backup
- [ ] 👤 Verificar restauración de un backup (prueba de recuperación)

---

## Fase 8 — Lanzador de aplicaciones

Reemplaza Dashy como lanzador, liberando un contenedor Docker. Ver `analisis.md` para el análisis completo.

- [x] 🤖 Crear `portal/lanzador.html` con los grupos de enlaces de Dashy migrados:
  - Servicios Externos (ChatGPT, Grok, Gemini, Claude, TailScale)
  - PRODUCCIÓN Dell 7050 (ProxMox, Portainer, Heimdall, HA, NodeRed, NextCloud, Jupyter, N8N, Planka, DockMon, FiDo, hogarOS)
  - DESARROLLO (ProxMox, Portainer, NodeRed, MLDonkey, HA, Heimdall)
- [x] 🤖 Iconos vía Simple Icons CDN y Homarr icons CDN
- [x] 🤖 Enlazar el lanzador desde el header del portal principal
- [x] 👤 Verificar que todos los enlaces funcionan correctamente
- [x] 👤 Dar de baja el contenedor de Dashy en Docker

### Gestión dinámica (Fase 8b)
- [x] 🤖 Crear `hogar-api/` — microservicio FastAPI con `GET /api/lanzador` y `PUT /api/lanzador`
- [x] 🤖 Refactorizar `portal/lanzador.html` para cargar config desde la API
- [x] 🤖 Crear `portal/admin-lanzador.html` — CRUD de grupos y enlaces sin tocar código
- [x] 🤖 Actualizar `nginx.conf` — nueva ruta `/api/lanzador` → `hogar-api`
- [x] 🤖 Actualizar `docker-compose.yml` — nuevo servicio `hogar-api`
- [x] 👤 Crear `/mnt/datos/hogar-api/` en la VM y ejecutar `actualizar.sh`
- [x] 👤 Dar de baja el contenedor de Dashy en Docker

### Mejoras futuras del lanzador
- [ ] 🤖 Status check server-side (proxy nginx o endpoint backend) para evitar problemas de CORS

---

## Fase 9 — Integración de Kryptonite

Tarjeta de crypto portfolio en el dashboard, consumiendo la API de Kryptonite (Flask, puerto 5000, JupyterLab).

- [x] 🤖 Añadir tarjeta "Crypto Portfolio" en `portal/index.html`
- [x] 🤖 Consumir `GET /portafolio` de Kryptonite (tabla con 6 cryptos, totales, rentabilidad)
- [x] 🤖 Añadir proxy en `nginx.conf`: `/crypto/api/` → `host.docker.internal:5000`
- [x] 👤 Ejecutar `actualizar.sh` en la VM y verificar que muestra datos reales ✅

### Fase 9b — Gráfica comparativa 24h (2026-03-19)

- [x] 🤖 Clonar repo `acabellan1868-prog/kryptonite` para explorar la API
- [x] 🤖 Añadir tarjeta "Crypto Comparativa 24h" en `portal/index.html`
- [x] 🤖 Consumir `GET /grafica24h` (sin parámetros) → imagen PNG base64 con comparativa de todo el portafolio
- [x] 🤖 Separar intervalos de refresco: datos operacionales 60s, tarjetas crypto 10 minutos
- [x] 👤 Ejecutar `actualizar.sh` en la VM y verificar ✅

### Fase 9c — Crypto integrado en FiDo (2026-03-19) ✅

- [x] 🤖 Mover tarjetas crypto del portal hogarOS a FiDo (nueva pestaña "₿ Crypto")
- [x] 🤖 FiDo: tabla de portfolio con inversión, valor actual y rentabilidad por moneda + totales en pie de tabla
- [x] 🤖 FiDo: gráfica comparativa 24h cargada en segundo plano (no bloquea la tabla)
- [x] 🤖 FiDo: estado "⏳ Cargando..." visible al entrar en la pestaña + mensaje de error si Kryptonite no responde
- [x] 🤖 FiDo: cache-busting en `api.js` y `app.js` (`?v=2`) para forzar recarga tras despliegue
- [x] 🤖 Portal hogarOS: mini-resumen crypto en tarjeta "Finanzas Domésticas" (₿ inv → valor € ▼ %)
- [x] 🤖 Portal hogarOS: limpieza de CSS y JS de las tarjetas crypto eliminadas
- [x] 👤 Verificado en producción: tabla y gráfica visibles ✅

---

## Fase 10 — Rediseño visual "Living Sanctuary" (2026-03-20)

Cambio completo de la capa visual de todo el ecosistema. Solo diseño, sin cambios funcionales.

### Design system
| Aspecto | Antes (Índigo y Arena) | Después (Living Sanctuary) |
|---------|------------------------|----------------------------|
| Paleta | Índigo `#6C63A8` + Arena `#F5F0E8` | Teal `#1a6a60` + Pasteles (mint, blush, dusk) |
| Tipografía | System UI | Plus Jakarta Sans + Be Vietnam Pro |
| Iconos | Emojis | Material Symbols Outlined |
| Bordes | 4px, con líneas 1px | Redondeados grandes (1-3rem), sin líneas |
| Header | Barra sólida oscura sticky | Barra flotante glassmorphic con blur |
| Tarjetas | Fondo plano + borde 1px | Fondos semi-transparentes + sombras ambient |
| Framework CSS | CSS puro (variables) | CSS variables + clases utilitarias |

### Tareas
- [x] 🤖 Paso 1: Reescribir `hogar.css` con paleta Living Sanctuary (modo claro + oscuro), tipografías, formas orgánicas, glassmorphism, componentes compartidos
- [x] 🤖 Paso 2: Rediseñar `portal/index.html` — header flotante, tarjetas orgánicas, layout bento (mismo contenido y JS)
- [x] 🤖 Paso 3: Rediseñar `portal/lanzador.html` — grid de blobs orgánicos, misma carga desde API
- [x] 🤖 Paso 4: Rediseñar `ReDo/static/index.html` — aplicar design system, cargar hogar.css via proxy
- [x] 🤖 Paso 5: Rediseñar `FiDo/static/index.html` — adaptar a Living Sanctuary (variables CSS, header, tarjetas, colores accent)
- [x] 👤 Ejecutar `actualizar.sh` en la VM y verificar en producción ✅

### Fix nginx — sub_filter y hogar.css (2026-03-21)

Al desplegar el rediseño de ReDo se detectó que `hogar.css` no cargaba.
Causa: el `sub_filter` reescribe `/static/hogar.css` → `/red/static/hogar.css`,
pero no había `location` block para esa ruta → nginx la proxificaba a ReDo → 404.

- [x] 🤖 Añadir `location /red/static/` en `nginx.conf` → sirve desde `portal/static/`
- [x] 🤖 Añadir `location /finanzas/static/` en `nginx.conf` → mismo fix preventivo para FiDo

### Documentación del ecosistema (2026-03-21)

- [x] 🤖 Crear `CLAUDE.md` en `hogarOS/` — estructura completa del ecosistema, arquitectura nginx, flujo de despliegue, design system
- [x] 🤖 Crear `CLAUDE.md` en `ReDo/` — estructura interna, API, integración con hogarOS
- [x] 🤖 Crear `CLAUDE.md` en `FiDo/` — estructura interna, API, parsers bancarios

### Migración de Chart.js a ApexCharts (2026-03-21)

Chart.js (canvas) fallaba al calcular dimensiones dentro de CSS Grid a pantalla completa.
En móvil funcionaba pero en PC no se renderizaban las gráficas.

- [x] 🤖 Reemplazar Chart.js por ApexCharts (SVG) en FiDo — gráficas de categoría (donut) y evolución mensual (bar)
- [x] 👤 Verificado en producción ✅

### Nuevo header: Floating Glass Dock (2026-03-21)

Reemplaza la navegación horizontal del header por un drawer lateral glassmorphic,
siguiendo el diseño de `stitch (6)`. El botón hamburguesa abre un panel que desliza
desde la derecha con overlay, cierre por Escape/click fuera.

- [x] 🤖 `hogar.css`: botón menú (`.hogar-header__menu-btn`), drawer lateral (`.hogar-drawer` reescrito), overlay (`.hogar-drawer-overlay`), items del drawer (`.hogar-drawer__enlace`)
- [x] 🤖 `portal/index.html`: drawer con Inicio, Red, Finanzas, Domótica, Lanzador + Cambiar tema
- [x] 🤖 `portal/lanzador.html`: mismo drawer, Lanzador como activo
- [x] 🤖 `FiDo/static/index.html`: 7 pestañas pasan al drawer (integrado con Alpine.js), cierre auto al seleccionar. Toggle tema añadido
- [x] 🤖 `ReDo/static/index.html`: drawer con Red, Ir al Portal, Finanzas. Toggle tema añadido
- [x] 🤖 Fix enlaces cruzados: `href="/"` era reescrito por `sub_filter` de nginx → usar `window.location.origin` en FiDo y ReDo
- [ ] 👤 Ejecutar `actualizar.sh` en la VM y verificar en producción

### Referencia de diseño
- Diseños en `diseño/stitch (6)/` (dashboard) y `diseño/stitch (7)_lanzador (3)/` (lanzador)
- Especificación completa: `diseño/stitch (6)/DESIGN.md`
- Carpeta `diseño/` excluida del repo (`.gitignore`)

---

## Fase 11 — Futuro (sin fecha)

- [x] 🤖 **Home Assistant Nivel 2**: widget con datos reales via API REST de HA (completado 2026-03-17)
  - [x] Temperatura exterior (actual + max/min, Meteoclimatic)
  - [x] Temperaturas interiores por habitación (Xiaomi Aqara + MQTT)
  - [x] Luces/enchufes activos (conteo encendidos)
  - [ ] Estado alarma
  - [ ] Consumo eléctrico
- [ ] 🤖 Módulo Inventario del hogar
- [ ] 🤖 Módulo Tareas domésticas compartidas
- [ ] 🤖 Notificaciones push en el portal
- ~~Self-hosting de ntfy en la VM~~ — Descartado: ntfy.sh público es suficiente y evita depender de Tailscale

---

## Resumen de dependencias entre fases

```
Fase 0 (repos)
    ↓
Fase 1 (ReDo desde cero)  +  Fase 2 (FiDo /api/resumen)  +  Fase 3 (CSS)
                              ↓
                    Fase 4 (Portal HTML)
                              ↓
                    Fase 5 (Infraestructura)
                              ↓
                    Fase 6 (Pulido)
                              ↓
                    Fase 7 (Backups)  ← prioridad post-despliegue
                              ↓
                    Fase 8 (Lanzador)
                              ↓
                    Fase 9 (Kryptonite)
                              ↓
                    Fase 10 (Rediseño visual)
                              ↓
                    Fase 11 (Futuro)
```
