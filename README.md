# HogarOS

> Portal doméstico unificado — gestiona tu red, tus finanzas y tu domótica desde una única interfaz web, desplegado en tu propio servidor.

![Portal HogarOS](captura-portal.png)

---

## ¿Qué es HogarOS?

HogarOS es un portal *self-hosted* que integra las herramientas de gestión doméstica en un único dashboard accesible desde la red local. En lugar de recordar IPs y puertos para cada servicio, todo está bajo una única URL servida por Nginx en un servidor Proxmox.

**Módulos integrados:**

| Módulo | Stack | Función |
|---|---|---|
| 🔍 [ReDo](https://github.com/acabellan1868-prog/ReDo) | Python · FastAPI · nmap | Red doméstica, detección de intrusos, alertas NTFY |
| 💰 [FiDo](https://github.com/acabellan1868-prog/FiDo) | Python · FastAPI · SQLite | Finanzas domésticas, extractos bancarios, categorización |
| 🏠 Home Assistant | — | Domótica (enlace directo, Nivel 1) |

---

## Arquitectura

```
Usuario → http://192.168.31.131
                │
                ▼
             Nginx (80)
             ├── /          → Portal (dashboard con widgets)
             ├── /static/   → hogar.css (design system compartido)
             ├── /red/      → ReDo (host.docker.internal:8083)
             └── /finanzas/ → FiDo (fido:8080 red Docker interna)
```

Cada app es independiente y se puede actualizar por separado. El portal consume sus APIs (`/api/resumen`) para mostrar resúmenes en tiempo real.

---

## Despliegue

### Requisitos

- VM con Docker y Docker Compose
- nmap instalado en el host (para los escaneos de ReDo)

### Estructura en la VM

```
/mnt/datos/
├── hogarOS/       ← este repositorio (portal + compose + nginx)
├── redo-build/    ← código ReDo (git clone)
├── redo/          ← datos persistentes (redo.db)
├── fido-build/    ← código FiDo (git clone)
└── fido/          ← datos persistentes (fido.db)
```

### Puesta en marcha

```bash
cd /mnt/datos/hogarOS
docker compose up -d
```

### Actualización

```bash
cd /mnt/datos/hogarOS
bash actualizar.sh
```

El script hace `git pull` en los tres repos, reconstruye las imágenes y reinicia los contenedores.

---

## Cómo añadir una nueva app al portal

Para integrar una nueva aplicación (por ejemplo, una app llamada **MiApp** accesible bajo `/miapp/`), hay que tocar 4 archivos:

### 1. `docker-compose.yml` — Añadir el servicio

```yaml
  miapp:
    build: /mnt/datos/miapp-build
    container_name: miapp
    ports:
      - "8084:8080"            # puerto libre → puerto interno de la app
    volumes:
      - /mnt/datos/miapp:/app/data
    environment:
      - TZ=Europe/Madrid
    restart: unless-stopped
```

> Si la app necesita acceso directo a la red del host (como ReDo), usa `network_mode: host` en lugar de `ports`.

### 2. `nginx.conf` — Añadir el proxy inverso

Añadir un upstream y un bloque location:

```nginx
    # En la sección de upstreams:
    upstream miapp {
        server miapp:8080;     # nombre del servicio en compose
    }

    # Dentro del bloque server { }:
    location /miapp/ {
        proxy_pass http://miapp/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Prefix /miapp;

        sub_filter_once off;
        sub_filter_types text/html application/javascript;
        sub_filter 'href="/' 'href="/miapp/';
        sub_filter 'src="/' 'src="/miapp/';
        sub_filter 'fetch("/' 'fetch("/miapp/';
        sub_filter 'fetch(`/' 'fetch(`/miapp/';
        sub_filter '"/api/' '"/miapp/api/';
        sub_filter '"/static/' '"/miapp/static/';
    }
```

Las reglas `sub_filter` reescriben las rutas absolutas del HTML/JS de la app para que funcionen bajo el prefijo.

### 3. `portal/index.html` — Añadir la tarjeta al dashboard

Dentro del `<div class="hogar-grid">`, añadir:

```html
        <!-- TARJETA MIAPP -->
        <div class="hogar-tarjeta" id="tarjetaMiapp">
          <div class="hogar-tarjeta__cabecera">
            <span class="hogar-tarjeta__titulo">Mi App</span>
            <span class="hogar-tarjeta__icono">&#128736;</span>
          </div>
          <div id="miappContenido">
            <span class="cargando">Cargando...</span>
          </div>
          <a href="/miapp/" class="hogar-tarjeta__enlace">Abrir MiApp &rarr;</a>
        </div>
```

Y en la sección `<script>`, añadir la función que consume la API:

```javascript
    const MIAPP_API = "/miapp/api";

    function cargarMiapp() {
      fetch(MIAPP_API + "/resumen")
        .then(function(r) { return r.json(); })
        .then(function(d) {
          document.getElementById("miappContenido").innerHTML =
            '<div class="hogar-tarjeta__valor">' + d.dato_principal + '</div>' +
            '<div class="hogar-tarjeta__detalle">' + d.detalle + '</div>';
        })
        .catch(function() {
          document.getElementById("miappContenido").innerHTML =
            '<span class="hogar-estado-offline">Sin conexion con MiApp</span>';
        });
    }

    // Llamar en la inicialización y en el setInterval
    cargarMiapp();
```

### 4. La app debe exponer `GET /api/resumen`

Este es el contrato que sigue el portal. El endpoint debe devolver un JSON con los datos que la tarjeta necesita mostrar. Ejemplo:

```json
{
  "dato_principal": "42",
  "detalle": "algún contexto"
}
```

### Resumen de pasos

1. **`docker-compose.yml`** → nuevo servicio
2. **`nginx.conf`** → upstream + location con sub_filter
3. **`portal/index.html`** → tarjeta HTML + función JS que consume `/api/resumen`
4. **La app** → implementar `GET /api/resumen`
5. `docker compose up -d --build` para desplegar

---

## Estructura del repositorio

```
hogarOS/
├── portal/
│   ├── index.html           ← Dashboard principal
│   └── static/
│       └── hogar.css        ← Design system (paleta Índigo y Arena)
├── nginx.conf               ← Reverse proxy
├── docker-compose.yml       ← Orquestación de servicios
├── actualizar.sh            ← Script de actualización (pull + build + up)
├── ROADMAP.md               ← Plan de desarrollo con fases
├── analisis.md              ← Análisis y decisiones de diseño
└── README.md                ← Este archivo
```

> ReDo y FiDo viven en sus propios repositorios y se construyen desde rutas locales en la VM.

---

## Tecnologías

| Capa | Tecnología |
|---|---|
| Servidor | Proxmox VE (VM Debian 12) |
| Contenedores | Docker + Compose |
| Reverse proxy | Nginx Alpine |
| Frontend | HTML · CSS · JS vanilla |
| Design system | hogar.css (Índigo y Arena, modo claro/oscuro) |
| ReDo | Python 3.12 · FastAPI · python-nmap |
| FiDo | Python 3.12 · FastAPI · SQLite |
| Notificaciones | NTFY (push al móvil) |

---

## Estado del proyecto

Consulta el [roadmap completo](ROADMAP.md) para ver todas las fases y próximos pasos.
