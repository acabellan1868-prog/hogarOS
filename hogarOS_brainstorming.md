# HogarOS — Brainstorming y definición del proyecto

> Documento vivo. Todo lo que se define en las sesiones de trabajo se añade aquí.
> Última actualización: 2026-03-15 (sesión 4)

---

## Idea y origen

Durante el desarrollo de **ReDo** (red doméstica) y teniendo ya en funcionamiento **FiDo** (gestión de finanzas domésticas), surgió la idea de unificar ambas herramientas en un único portal accesible desde la red local.

En lugar de recordar distintas IPs y puertos (`192.168.31.131:3000` para la red, `192.168.31.131:8080` para finanzas), un portal central tipo _home dashboard_ concentra todo bajo una única URL y ofrece una visión global del estado del hogar.

---

## Arquitectura

```
Usuario → http://192.168.31.131
              │
              ▼
           Nginx (80)
           ├── /          → Portal (inicio con widgets)
           ├── /red/      → ReDo
           └── /finanzas/ → FiDo
```

Cada aplicación mantiene su **independencia total** — pueden desplegarse y actualizarse por separado. El portal solo agrega sus APIs para mostrar resúmenes.

---

## Módulos integrados

### ReDo (Red Doméstica)
- **Stack:** Node.js 20, nmap
- **Repositorio:** `acabellan1868-prog/redo`
- **Función:** Escaneo periódico de la red local (192.168.31.0/24), detección de dispositivos desconocidos, gestión de dispositivos conectados, alertas via NTFY
- **Datos que expone al portal:**
  - Nº de dispositivos activos
  - Nº de dispositivos confiables
  - Nº de dispositivos desconocidos (alertas)
  - Timestamp del último escaneo

### FiDo
- **Stack:** Python 3.12, FastAPI, SQLite
- **Repositorio:** `acabellan1868-prog/FiDo`
- **Función:** Gestión de finanzas domésticas — importación de extractos bancarios (CaixaBank, Revolut, Santander), categorización automática, panel de movimientos
- **Datos que expone al portal:**
  - Ingresos del mes actual
  - Gastos del mes actual
  - Balance
  - Últimos movimientos importados

---

## Página de inicio del portal

La página principal (`/`) muestra:

### 1. Tarjetas de módulos
Cada app tiene una tarjeta con sus métricas clave en tiempo real (obtenidas vía sus APIs). Un click en "Abrir →" lleva a la interfaz completa de la app.

### 2. Feed de alertas unificado
Un único listado cronológico con eventos de todas las apps:
- Dispositivos desconocidos detectados en la red (también notificados via NTFY)
- Nuevos movimientos importados en FiDo
- Confirmaciones de escaneos sin incidencias

### 3. Accesos rápidos
Botones de acción frecuente sin necesidad de entrar a cada app:
- Lanzar escaneo de red
- Clasificar dispositivos pendientes
- Importar extracto bancario
- Ver informe mensual

---

## Estructura de repositorios

**Decisión tomada: repos totalmente independientes, sin submodules ni subcarpetas**

Cada app vive en su propio repo y tiene su propio ciclo de vida. hogarOS **no contiene código de las otras apps** — solo sabe dónde están (IP/puerto) para redirigir tráfico y consultar sus APIs.

```
acabellan1868-prog/
├── hogarOS       ← portal + nginx + docker-compose
├── redo          ← app independiente (pendiente crear repo en GitHub)
└── FiDo          ← app independiente (ya existe)
```

El repo hogarOS solo contiene:
```
hogarOS/
├── portal/              ← Frontend del dashboard (HTML/CSS/JS vanilla)
├── nginx.conf           ← Config del reverse proxy
├── docker-compose.yml   ← Referencias a imágenes externas, no builds locales
├── README.md
└── roadmap.md
```

---

## Contrato entre apps y portal (API REST)

Cada app expone un endpoint `/api/resumen` que hogarOS consume para el dashboard. Si se quieren mostrar más datos, se amplía el endpoint de la app correspondiente — hogarOS no cambia su arquitectura.

```
ReDo  →  GET /api/resumen  →  { dispositivos, alertas, ultimo_escaneo }
FiDo  →  GET /api/resumen  →  { ingresos, gastos, balance, mes }
```

Añadir una nueva app al portal en el futuro:
1. La nueva app expone `/api/resumen`
2. Añadir una línea en `nginx.conf`
3. Añadir una tarjeta en el portal HTML

---

## Contenedores

Un contenedor por servicio, orquestados con docker-compose. Cada contenedor es independiente — FiDo puede correr sin hogarOS, igual que lo hace ahora.

```
Sin hogarOS:  192.168.31.131:8080  → FiDo   ✅
              192.168.31.131:3000  → ReDo   ✅

Con hogarOS:  192.168.31.131/           → Portal  ✅
              192.168.31.131/finanzas/  → FiDo    ✅
              192.168.31.131/red/       → ReDo    ✅
```

Si hogarOS cae, las apps siguen funcionando — solo se pierde el portal central.

---

## docker-compose.yml propuesto

El compose de hogarOS referencia imágenes ya construidas de cada app (no hace build del código fuente):

```yaml
services:

  nginx:
    image: nginx:alpine
    container_name: hogar-portal
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./portal:/usr/share/nginx/html:ro
    restart: unless-stopped

  redo:
    image: ghcr.io/acabellan1868-prog/redo:latest
    container_name: redo
    network_mode: host
    cap_add:
      - NET_RAW
      - NET_ADMIN
    environment:
      - TZ=Europe/Madrid
    restart: unless-stopped

  fido:
    image: ghcr.io/acabellan1868-prog/fido:latest
    container_name: fido
    volumes:
      - /mnt/datos/fido:/app/data
    environment:
      - TZ=Europe/Madrid
      - FIDO_DB_PATH=/app/data/fido.db
    restart: unless-stopped
```

> **Nota:** ReDo usa `network_mode: host` para ARP scans en la LAN. Se comunica con Nginx a través de `localhost`.

---

## Pendientes (próximos pasos)

- [ ] Crear repositorio `redo` en GitHub
- [ ] Construir portal HTML con widgets reales (consumiendo las APIs de cada app)
- [ ] Añadir endpoint `/api/resumen` en ReDo (ya tiene `/api/estado`)
- [ ] Añadir endpoint `/api/resumen` en FiDo (resumen del mes actual)
- [ ] Configurar Nginx como reverse proxy
- [ ] Adaptar `docker-compose.yml` con los tres servicios
- [ ] Desplegar en Proxmox y verificar comunicación entre contenedores

---

## Integración con Home Assistant

El usuario ya tiene Home Assistant en funcionamiento para domótica. No se duplica — se integra.

### Estrategia: dos niveles

**Nivel 1 — Enlace directo (fase inicial)**
La tarjeta "Domótica" en el dashboard simplemente enlaza a Home Assistant. Cero trabajo técnico, integración inmediata.

**Nivel 2 — Widget con datos reales (fase futura)**
hogarOS consulta la API REST de Home Assistant para mostrar un resumen en el dashboard:
```
HA API → GET /api/states  →  { temperatura, luces_encendidas, alarma, ... }
```
La tarjeta mostraría datos clave (temperatura salón, luces activas, estado alarma) y el click lleva a HA para el control completo.

### Plan
- **Ahora:** Nivel 1 — enlace directo a Home Assistant
- **Futuro:** Nivel 2 — widget con datos via API REST de HA (muy fácil de consumir cuando llegue el momento)

### Datos candidatos para el widget HA
- Temperatura interior (salón u otras estancias)
- Nº de luces / enchufes encendidos
- Estado de la alarma
- Consumo eléctrico en tiempo real

---

## Notificaciones — NTFY

### Decisión tomada

Se usa **NTFY** como sistema de notificaciones push para el móvil. Cada app publica en un topic compartido y el usuario se suscribe desde la app NTFY en el móvil.

### Configuración

| Parámetro | Valor |
|-----------|-------|
| Servidor | `ntfy.sh` (público) |
| Topic | `hogaros-alertas` |
| URL completa | `https://ntfy.sh/hogaros-alertas` |

### Uso actual
- **ReDo** publica alertas de dispositivos desconocidos detectados en la red y resultados de escaneos

### Uso futuro
- **FiDo** podría publicar alertas de presupuesto superado, movimientos sospechosos, etc.
- Cualquier nueva app del ecosistema usa el mismo topic, identificándose con un título/tag distinto

### Suscripción en el móvil
1. Instalar la app **NTFY** (Android/iOS)
2. Suscribirse al topic `hogaros-alertas`
3. Recibir notificaciones push de todas las apps de hogarOS

---

## Ideas futuras de expansión

Una vez el portal esté operativo, se pueden añadir nuevos módulos fácilmente:

| Módulo | Función | Notas |
|---|---|---|
| Domótica | Estado dispositivos, clima, energía | Via Home Assistant (ya existe) |
| Inventario | Lista de productos del hogar | — |
| Tareas | Lista de tareas domésticas compartidas | — |

---

## Design System

### Decisiones tomadas

| Decisión | Elección |
|---|---|
| Paleta | **Índigo y Arena** (opción 3) |
| Tipografía | **System UI** (fuente del sistema operativo) |
| Bordes | Poco redondeados — `border-radius: 4px` |
| Modos | Claro y oscuro (toggle) |

> Las 4 paletas candidatas están disponibles de forma interactiva (con toggle claro/oscuro) en [`demo-paletas.html`](demo-paletas.html).
> Las 3 tipografías comparadas sobre la paleta elegida están en [`demo-tipografias.html`](demo-tipografias.html).

### Principio
Todas las apps (hogarOS, ReDo, FiDo, futuras) comparten el mismo design system para dar sensación de entorno coherente. Cada app puede tener sus peculiaridades, pero la base visual es la misma.

### Cómo se comparte
hogarOS sirve un fichero CSS compartido (`/static/hogar.css`) que todas las apps cargan. Si se cambia un color o estilo base, se actualiza en todas automáticamente.

### Paleta — Índigo y Arena

**Modo claro:**
```css
--fondo:          #F5F0E8;   /* arena cálido */
--fondo-tarjeta:  #FDF9F3;   /* blanco roto */
--fondo-header:   #1E1B2E;   /* índigo oscuro */
--texto:          #1E1B2E;
--texto-suave:    rgba(30, 27, 46, 0.5);
--acento:         #6C63A8;   /* índigo medio */
--acento-hover:   #5A5296;
--alerta-fondo:   #EDE8F8;
--boton-sec:      #EAE4D8;
```

**Modo oscuro:**
```css
--fondo:          #13111E;
--fondo-tarjeta:  #1E1B2E;
--fondo-header:   #1E1B2E;
--texto:          #D4CEEE;
--texto-suave:    rgba(212, 206, 238, 0.5);
--acento:         #8B82C4;
--acento-hover:   #9D95D0;
--alerta-fondo:   #26223A;
--boton-sec:      #2A2640;
```

### Tipografía — System UI
```css
--fuente: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
```
Sin dependencias externas. Usa la fuente del sistema operativo — nítida y de carga instantánea.

### Bordes y forma
```css
--radio-sm:  4px;   /* tarjetas, botones, inputs */
--radio-md:  6px;   /* modales, paneles */
--radio-lg:  8px;   /* contenedores grandes */
```

---

## Tecnologías

| Capa | Tecnología |
|---|---|
| Servidor | Proxmox VE (192.168.31.131) |
| Contenedores | Docker + Compose |
| Reverse proxy | Nginx Alpine |
| Portal frontend | HTML + CSS + JS vanilla (sin frameworks) |
| ReDo | Node.js 20, nmap |
| FiDo | Python 3.12, FastAPI, SQLite |
