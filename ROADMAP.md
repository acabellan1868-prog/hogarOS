# HogarOS — Hoja de ruta

> Estado actual: fase de diseño y planificación completada.
> Última actualización: 2026-03-15

---

## Fase 0 — Preparación de repositorios

- [ ] Crear repositorio `redo` en GitHub (`acabellan1868-prog/redo`)
- [ ] Verificar que el repositorio `FiDo` está actualizado en GitHub

> **Nota:** El código actual de ReDo (`network-monitor/`) es una versión muy básica sin Docker ni frontend.
> Se construye desde cero en la Fase 1. Sirve solo como referencia de la lógica de escaneo existente.

---

## Fase 1 — ReDo: construcción desde cero

ReDo no tiene Docker ni frontend. Se construye como app completa e independiente.

### Estructura objetivo
```
redo/
├── src/               ← lógica de escaneo (Node.js + nmap)
├── frontend/          ← interfaz web propia (HTML/CSS/JS)
├── Dockerfile
├── docker-compose.yml ← para desarrollo/pruebas independiente
└── README.md
```

### Tareas
- [ ] Definir y crear la estructura del proyecto
- [ ] Migrar/reescribir la lógica de escaneo existente
- [ ] Integrar notificaciones via NTFY (topic: `hogaros-alertas`)
- [ ] Crear frontend propio (aplicando el design system de hogarOS)
- [ ] Dockerizar la aplicación
- [ ] Implementar `GET /api/resumen` que devuelva:
  ```json
  {
    "dispositivos_activos": 12,
    "dispositivos_confiables": 11,
    "dispositivos_desconocidos": 1,
    "ultimo_escaneo": "2026-03-13T18:30:00"
  }
  ```
- [ ] Verificar que el endpoint responde correctamente
- [ ] Probar la app de forma independiente antes de integrar en hogarOS

## Fase 2 — FiDo: endpoint de resumen

FiDo ya está en Docker y funcionando. Solo hay que añadir el endpoint.

### FiDo
- [ ] Implementar `GET /api/resumen` que devuelva:
  ```json
  {
    "mes": "Marzo 2026",
    "ingresos": 2100.00,
    "gastos": 1258.50,
    "balance": 841.50
  }
  ```
- [ ] Verificar que el endpoint responde correctamente

---

## Fase 3 — Design System (hogar.css)

- [ ] Crear `portal/static/hogar.css` con todas las variables CSS del design system:
  - Paleta Índigo y Arena (modo claro y oscuro)
  - Tipografía System UI
  - Variables de border-radius, espaciado, sombras
- [ ] Crear componentes base documentados:
  - Header con navegación entre apps
  - Tarjeta de módulo
  - Botones (primario y secundario)
  - Alerta / notificación
  - Toggle claro/oscuro

---

## Fase 4 — Portal HTML

- [ ] Crear `portal/index.html` con la estructura principal:
  - Header con logo hogarOS y navegación
  - Grid de tarjetas de módulos
  - Feed de alertas unificado
  - Sección de accesos rápidos
- [ ] Tarjeta ReDo: consumir `/api/resumen` de ReDo y mostrar datos en tiempo real
- [ ] Tarjeta FiDo: consumir `/api/resumen` de FiDo y mostrar datos en tiempo real
- [ ] Tarjeta Home Assistant: enlace directo (Nivel 1)
- [ ] Implementar toggle claro/oscuro con persistencia en localStorage
- [ ] Manejo de errores: mostrar estado "sin conexión" si una app no responde

---

## Fase 5 — Infraestructura

### Nginx
- [ ] Crear `nginx.conf` con las reglas de reverse proxy:
  - `/` → portal HTML estático
  - `/red/` → ReDo
  - `/finanzas/` → FiDo
  - `/static/` → ficheros compartidos (hogar.css, etc.)

### Docker Compose
- [ ] Crear `docker-compose.yml` con los tres servicios:
  - `hogar-portal` (Nginx)
  - `redo` (imagen externa)
  - `fido` (imagen externa)
- [ ] Configurar variables de entorno y volúmenes
- [ ] Verificar comunicación entre contenedores en local

### Despliegue en VM 101 (Debian 12)

El código se clona en la VM 101 donde corre Docker.
Se sigue la convención ya establecida con FiDo:

```
/mnt/datos/
├── fido-build/        ← código FiDo        (ya existe ✅)
├── fido/              ← datos FiDo (fido.db) (ya existe ✅)
├── hogarOS/           ← código hogarOS      (a clonar)
├── redo-build/ ← código ReDo  (a clonar)
└── redo/       ← datos ReDo   (a crear)
```

- [ ] Clonar hogarOS en `/mnt/datos/hogarOS/`
- [ ] Clonar redo en `/mnt/datos/redo-build/`
- [ ] Crear `/mnt/datos/redo/` para datos persistentes
- [ ] Actualizar `actualizar.sh` con las rutas correctas de `/mnt/datos/`
- [ ] Ejecutar `docker compose up -d` desde `/mnt/datos/hogarOS/`
- [ ] Probar acceso desde la red local: `http://192.168.31.131`
- [ ] Configurar reinicio automático (`restart: unless-stopped`)

---

## Fase 6 — Pulido y estabilización

- [ ] Probar en móvil (diseño responsive)
- [ ] Ajustar tiempos de refresco de los widgets
- [ ] Documentar en README cómo añadir una nueva app al portal
- [ ] Actualizar README con capturas del portal en funcionamiento

---

## Fase 7 — Futuro (sin fecha)

- [ ] **Home Assistant Nivel 2**: widget con datos reales via API REST de HA
  - Temperatura interior
  - Luces/enchufes activos
  - Estado alarma
  - Consumo eléctrico
- [ ] Módulo Inventario del hogar
- [ ] Módulo Tareas domésticas compartidas
- [ ] Notificaciones push en el portal (sin Telegram)

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
                    Fase 7 (Futuro)
```
