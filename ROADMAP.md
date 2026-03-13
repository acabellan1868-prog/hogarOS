# HogarOS — Hoja de ruta

> Estado actual: fase de diseño y planificación completada.
> Última actualización: 2026-03-13

---

## Fase 0 — Preparación de repositorios

- [ ] Crear repositorio `netsentinel` en GitHub (`acabellan1868-prog/netsentinel`)
- [ ] Verificar que el repositorio `FiDo` está actualizado en GitHub

> **Nota:** El código actual de NetSentinel (`network-monitor/`) es una versión muy básica sin Docker ni frontend.
> Se construye desde cero en la Fase 1. Sirve solo como referencia de la lógica de escaneo existente.

---

## Fase 1 — NetSentinel: construcción desde cero

NetSentinel no tiene Docker ni frontend. Se construye como app completa e independiente.

### Estructura objetivo
```
netsentinel/
├── src/               ← lógica de escaneo (Node.js + nmap)
├── frontend/          ← interfaz web propia (HTML/CSS/JS)
├── Dockerfile
├── docker-compose.yml ← para desarrollo/pruebas independiente
└── README.md
```

### Tareas
- [ ] Definir y crear la estructura del proyecto
- [ ] Migrar/reescribir la lógica de escaneo existente
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
- [ ] Tarjeta NetSentinel: consumir `/api/resumen` de NetSentinel y mostrar datos en tiempo real
- [ ] Tarjeta FiDo: consumir `/api/resumen` de FiDo y mostrar datos en tiempo real
- [ ] Tarjeta Home Assistant: enlace directo (Nivel 1)
- [ ] Implementar toggle claro/oscuro con persistencia en localStorage
- [ ] Manejo de errores: mostrar estado "sin conexión" si una app no responde

---

## Fase 5 — Infraestructura

### Nginx
- [ ] Crear `nginx.conf` con las reglas de reverse proxy:
  - `/` → portal HTML estático
  - `/red/` → NetSentinel
  - `/finanzas/` → FiDo
  - `/static/` → ficheros compartidos (hogar.css, etc.)

### Docker Compose
- [ ] Crear `docker-compose.yml` con los tres servicios:
  - `hogar-portal` (Nginx)
  - `netsentinel` (imagen externa)
  - `fido` (imagen externa)
- [ ] Configurar variables de entorno y volúmenes
- [ ] Verificar comunicación entre contenedores en local

### Despliegue en VM 101 (Debian 12)

El código se clona en la VM 101 donde corre Docker.
Los datos persistentes van en `/mnt/datos/` (ya en uso por FiDo y otros servicios).

```
/opt/hogar/          ← código fuente (git clones)
├── hogarOS/
├── netsentinel/
└── FiDo/

/mnt/datos/          ← volúmenes Docker (datos persistentes)
├── fido/            ← ya existe ✅
└── netsentinel/     ← a crear
```

- [ ] Crear `/opt/hogar/` en la VM 101
- [ ] Clonar los tres repos en `/opt/hogar/`
- [ ] Ejecutar `./hogarOS/actualizar.sh` para verificar que el script funciona
- [ ] Ejecutar `docker compose up -d` desde `/opt/hogar/hogarOS/`
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
Fase 1 (NetSentinel desde cero)  +  Fase 2 (FiDo /api/resumen)  +  Fase 3 (CSS)
                              ↓
                    Fase 4 (Portal HTML)
                              ↓
                    Fase 5 (Infraestructura)
                              ↓
                    Fase 6 (Pulido)
                              ↓
                    Fase 7 (Futuro)
```
