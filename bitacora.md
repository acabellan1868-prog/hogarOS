# Bitácora — hogarOS

## 2026-03-28

### Tarjeta MediDo en el portal

Añadida tarjeta "Salud del Sistema" al grid bento del portal. Consume
`/salud/api/resumen` y muestra semáforo de estado global (ok/warning/danger),
barras de CPU/RAM/disco del host Proxmox, conteo de contenedores y servicios,
y alertas activas. El grid bento pasa de 4 a 5 tarjetas (distribución 7+5 / 4+5+3).
Refresco automático cada 60 segundos junto al resto de datos operacionales.

## 2026-03-27

### Despliegue de MediDo en el ecosistema

Se añadió MediDo como nuevo módulo de monitorización del ecosistema hogarOS.
Integrado en el portal via proxy Nginx en `/salud/`.

### Reorganización de documentación

Se adoptó la estructura de documentación estándar del ecosistema:
- `ROADMAP.md` renombrado a `roadmap.md`
- `mejoras.md` renombrado a `analisis-mejoras.md`
- `Politica_backup/ROADMAP.md` renombrado a `Politica_backup/roadmap.md`
- Creada `bitacora.md` (este fichero)
