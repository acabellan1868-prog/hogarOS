# Repaso del ecosistema hogarOS — 2026-09-03

> Instantánea del estado de todos los proyectos. Basada en código y documentación
> local (roadmaps, bitácoras, CLAUDE.md, analisis-mejoras.md e historial git).
> **No refleja el estado real de la VM 101** — los "pendientes de desplegar" salen
> de las notas de cada roadmap.

---

## Panorámica

| App | Último commit | Estado | Riesgo / atención |
|-----|---------------|--------|-------------------|
| hogarOS | 2026-08-16 | En producción, estable | Falta cerrar Fase 17 (tarjeta Despensa) |
| FiDo | 2026-08-21 | En producción, activo | Migración v6 pusheada sin desplegar; duplicados sin limpiar |
| DeDo | 2026-08-04 | En producción parcial | Mucho pusheado sin desplegar; stock vacío |
| ReDo | 2026-05-22 | Terminado / estable (Fase 5 ✅) | Roadmap congelado desde abril; header sin unificar |
| MediDo | 2026-06-08 | En producción, estable | Roadmap desactualizado; Fases 7-9 sin tocar |
| kryptonite | 2026-06-01 | En producción (API dockerizada) | Fases 2-5 paradas; modelo ML sin integrar |
| pomoTareas | 2026-06-04 | v12 estable (GitHub Pages) | Fuera del ecosistema, sin docs estándar |
| dotfiles | 2026-05-21 | Consolidado | — |
| network-monitor | 2026-03 | Carpeta muerta (precursora de ReDo), no es repo git | Borrar / archivar |

El ecosistema lleva ~2 semanas sin actividad (último toque: FiDo 21-ago).
ReDo, MediDo y kryptonite llevan 3+ meses sin cambios.

---

## Por aplicación

### hogarOS — falta rematar Fase 17

**Pendiente inmediato:**
- Tarjeta resumen **"Despensa"** en el bento grid (`portal/index.html` consumiendo
  `GET /despensa/api/resumen`). Bloqueada esperando cerrar ajustes en DeDo.
- Fase 14 (briefing): verificar que el briefing de las 8:30 trae ↓mín/↑máx tras el
  fix AEMET, y borrar del `.env` de la VM la variable antigua `BRIEFING_HA_WEATHER_ENTITY`.
- El `## Estado actual` del roadmap va un par de sesiones por detrás (habla de Fase 16;
  últimas entradas de bitácora son del 16-ago).

**Futuras actuaciones (Fase 11 + `analisis-mejoras` §6):**
- Home Assistant nivel 2: **estado de alarma** y **consumo eléctrico** (únicos ítems sin marcar).
- Módulo **Inventario del hogar** (§6.10) y **Tareas domésticas compartidas / TareDo** (§4).
- **Widget del tiempo** con Open-Meteo (§6.13) — esfuerzo mínimo.
- **PWA instalable** (§6.14) y **vista quiosco** para la pantalla de cocina (§6.17).
- Notificaciones push en el portal (Web Push / Service Worker).
- Lanzador: status-check server-side para evitar el CORS.

### FiDo — cerrar el tema duplicados

**Pendiente inmediato (del propio roadmap):**
1. **Redesplegar el contenedor** para activar la migración v6 (índice único sobre
   `huella`) — está en el código pero no activa en producción.
2. Limpiar los **5 duplicados cruzados CSV↔NTFY** confirmados y aún sin borrar.
3. Diseñar la reconciliación de esos cruces: margen de liquidación **direccional y
   configurable por banco** (CaixaBank liquida con retraso, Revolut al instante),
   siempre a `estado='revisar'`, nunca auto-fusión.
- `Estado actual` del roadmap está en 07-ago; los commits del donut-clic y evolución
  mensual (16-21 ago) no están reflejados.
- `analisis-mejoras.md` está vacío ("Pendiente de definir") pese a que hay ideas
  maduras en `hogarOS/analisis-mejoras.md §6`.

**Futuras actuaciones (§6.1-6.3, 6.11 + Fase 5):**
- **Presupuestos mensuales por categoría** con alertas 75/90/100% → salto de "registro"
  a "control". Alto valor.
- **Movimientos recurrentes / suscripciones** (separar gasto fijo de variable).
- **Transferencias internas** modeladas de verdad (hoy inflan ingresos/gastos en los
  informes agregados).
- **Informe mensual automático por NTFY** el día 1 (mismo patrón que el briefing).
- Exportación de datos y comparativas por período.

### DeDo — el que más deuda operativa acumula

**Pendiente inmediato:** pila de commits **pusheados y sin desplegar** (`actualizar.sh`
en la VM): campo `ean`, catálogo agrupado por marca, modal de catálogo, Despensa
agrupada por zona + fix del JOIN de `stock.py` (el filtro "Stock bajo/OK" llevaba roto
en silencio), y la pestaña **Tickets**.
- Cargar el **stock real** (dato del usuario) — la pestaña Despensa está vacía.
- Probar `POST /api/tickets` con un ticket real (Fase 2d, pendiente desde el inicio).
- Añadir **cache-busting `?v=N`** — hoy depende de Ctrl+Shift+R manual en cada deploy.
- Enviar los 40 valores de `zona` ya preparados una vez desplegado el campo.

**Futuras actuaciones (Fases 5-8, todas sin empezar):**
- Rutinas Claude Code: procesado automático de tickets desde Drive, avisos escalonados
  de caducidad, informe semanal.
- Fase 5b: **reconocimiento visual de la despensa** por foto (`POST /api/foto-despensa`)
  — concepto documentado, sin código.
- Módulo **menú** (señal de consumo), bot de **Telegram**, voz vía HA.
- Fase 8: cadencias de consumo y predicción de reposición (necesita 2-3 meses de datos).

### ReDo — funcionalmente terminado

Fase 5 cerrada en abril: exportación, vista por zona, historial con gráfico, config en
vivo. Nada pendiente planificado; el roadmap lo dice explícitamente.
- **Deuda de unificación:** `hogarOS/CLAUDE.md` marca ReDo como *"pendiente"* de adoptar
  el header Cockpit canónico (clases `ck-` compartidas). Tiene su propio Cockpit
  reimplementado, no el compartido.
- `Estado actual` congelado en 2026-04-02.

**Futuras actuaciones (§6.7, §6.15):**
- **Mapa de presencia familiar/doméstica**: convertir el dato técnico de presencia en
  lectura útil — primera/última presencia, ausencias fuera de patrón, actividad nocturna.
- **Topología visual por zonas** (grid de tarjetas por zona vs. tabla plana).

### MediDo — estable pero con roadmap parado

`Estado actual` en 2026-04-04. Hay commits hasta junio sin reflejar (uno, "listado Polar",
parece ajeno al proyecto — revisar qué es).
- Misma deuda que ReDo: header Cockpit *"pendiente"* de unificar con las clases compartidas.

**Futuras actuaciones (Fases 7-9 + §6.6):**
- **Estado real de backups**: que `backup.sh` emita un JSON y MediDo/hogar-api lo expongan
  por `/api/backup` con duración, tamaño, dumps OK/error, VMs, último error (§6.5). Hoy la
  tarjeta solo mira antigüedad.
- Disco real de las VMs vía QEMU guest agent; detección del disco USB externo.
- **Panel de degradación** (§6.6): línea base de latencia por servicio y alerta cuando se
  desvía, en vez de esperar a la caída total.
- Métricas por contenedor (CPU/mem) — desactivadas por rendimiento, habría que hacerlo async.
- Pantalla de settings (umbrales, intervalos, contenedores ignorados) desde la UI.

### kryptonite — el más estancado

API dockerizada y funcionando (`/crypto/api/`), pero las Fases 2-5 llevan paradas desde
junio. La integración de recompensas de staking de Revolut X se **descartó** (la API no
las expone); quedan ~1.10 DOT y ~2.47 ADA sin contabilizar de forma permanente.
- **Doc drift:** `hogarOS/CLAUDE.md` y `dotfiles/CLAUDE.md` dicen que nginx apunta a
  `host.docker.internal:5000`, pero la bitácora de kryptonite dice que se cambió a upstream
  de contenedor y puerto 5001. Alinear la documentación.

**Futuras actuaciones:**
- Integrar el **modelo Random Forest** (`modelo_ia.py`), que existe pero no está enganchado
  a ningún endpoint (Fase 4).
- Agente con **historial persistente** de conversación (hoy stateless) y modo
  experto/principiante (Fase 2).
- **Alertas avanzadas** con condiciones combinables + flujo Node-RED → Telegram (Fase 3).
- Paper trading y reportes PDF automáticos (Fase 5).

### pomoTareas

App HTML de un solo fichero en GitHub Pages (v12), sin servidor, sin integración con
hogarOS. No sigue la estructura documental estándar. Estable, sin pendientes documentados.
- Decisión pendiente: ¿se integra en el lanzador de hogarOS o se deja suelta? ¿Se le crea
  la documentación estándar?

---

## Deuda transversal (afecta a varios)

1. **Roadmaps desactualizados.** ReDo y MediDo en abril, FiDo y hogarOS un par de sesiones
   por detrás. Merece una pasada de puesta al día del `## Estado actual` de los cuatro.
2. **Header Cockpit sin unificar.** ReDo y MediDo tienen su propia versión en vez de las
   clases `ck-` canónicas de `hogar.css`. Refactor pendiente.
3. **Cache-busting inconsistente.** FiDo y ReDo usan `?v=N`; DeDo no.
4. **Despliegue 100% manual sin CI.** Cambios pusheados sin desplegar en DeDo (bastantes)
   y FiDo (migración v6). Cada `git push` necesita un `actualizar.sh` que se olvida.
5. **`network-monitor/`**: carpeta muerta que confunde (no es repo, precursora de ReDo).
   Archivar o borrar.
6. **Doc drift kryptonite** (puerto / upstream nginx).

---

## Próximos pasos propuestos, por orden

1. **DeDo:** `actualizar.sh` en la VM + verificar todo lo pendiente → desbloquea la tarjeta
   "Despensa" y cierra la Fase 17 de hogarOS.
2. **FiDo:** redesplegar para activar la migración v6 y limpiar los 5 duplicados cruzados.
3. **hogarOS:** verificar el briefing de las 8:30 y limpiar la variable `.env` antigua.
4. **Pasada de roadmaps:** poner al día `## Estado actual` en ReDo, MediDo y FiDo.
5. Elegir **una** evolución con valor alto para la siguiente tanda: **FiDo presupuestos por
   categoría** o **MediDo estado de backups estructurado**.
