# HogarOS — Hoja de ruta

> Estado actual: fase de diseño y planificación completada.
> Última actualización: 2026-03-13

---

## Fase 0 — Preparación de repositorios

- [ ] Crear repositorio `netsentinel` en GitHub (`acabellan1868-prog/netsentinel`)
- [ ] Vincular el código local de NetSentinel (`E:\Documentos\Desarrollo\claude\network-monitor\`) al nuevo repo
- [ ] Verificar que el repositorio `FiDo` está actualizado en GitHub

---

## Fase 1 — APIs de resumen

Cada app debe exponer un endpoint `/api/resumen` que el portal pueda consultar.

### NetSentinel
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

## Fase 2 — Design System (hogar.css)

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

## Fase 3 — Portal HTML

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

## Fase 4 — Infraestructura

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

### Despliegue en Proxmox
- [ ] Clonar el repositorio hogarOS en el servidor Proxmox
- [ ] Ejecutar `docker compose up -d` y verificar que todo arranca
- [ ] Probar acceso desde la red local: `http://192.168.31.131`
- [ ] Configurar reinicio automático (`restart: unless-stopped`)

---

## Fase 5 — Pulido y estabilización

- [ ] Probar en móvil (diseño responsive)
- [ ] Ajustar tiempos de refresco de los widgets
- [ ] Documentar en README cómo añadir una nueva app al portal
- [ ] Actualizar README con capturas del portal en funcionamiento

---

## Fase 6 — Futuro (sin fecha)

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
Fase 1 (APIs)  +  Fase 2 (CSS)
         ↓              ↓
         Fase 3 (Portal HTML)
                ↓
         Fase 4 (Infraestructura)
                ↓
         Fase 5 (Pulido)
                ↓
         Fase 6 (Futuro)
```
