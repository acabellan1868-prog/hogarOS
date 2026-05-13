# Bitácora — hogarOS

## 2026-05-13 — Fix permisos backup MariaDB

Error al ejecutar `backup_dumps.sh`: "Permiso denegado" al escribir el dump de Nextcloud.

**Causa raíz:** el dump se escribía en `/mnt/datos/mariadb/` (volumen de datos interno de MariaDB, propietario `999:systemd-journal`, sin escritura para `others`). El montaje NFS aplica `root_squash`, por lo que `root` no tiene privilegios reales sobre ese directorio.

**Cambios:**
- `Politica_backup/backup_dumps.sh` línea 29: destino del dump cambiado de `/mnt/datos/mariadb/nextcloud_dump.sql` a `/mnt/datos/backups/mariadb/nextcloud_dump.sql`
- `Politica_backup/backup.sh` líneas 292 y 417: rutas de verificación del dump actualizadas a `backups/mariadb/nextcloud_dump.sql`

**Acción manual en VM:** `mkdir -p /mnt/datos/backups/mariadb && chmod 777 /mnt/datos/backups/mariadb`

**Pendiente verificar:** ejecutar backup completo en la próxima sesión para confirmar que el dump se genera correctamente.

---

## 2026-05-12 — Silenciado de alertas (Centro de Alertas 2.0 parcial)

### Objetivo
Permitir silenciar alertas individualmente desde el portal, suprimiendo también las notificaciones NTFY durante el período de silencio.

### Cambios en ReDo (`ReDo/app/`)
- `bd.py`: migración automática que añade columna `silenciada_hasta TEXT` a la tabla `alertas`
- `rutas/alertas.py`: tres endpoints nuevos:
  - `POST /api/alertas/{id}/silenciar` — body `{ horas: 24 }` o `{ permanente: true }`
  - `POST /api/alertas/{id}/activar` — quita el silencio (pone `silenciada_hasta = NULL`)
  - El listado `GET /api/alertas` devuelve `silenciada_hasta` y excluye silenciadas del contador

### Cambios en MediDo (`MediDo/app/`)
- `bd.py`: misma migración para `silenciada_hasta`
- `rutas/alertas.py`: mismos tres endpoints + helper `_esta_silenciada()`
- `alertador.py`: `_crear_alerta()` ahora comprueba si existe una alerta silenciada del mismo tipo+servicio antes de crear una nueva — si la hay, no crea ni envía NTFY

### Cambios en hogarOS (`portal/alertas.html`)
- Nuevo filtro `SILENCIADAS` en la toolbar
- Filtro `TODAS` excluye silenciadas (muestra activas + resueltas)
- Botones por alerta activa: ⏸ Silenciar 24h, ⊘ Ignorar siempre, ↺ Activar (en silenciadas)
- Etiqueta visual `SILENCIADA 24H` / `IGNORADA SIEMPRE` en color warn
- Contador de alertas activas no cuenta las silenciadas

### Comportamiento
- `silenciada_hasta = NULL` → activa
- `silenciada_hasta = "9999-12-31"` → ignorada permanentemente
- `silenciada_hasta = timestamp` → silenciada hasta esa fecha
- Al expirar el silencio temporal, MediDo crea nueva alerta y envía NTFY en el siguiente ciclo

---

## 2026-05-12 — Migración al estilo Cockpit de lanzador, admin y alertas

### `portal/lanzador.html` — Rediseño completo Cockpit (commit `b5ad36e`)

- Sustituido el diseño Living Sanctuary por Cockpit completo.
- Header: 48px fijo sticky, `ck-bg2`, nav inline con LANZADOR como tab activo, reloj + toggle tema a la derecha.
- Fondo: `ck-bg` con scanlines decorativos.
- Grupos: encabezado `◆ NOMBRE` en JetBrains Mono uppercase, línea separadora `1px solid ck-line`.
- Apps: tiles rectangulares con `border: 1px solid ck-line`. Hover: borde teal + glow en oscuro.
- FAB de administración: `[ + ]` estilo terminal en vez del blob orgánico.
- Tema: migrado de `data-tema`/`hogar-tema` a `data-tema-cockpit`/`hogar-cockpit-tema`.
- Drawer móvil: mismo patrón que el portal.

### `portal/admin-lanzador.html` — Rediseño completo Cockpit (commit `bbce7f2`)

- Mismo header 48px que el resto del ecosistema. Subtítulo `ADMIN · LANZADOR`.
- Grupos: borde `1px solid ck-line`, cabecera `ck-bg2` con `◆` en JetBrains Mono.
- Filas de enlace: icono en caja cuadrada `ck-bg3`, nombre uppercase 0.52rem.
- Botones de acción: `✎` / `✕` en cuadrados de 26px; borrar se tiñe en `ck-danger` al hover.
- Botones principales: `[ + GRUPO ]` y `[ GUARDAR ]` estilo terminal.
- Modales: fondo `rgba(0,0,0,0.65)`, caja `ck-bg2` con `1px solid ck-line` sin border-radius.
- Inputs: `ck-input-bg` / `ck-input-border`; foco en `ck-accent`.
- Aviso guardado: `✓ CAMBIOS GUARDADOS` con borde `ck-success`.

### `portal/alertas.html` — Rediseño completo Cockpit (commit `b7e7bec`)

- Header 48px con ALERTAS como tab activo.
- Filtros de estado y módulo: botones de borde fino uppercase, toggle a teal al activarse.
- Contador: en `ck-danger` con `!` cuando hay alertas activas, gris si no hay ninguna.
- Items: grid 3 columnas — barra lateral de color (rojo activa, naranja warning, gris resuelta), cuerpo, acciones.
- Badge de módulo: caja con borde fino sin border-radius; ReDo en teal, MediDo en verde.
- Botones `✓` (resolver) y `✕` (eliminar): cuadrados con hover de color.
- Mensajes de error de conexión: franja fina con borde naranja.

### Fix: `ck-marca-box` como enlace al portal (commit `f62c81f`)

- En `lanzador.html`, `admin-lanzador.html` y `alertas.html` el `div.ck-marca-box` pasa a `<a href="/">`.
- Permite volver al portal haciendo clic en el cuadradito con el punto del header.
- `hogar.css`: añadido `text-decoration: none` a `.ck-marca-box` para evitar subrayado.

### Despliegue en producción

- `./actualizar.sh` ejecutado en VM 101. Todos los cambios de la sesión en producción. ✅

### Fix: icono de Claude en el lanzador (commit `131112e`)

- `hogar-api/app/principal.py`: sustituido `emoji:🧠` por la URL del SVG oficial de Claude en el CDN de Homarr (`cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/claude.svg`).
- Aplica solo a instalaciones nuevas o si se borra `lanzador.json`. Para la VM actual: actualizar desde `/admin-lanzador.html` o con `sed` en el JSON.

---

## 2026-05-07 — Mejoras responsive ecosistema completo

### `portal/index.html` — Font-size adaptativo y scroll en portátil

- `html { font-size }` cambiado de fijo `150%` a tres escalones: `150%` (≥1301px), `125%` (portátiles ≤1300px), `100%` (tablet/móvil ≤900px). Antes todo el contenido se veía muy grande en portátiles de 15".
- `overflow-x: hidden; overflow-y: auto` en móvil (≤767px): elimina el scroll horizontal en móvil que aparecía cuando algún elemento desbordaba el viewport.
- Nuevo bloque `@media (max-width: 1300px) and (min-width: 768px)`: añade `overflow-y: auto` a `.ck-zona`, `#zona-d`, `.ck-zona-d-izq` y `.ck-zona-d-der`, permitiendo scroll interno por panel en portátil sin romper el diseño cockpit de pantalla completa.

### `portal/static/hogar.css` — Fix tipografía nav compartida

- Añadido `font-weight: normal` a `.ck-nav a, .ck-nav button`. Los navegadores aplican `font-weight: bold` por defecto a `<button>`, haciendo que los ítems del nav en FiDo (que usa `<button>`) aparecieran en negrita frente a los `<a>` de hogarOS. Al ser hogar.css compartido, el fix afecta a todas las apps.

## 2026-05-05 (sesión 2)

### Fase 15 Paso 4 y 5 — Rediseño Cockpit de ReDo y MediDo

Completada la migración al estilo Cockpit de las dos apps restantes del ecosistema.
Toda la capa visual reemplazada; toda la lógica JS y los endpoints de API preservados.

**ReDo** (`ReDo/static/index.html`, commits `1fb510e` + `0eae3a2`):
- Header fijo 48px con `ck-header` + nav inline de 4 pestañas (DISPOSITIVOS / PRESENCIA / HISTORIAL / CONFIG). Drawer lateral solo en móvil.
- 4 KPIs en grid horizontal con fuente HUD monoespaciada.
- Tabla de dispositivos con bordes `1px var(--ck-line)`, cabeceras en `0.48rem` uppercase, badges `--ok/--warn`.
- Timeline de barras con `--ck-accent` y gráfica SVG historial 24h preservada.
- Sección configuración con inputs Cockpit.
- `cambiarTab()` sincroniza botones de escritorio, pestañas móviles y drawer simultáneamente.

**MediDo** (`MediDo/static/index.html`, commits `631a3d6` + `dc9d862`):
- Header con 7 pestañas inline (General / Proxmox / Contenedores / Servicios / Historial / Alertas / Claude).
- Barra `.md-status` con `.status-dot` reemplaza el semáforo circular antiguo.
- Tarjetas métricas (`.md-tarjeta`) con barras de progreso de 2px (`.md-barra`).
- Canvas gráfica 24h preservada; líneas de cuadrícula en `rgba(128,128,128,0.1)` para compatibilidad oscuro/claro.
- Tab Claude: select de período, tabla de sesiones con filas expandibles, totales en grid.
- Todo el JS preservado: `cargarGeneral`, `cargarProxmox`, `cargarContenedores`, `cargarServicios`, `cargarHistorial`/`dibujarGrafica`, `cargarAlertas`, `cargarSesionesClaudeAPI`, `setInterval(60s)`.

**Fix tipografía común:**
- Causa raíz: ReDo y MediDo no tenían `html { font-size: 150% }`, por lo que `1rem = 16px`
  en lugar de `24px`, haciendo todos los textos más pequeños que en hogarOS y FiDo.
- Fix: añadida la regla en el bloque `<style>` de cada `index.html`.

---

## 2026-05-05

### Header Cockpit extraído a hogar.css como componente compartido

Los estilos del header del portal (`portal/index.html`) estaban definidos como
`<style>` inline y no eran reutilizables por las sub-apps (FiDo, ReDo, MediDo).
Esto hacía que cada app tuviera su propia versión del header con dimensiones y
estilos distintos, rompiendo la consistencia visual del ecosistema.

**Solución:** Se extrajo el sistema completo de cabecera Cockpit a `portal/static/hogar.css`
(sección 7b). Las clases son las mismas que ya usaba el portal, por lo que este
no requirió cambios en su HTML.

**Clases añadidas a hogar.css:**
- `.ck-header` — contenedor principal (height 48px, fondo `--ck-bg2`, borde inferior)
- `.ck-hdr-izq` / `.ck-hdr-der` — lados izquierdo y derecho
- `.ck-marca-box` / `.ck-marca-dot` — logotipo cuadrado con punto interior
- `.ck-marca-txt` / `.ck-marca-sub` — nombre y subtítulo de la marca
- `.ck-sep` — separador vertical de 1px
- `.ck-nav` / `.ck-nav a` / `.ck-nav button` — navegación horizontal con estado `activo`
- `.ck-reloj` / `.ck-reloj__hora` / `.ck-reloj__fecha` — reloj con hora y fecha
- `.ck-tema-btn` — botón de cambio de tema (28×28px)

**Primera app en adoptarlo:** FiDo (ver su bitácora).
**Pendiente de adoptar:** ReDo y MediDo, cuando se migre su interfaz.

## 2026-05-04

### Refactorización completa del grafo de red (portal Cockpit)

Sesión de correcciones iterativas sobre `renderNetworkGraph` en `portal/index.html`.
Commits: `9123012`, `819e051`, `f1f9da6`, `10f9316`, `3164ebb`.

#### Problemas identificados y soluciones

**Bug: 3 nodos naranjas pero el contador decía "1 desconocido"**
- Causa: el contador del encabezado (`/api/resumen`) filtra `WHERE ultima_vez >= datetime('now', '-24 hours') AND confiable = 0` (solo activos recientes), pero el grafo coloreaba de naranja TODOS los dispositivos con `confiable = 0` en la BD, incluyendo históricos inactivos.
- Fix: `unknown = (d.confiable === false || d.confiable === 0) && minAct < 1440` — coherente con el contador.

**Bug: nodos sin nombre**
- Causa: la etiqueta solo se mostraba si `activo` (visto en < 70 min).
- Fix: etiqueta siempre visible para todos los dispositivos; fuente y opacidad reducidas para los inactivos.

**Bug: grafo pequeño — viewBox cuadrado en contenedor apaisado**
- Primera iteración: cambié viewBox de 320×200 a 300×300 con `meet`. Error: en un contenedor apaisado (~900×380 px) el `meet` limita por el alto → el contenido se encoge a 380×380 y deja 260 px vacíos a cada lado. Empeoró.
- Segunda iteración: viewBox 480×270 (16:9) con `preserveAspectRatio="none"`. El grafo llenaba el espacio pero los círculos se convertían en elipses (el SVG se estira en X e Y de forma independiente). El usuario lo reportó como "mareante".

**Bug: nodos agrupados en el centro (radio basado en timestamp)**
- Causa: el radio se calculaba con la antigüedad del dispositivo (`primera_vez`). Como todos los dispositivos fueron descubiertos en el mismo primer scan de nmap, `primera_vez` es prácticamente idéntico para todos → `ratio ≈ 1` para todos → radio mínimo → montón en el centro. Solo los pocos añadidos después se distribuían.
- Fix: el radio se calcula con `hash(IP + "r") % 997`, distribución pseudoaleatoria uniforme entre `rMin` y `rMax`, determinista (misma posición en cada render).

**Problema raíz: distorsión con `preserveAspectRatio="none"`**
- `none` estira el SVG para rellenar el contenedor, haciendo que círculos se conviertan en elipses y el texto se deforme horizontalmente.
- Fix definitivo: la función ya no devuelve HTML sino que recibe el elemento contenedor directamente. Inserta un `<svg>` vacío y usa `requestAnimationFrame` para leer las dimensiones reales del contenedor (`clientWidth` / `clientHeight`). El `viewBox` se fija exactamente a esas dimensiones → escala 1:1 → círculos perfectos siempre, independientemente del tamaño o ratio del contenedor.

#### Estado final del grafo (`renderNetworkGraph`)

| Aspecto | Implementación |
|---------|---------------|
| Radio | Hash del IP/MAC → distribución uniforme + jitter ±10 % |
| Forma distribución | Elipse proporcional al contenedor real (rxMax=90 % de cx, ryMax=82 % de cy) |
| Nodos naranjas | Solo si `confiable=0` y visto en últimas 24 h (igual que el contador) |
| Etiquetas | Siempre visibles; font-size 11 px (activos) / 9 px (inactivos) |
| Círculos | Sin distorsión: viewBox = px reales del contenedor |
| Firma función | `renderNetworkGraph(lista, contenedor)` — manipula el DOM directamente |

## 2026-05-02 (sesión 2)

### Fix tamaño de fuentes en FiDo Cockpit

Las fuentes del nuevo diseño eran demasiado pequeñas (rem calibrados para el prototipo,
no para uso real). Solución: `html { font-size: 150% }` en `estilos.css` — escala
proporcionalmente todos los tamaños rem sin tener que cambiarlos uno a uno. Misma
técnica usada en el portal.

- `FiDo/static/estilos.css`: añadido `html { font-size: 150% }`. Header ajustado
  a `height: 3.5rem` y footer a `height: 2.2rem` (de `px` a `rem` para escalar).
- `FiDo/static/index.html`: cache-busting a `estilos.css?v=3`.
- Commit: `ff73ecf` — pendiente despliegue con `./actualizar.sh` en VM.

---

## 2026-05-02

### Fase 1 rediseño Cockpit — hogar.css (base compartida)

Inicio del rediseño visual del ecosistema hogarOS: de estilo "Living Sanctuary"
(glassmorphic, Plus Jakarta Sans) a nuevo estilo "Cockpit" (HUD, líneas finas,
JetBrains Mono, modo oscuro/claro con toggle).

**Cambios en `portal/static/hogar.css`** (añadidos al final, sin tocar código existente):
- `@import` JetBrains Mono (pesos 300/400/500/700) desde Google Fonts.
- Variables `--ck-*` en `:root` (oscuro por defecto) y override en `[data-tema-cockpit="light"]`.
  Paleta oscura: fondo `#060a09`, acento teal `#00e5c4`. Paleta clara: fondo `#f5f2ed`, acento `#1a6a60`.
- Componente `.zone-label` / `.zone-label__diamond`: etiqueta de zona HUD (sustituirá a `.hogar-seccion__titulo`).
- Componente `.minibar` (`.minibar__label`, `.minibar__track`, `.minibar__fill`, `.minibar__valor`): barra de progreso horizontal para métricas.
- Componente `.status-dot` (variantes `--ok`, `--warn`, `--danger`): punto de estado con glow; sin glow en modo claro.
- Clase `.cockpit-line` / `.cockpit-line--bright`: divisor de 1px usando `--ck-line`.
- Animaciones `@keyframes pulse-danger` y `@keyframes blink`; clases utilidad `.danger-pulse`, `.cursor-blink`.
- Scrollbar global: 4px, thumb `rgba(0,229,196,0.15)` oscuro / `rgba(26,106,96,0.15)` claro.

El estilo Living Sanctuary queda intacto — la migración es incremental por fases.

### Fase 2 rediseño Cockpit — portal/index.html

Reescritura completa del portal principal al estilo Cockpit. Toda la lógica de
negocio (fetches, entidades HA, IDs) se preserva; solo cambia la capa visual.

**Cambios en `portal/index.html`:**
- Header flotante glassmorphic → header fijo 48px, fondo `var(--ck-bg2)`, nav inline.
  Eliminado drawer antiguo — drawer nuevo solo para móvil (<768px).
- `hogar-lumina`, `.hogar-tarjeta`, `.portal-bento` → eliminados.
- Grid 3×2 (`320px 1fr 260px` / `1fr 1fr`) con 6 zonas HUD:
  - [A] Clima: temp exterior grande + TempScale interior cromático
  - [B] Luces: chips 3×3 con dot de estado
  - [C] Red: NetworkGraph SVG generado en JS con layout circular
  - [D] Finanzas + Claude: split 50/50 con MiniBar ingresos/gastos y tokens
  - [E] Gauges: 3× Gauge SVG circular (CPU/RAM/Disco) + resumen ctrs/svcs
  - [F] Backup + Log alertas + Accesos rápidos estilo terminal
- Footer fijo 28px con status dots (SISTEMA/RED/BACKUP/CLAUDE) actualizados
  en tiempo real desde cada fetch.
- Toggle tema sol/luna → `localStorage("hogar-cockpit-tema")` + `data-tema-cockpit`.
- Responsive: móvil <768px pasa a flex columna con drawer lateral.
- `body { overflow: hidden }` en desktop; `overflow: auto` en móvil.

### Fase 3 rediseño Cockpit — FiDo

Reescritura completa del frontend de FiDo al estilo Cockpit.

**Cambios en `static/index.html`:**
- Eliminados: `hogar-lumina`, header flotante Living Sanctuary, drawer antiguo, ApexCharts.
- Header fijo 48px con nav inline (botones de sección) + reloj + toggle tema. Drawer lateral solo en móvil.
- Panel: grid 3 columnas — KPIs (Balance/Ingresos/Gastos/Movimientos) | minibars categorías + donut SVG | barras mensuales SVG + resumen crypto.
- Sección Movimientos: barra de filtros compacta + tabla `ck-tabla` + paginación Cockpit.
- Sección Importar: 2 columnas (formulario | resultado estilo terminal).
- Secciones Categorías, Reglas, Ajustes: `ck-card` con `ck-lista-item`, formularios inline con `ck-input`/`ck-select`.
- Sección Crypto: tabla + sidebar distribución con minibars.
- Modal edición movimiento: grid 2 cols con `ck-input`/`ck-select` Cockpit.
- Footer 28px con status dots API/BD/NTFY/KRYPTO.
- Tema: `data-tema-cockpit` en `<html>`, toggle por botón, persiste en `localStorage`.
- Toda la lógica Alpine.js (x-data, x-model, @click, x-for) preservada intacta.

**Cambios en `static/estilos.css`:**
- Reescritura completa. Elimina todas las clases Living Sanctuary (hogar-tarjeta, hogar-tabla, etc.).
- Nuevas clases `ck-*` usando variables `--ck-*` de hogar.css.
- Layout: `#fido-app` flex-column 100vh, secciones con overflow controlado.

**Cambios en `static/app.js`:**
- Eliminada dependencia de ApexCharts (no se carga en index.html).
- Constante global `COLORES_CAT` (paleta teal/indigo/amber/pink…).
- `renderizarGraficaCategoria()` y `renderizarGraficaMes()` → `renderizarDonut()` y `renderizarBarras()`: SVG inline generado con string concatenation.
- Nuevos métodos `catColor(i)` y `catPct(cat)` para minibars del panel.

### Correcciones post-implementación — portal/index.html

- **Grafo de red enano**: el SVG de `renderNetworkGraph` no llenaba el espacio disponible.
  Corregido cambiando `.ck-grafo-wrap` a `position:relative` y el SVG a
  `position:absolute; inset:0.25rem` para que ocupe toda la zona sin desbordarse.
- **Etiquetas de nodo con "192.168."**: todos los dispositivos sin nombre mostraban
  `192.168.` (truncado a 8 chars). Añadido helper `ipCorta()` que extrae los dos
  últimos octetos. Ahora cada nodo muestra el nombre como primario y los octetos
  `X.Y` como texto secundario más pequeño y tenue.
- **Fetches encadenados**: `/resumen` y `/dispositivos` estaban encadenados —
  cualquier fallo en `/dispositivos` borraba las métricas ya renderizadas.
  Separados en dos `fetch` totalmente independientes.

## 2026-04-27

### Briefing diario — implementación completa

Se implementa el briefing diario del hogar: un mensaje NTFY (protocolo de notificaciones)
que se envía automáticamente a las 8:30 con el parte de situación del ecosistema.

**Motivación:** el portal hogarOS no se mira por las mañanas, pero sí el móvil.
NTFY es el canal natural al ser el ya usado para alertas.

**Cambios en hogar-api** (orquestador del ecosistema, lugar correcto para esta lógica):
- `requirements.txt`: añadidos `apscheduler` (planificador de tareas) y `httpx` (cliente HTTP).
- `app/briefing.py`: nuevo módulo con toda la lógica de recopilación y envío.
  - `_obtener_sistema()` → consulta MediDo: CPU, RAM, disco y servicios caídos.
  - `_obtener_backup()` → lee `backup_estado.json` del volumen local (sin HTTP).
  - `_obtener_gasto_semana()` → consulta FiDo con `?periodo=semana`.
  - `_obtener_temperatura()` → consulta HA vía API REST con la entidad weather configurada.
  - `_componer()` → ensambla título + cuerpo; prioridad `high` si hay servicios caídos o backup viejo.
  - `_enviar_ntfy()` → POST JSON a NTFY.
  - `enviar_briefing()` → punto de entrada del job.
- `app/principal.py`: añadido APScheduler con `CronTrigger` a las 8:30 (configurable).
  Añadido endpoint `POST /briefing/enviar` para lanzar el briefing manualmente al probar.
- `docker-compose.yml`: nuevas variables para hogar-api: `HA_TOKEN`, `HA_HOST`,
  `NTFY_URL`, `NTFY_TOPIC_ALERTAS`, `BRIEFING_HA_WEATHER_ENTITY`, `BRIEFING_HORA`, `BRIEFING_MINUTO`.
- `.env.example`: documentadas las tres nuevas variables de briefing.

**Cambio en FiDo:**
- `app/rutas/resumen.py`: nuevo parámetro `?periodo=semana` que devuelve gastos
  desde el lunes de la semana actual hasta hoy. Compatible con el parámetro anterior
  (`?periodo=mes` sigue siendo el comportamiento por defecto).

**Formato del mensaje NTFY:**
```
☀️ Buenos días — lunes 27 abr

🖥️ Sistema: CPU 12% · RAM 54% · Disco 67% ✅
💾 Backup: hace 1 día ✅
💶 Semana del 21 al 27 abr: 143.50 € gastados
🌡️ Exterior: 14°C · ↓9° ↑22°
```

**Pruebas realizadas el mismo día:**
- Desplegado con `actualizar.sh`. El endpoint devuelve OK y los datos se recopilan
  correctamente: CPU 5%, RAM 76%, backup hace 1 día, gasto semanal 0€, temperatura 18.8°C.
- Fix adicional (`commit 4e21a1a`): la primera versión posteaba a `ntfy.sh/TOPIC` con JSON body,
  lo que hacía que la app NTFY mostrase el JSON crudo. Corregido usando la API JSON de NTFY:
  POST al URL base con el topic como campo en el body.
- **Pendiente:** la notificación no llega al móvil. Causa probable: `NTFY_TOPIC_ALERTAS`
  no está configurado en el `.env` de la VM para el servicio hogar-api, o está vacío.
  Diagnóstico: `docker logs hogar-api --tail=20` en la VM.

**Resolución completa (2026-04-28):**
- `NTFY_TOPIC_ALERTAS` estaba configurado correctamente en el `.env`.
- Fix 2 (`commit 38b5947`): título URL-codificado con `urllib.parse.quote` — NTFY no lo decodifica,
  muestra los códigos `%E2%98%80...` en el título.
- Fix 3 (`commit 147a8ad`): título con RFC 2047 base64 (`=?UTF-8?B?...?=`) — NTFY lo decodifica
  correctamente en Android. Notificación verificada en producción ✅.

**Pendiente menor:**
- Temperatura llega (20.4°C) pero sin min/max del día. Requiere configurar `BRIEFING_HA_WEATHER_ENTITY`
  con una entidad weather que tenga forecast. Actualmente cae en el sensor de temperatura directo
  sin array de previsión.

## 2026-04-26

### Backup — diagnóstico pendiente de MariaDB/Nextcloud

Durante la primera prueba se detectaron dos pistas de permisos:

- Dentro del contenedor `next-cloud-db-1`, MariaDB corre como usuario `mysql`
  con UID/GID `999:999`.
- El directorio de datos aparecía como propietario `1000:1000`:
  `/var/lib/mysql` y `/var/lib/mysql/nextcloud`.
- En una prueba posterior apareció también permiso denegado al escribir
  `/mnt/datos/mariadb/nextcloud_dump.sql`.

Queda pendiente verificar en la próxima copia real:
- que la VM 101 tiene actualizado `Politica_backup/backup_dumps.sh`;
- si el fallo real está en permisos del volumen de MariaDB, en permisos de
  escritura de `/mnt/datos/mariadb`, o en ambos.

No se modificaron permisos durante esta sesión.

---

## 2026-04-26

### Backup — validación real de dumps generados

Ajustado `Politica_backup/backup_dumps.sh` para que no marque como generado un dump
si el comando falla o el fichero resultante queda vacío.

El caso detectado fue MariaDB/Nextcloud: `mariadb-dump` podía fallar por permisos
y aun así dejar una línea confusa en `backup_dumps.log` indicando que el SQL se
había generado.

Ahora el script:
- registra ERROR si el código de salida no es 0 o el fichero pesa 0 bytes;
- elimina el fichero de dump fallido para que no se copie como si fuera válido;
- solo notifica como OK los dumps que existen y tienen contenido.

Pendiente: revisar permisos reales de la base de datos `nextcloud` en el contenedor
MariaDB de la VM 101.

---

## 2026-04-26

### Backup — estado estructurado básico para la portada

Implementada la v1 rápida de mejora del backup:

- `Politica_backup/backup.sh` genera `backup_estado.json` al final del proceso.
- El JSON incluye estado general, duración, destino, tamaño total, conteos de dumps,
  conteos de VMs, estado de datos y resultado de NTFY.
- La verificación de dumps es básica: comprueba que los ficheros esperados existen
  y pesan más de 0 bytes tras el `rsync`.
- `backup.sh` envía ese JSON final a `POST /api/backup`, sobrescribiendo la notificación
  parcial que ya enviaba `backup_dumps.sh`.
- `hogar-api` normaliza la respuesta para mantener compatibilidad con el formato antiguo.
- La tarjeta "Estado del Backup" de `portal/index.html` muestra dumps, VMs, duración
  y tamaño si el JSON enriquecido está disponible.

Pendiente: actualizar `/root/backup.sh` en Proxmox, ejecutar backup real y verificar
en portada que se muestran los nuevos datos.

---

## 2026-04-26

### Propuestas de evolución añadidas a analisis-mejoras.md

Añadida una sección nueva en `analisis-mejoras.md` con 10 propuestas candidatas
para la evolución de hogarOS y sus aplicaciones satélite:

- Transferencias internas en FiDo
- Presupuestos por categoría
- Movimientos recurrentes y suscripciones
- Briefing diario del hogar
- Estado detallado de backups
- Degradación de servicios en MediDo
- Mapa de presencia en ReDo
- Centro de Alertas 2.0
- Integración Revolut X en Kryptonite
- Inventario doméstico ligero

Quedan como ideas para discutir y priorizar antes de pasarlas a `roadmap.md`.

---

## 2026-04-25

### AGENTS.md local para Codex

Creado `AGENTS.md` en el repo de hogarOS a partir de `CLAUDE.md`, con contexto
operativo para Codex: arquitectura Nginx, rutas de despliegue, `sub_filter`,
variables de entorno, design system y monitor de Claude.

Añadidas dos normas locales:
- No meter fases, historial ni estado del proyecto en `AGENTS.md`.
- No subir `Politica_backup/MANIFIESTO.txt` salvo indicación explícita.

---

## 2026-04-25

### Portada — tesela de Finanzas Domésticas filtrada

La tesela de Finanzas Domésticas del portal deja de consumir el resumen global de FiDo
y pasa a pedir `GET /finanzas/api/resumen?cuenta_nombre=Cuenta%20Antonio&banco=caixa`.

Motivo: el resumen global suma movimientos de todas las cuentas, incluyendo transferencias
entre cuentas propias, por lo que ingresos/gastos aparecen duplicados. De momento se usa
`Cuenta Antonio (Caixa)` como cuenta operativa principal para la lectura mensual.

Ficheros modificados: `portal/index.html`

---

## 2026-04-18

### Fase 13 completada — despliegue en VM 101

Ejecutado `actualizar.sh` en VM 101. Portal y MediDo desplegados con la tarjeta
"Asistente IA" funcionando. Fase 13d verificada en producción — todas las tareas manuales completadas.

---

## 2026-04-07

### Gestión de datos sensibles — convención .env para todo el ecosistema

Los repositorios del ecosistema son públicos en GitHub. Había valores sensibles
(topics NTFY, rango de red doméstica) escritos directamente en los
`docker-compose.yml`. Se establece una convención uniforme para todos los proyectos.

**Convención:**
- `.env` — valores reales, nunca en git (ya estaba en `.gitignore` en todos los proyectos)
- `.env.example` — plantilla pública con nombres de variables y descripciones, sin valores reales
- `docker-compose.yml` — usa `${VARIABLE}` para todos los valores sensibles

**Cambios en hogarOS:**
- `docker-compose.yml`: `NTFY_TOPIC=hogaros-3ca6f61b` → `${NTFY_TOPIC_ALERTAS}` (servicios redo y medido)
- `docker-compose.yml`: `REDO_NETWORK=192.168.31.0/24` → `${REDO_NETWORK}`
- `docker-compose.yml`: añadidas variables NTFY al servicio fido (`${NTFY_TOPIC_FIDO}`)
- `.env.example`: reescrito completamente con todas las variables del ecosistema y sin valores reales (el anterior tenía `PVE_HOST`, `PVE_NODE`, `PVE_TOKEN_ID` con valores reales)

**Nota sobre nomenclatura en hogarOS/.env:**
En el `.env` del orquestador los topics NTFY tienen nombres distintos para evitar
colisión entre los dos canales:
- `NTFY_TOPIC_FIDO` → topic de movimientos bancarios (solo FiDo)
- `NTFY_TOPIC_ALERTAS` → topic de alertas del sistema (ReDo y MediDo)

Cada servicio recibe la variable internamente como `NTFY_TOPIC` — sin cambios en el código.

**Aplicado también en:** FiDo, ReDo, MediDo (ver bitácoras respectivas)

---

### Listener NTFY en FiDo — captura automática de movimientos desde el móvil

Ver bitácora de FiDo (2026-04-06) para el detalle técnico completo.

El topic `fido-mov-ea3172c15373bf4a` es exclusivo para movimientos financieros,
separado del topic de alertas del ecosistema (`hogaros-3ca6f61b`).

---

## 2026-04-04

### Alertas: página propia + tarjeta compacta en portal

Se separa la gestión de alertas del portal principal.

**Nueva página `portal/alertas.html`:**
- Listado completo con filtros por estado (todas/activas/resueltas) y módulo (ReDo/MediDo)
- Botones resolver y eliminar por alerta
- Refresco automático cada 30 segundos
- Accesible desde el drawer y desde la tarjeta del portal

**Cambios en `portal/index.html`:**
- Eliminado el bloque "Centro de Alertas" (sección completa con listado)
- Nueva tarjeta compacta: nº activas (rojo/verde), nº resueltas, última alerta con mensaje y fecha
- Enlace "Gestionar alertas" → `/alertas.html`
- Drawer: nuevo enlace a Alertas
- Fila 2 del bento pasa a 4 tarjetas span 3: Salud + IA + Backup + Alertas

**Push:** Commit 4d16938 en acabellan1868-prog/hogarOS

---

### Fix tarjeta Asistente IA: sesiones y tokens incorrectos

El endpoint `/api/claude/resumen` de MediDo contaba filas individuales en lugar de sesiones únicas.

**Causa:** `COUNT(*)` contaba cada respuesta del hook como una sesión distinta. `SUM(tokens)` sumaba acumulados parciales en lugar del valor final por sesión.

**Fix en `MediDo/app/rutas/claude.py`:**
- La query de agregación ahora agrupa por `session_id` usando `MAX()` por campo (igual que `/sesiones`)
- `sesiones_totales` devuelve sesiones únicas reales
- Tokens y coste reflejan el valor final de cada sesión, sin duplicados

**Push:** Commit 78b9278 en acabellan1868-prog/MediDo

---

### Reorganización bento grid: 3 tarjetas por fila

Se reorganiza el layout del portal para distribuir las 6 tarjetas en 2 filas de 3.

**Cambios en portal/index.html:**
- Fila 1: Domótica(5) + Finanzas Domésticas(4) + Red Doméstica(3) = 12 columnas
- Fila 2: Salud del Sistema(4) + Asistente IA(4) + Estado Backup(4) = 12 columnas
- Antes: Domótica(7) + Finanzas(5) en fila 1, resto distribuido en filas 2 y 3

**Push:** Commit a89aade en acabellan1868-prog/hogarOS

---

## 2026-04-02 (noche II)

### Fase 13d: Limites de tokens en tarjeta Claude

Se actualiza tarjeta "Asistente IA" para mostrar limites de tokens con barras de progreso.

**Cambios en portal/index.html:**
- Función cargarClaude(): renderiza limites_tokens (últimas 5h y última semana)
- Nuevas barras: `[████░░] 45k/200k` para 5h, `[██░░░░] 1.2M/4M` para semana
- Colores condicionales: warning (>=75%), danger (>=90%)
- Números formateados con formatearNumero(): 200000 → 200k, 1000000 → 1M
- Reorganización: limites > resumen > presupuesto > última sesión

**Arquitectura:**
- Ventanas móviles (rolling windows) sin reseteo manual
- Limites: 200k tokens (5h), 4M tokens (1 semana)
- Configurables por env: CLAUDE_LIMITE_5H_TOKENS, CLAUDE_LIMITE_SEMANA_TOKENS

**Push:** Commit 515b058 en acabellan1868-prog/hogarOS

**Próxima fase:** 13e (verificación offline + despliegue en VM 101)

---

## 2026-04-02 (noche)

### Fase 13c: Tarjeta "Asistente IA" implementada

Se completó la implementación de la tarjeta en el portal que consume datos de Claude Code desde MediDo.

**Cambios en portal/index.html:**
- Grid CSS: nueva tarjeta Asistente IA (span 4 columnas), Backup ajustado (span 3)
- HTML: tarjeta con icono smart_toy, contenedor claudeContenido
- Función JS cargarClaude(): fetch a /salud/api/claude/resumen
- Renderiza: barra presupuesto, coste/presupuesto, sesiones, tokens, días reseteo, última sesión
- Helper formatearNumero(): formatea 1000000 → 1M, 15000 → 15k
- Inicialización: cargarClaude() al cargar + en setInterval (cada 60s)

**Características:**
- Presupuesto opcional: si no está configurado, solo muestra coste en grande
- Fallback offline: clase hogar-tarjeta--offline si MediDo no responde
- Responsivo: 100% ancho móvil, 4/12 columnas desktop
- Colores: primario (teal) + aviso (naranja) para presupuesto alto
- Reutiliza clases existentes: no necesita CSS nuevo

**Push:** Commit 1dcb2f2 en acabellan1868-prog/hogarOS

**Próxima fase:** 13d (verificación offline + despliegue en VM 101)

---

## 2026-04-02 (tarde II)

### Fase 13b: Endpoints en MediDo implementados

Se completó la implementación de endpoints en MediDo para recolectar datos de Claude Code.

**Cambios en MediDo:**
- Tabla `tracking_claude`: almacena eventos del hook con UNIQUE en session_id (idempotencia)
- Router `app/rutas/claude.py`: POST /sesion (recibe evento), GET /resumen (agrega por período)
- Config: variables `CLAUDE_PRESUPUESTO_USD`, `CLAUDE_DIA_RESETEO`
- Integración: registrado router en principal.py
- Documentación: actualizado CLAUDE.md, roadmap.md, bitacora.md de MediDo

**Arquitectura:**
- POST idempotente: UNIQUE en session_id previene duplicados en reintentos del hook
- GET /resumen: agrega tokens por período (día/semana/mes)
- Presupuesto opcional: calcula saldo, porcentaje, días restantes
- Reseteo flexible: día configurable (no siempre el 1ro del mes)

**Push:** Commit 46c3e08 en acabellan1868-prog/MediDo

**Próxima fase:** 13c (tarjeta portal consumiendo GET /resumen)

---

## 2026-04-02 (tarde)

### Fase 13a: Hook verificado e instalación de Python

**Problema:** El hook "Stop" no se ejecutaba porque `python` no estaba disponible en Windows.
Se intentó con bash (dentro de Git Bash/WSL) pero los alias de Microsoft Store interferían.

**Solución:**
1. Instalación: Python 3.14.3 desde Microsoft Store (ejecutando `python` en PowerShell)
2. Cambio del hook: `python` → `py` (lanzador estándar de Python en Windows que no tiene conflictos)
3. Test manual: Script probado con JSON de prueba, creación de `cola_sync.jsonl` verificada

**Cambios en `~/.claude/settings.json`:**
```json
"command": "py C:\\Users\\familiaAlvarezBascon\\.claude\\claude-tracker.py"
```

**Verificación:**
- Hook funciona: ejecutado manualmente con `py claude-tracker.py` → cola creada correctamente
- Estructura correcta: session_id, tokens, costes (input/output/cache), sincronizado: false
- Listo para próxima sesión: al cerrar sesión de Claude Code, hook capturará datos reales

---

## 2026-04-02 (tarde anterior)

### Fase 13a: Hook de Claude Code implementado

Se implementó el sistema de tracking de sesiones de Claude Code. El objetivo es capturar
tokens y coste de cada sesión para mostrar en una tarjeta del portal (Fase 13).

**Limitaciones y alcance:**
- Solo captura Claude Code (CLI). Claude Chat web no tiene hooks accesibles.
- Las APIs oficiales de Anthropic requieren Admin API key (solo organizaciones), no aplica a Pro/Max.
- Solución: hooks locales de Claude Code + envío a MediDo.

**Arquitectura offline-first:**
```
Claude Code termina sesión (cualquier equipo)
  └─ Hook "Stop" ejecuta claude-tracker.py
      ├─ Guarda en cola local: ~/.claude/cola_sync.jsonl (siempre funciona)
      ├─ Intenta POST a MediDo (http://192.168.31.131/salud/api/claude/sesion)
      └─ Si falla → reintenta entradas pendientes al volver a red
```

**Cambios realizados:**

**Script local** (`~/.claude/claude-tracker.py`):
- Recibe JSON del hook por stdin (session_id, input/output/cache tokens)
- Calcula coste en USD según precios Sonnet 4.6:
  - Input: $3.0/Mtok, Output: $15.0/Mtok
  - Cache read: $0.30/Mtok, Cache creation: $3.75/Mtok
- Guarda en cola JSONL con estructura completa
- Intenta POST a MediDo; si falla, queda en cola para sincronizar después
- Si POST OK → reintenta entradas pendientes (sincronización retroactiva)

**Hook configurado** (`~/.claude/settings.json`):
- Sección `hooks.Stop[]` con comando: `python ~/.claude/claude-tracker.py`
- Se dispara al terminar cualquier sesión de Claude Code

**Estructura de datos guardada:**
```json
{
  "session_id": "abc123",
  "fecha_fin": "2026-04-02T15:30:45.123456+00:00",
  "directorio": "C:\\...",
  "proyecto": "Desarrollo",
  "input_tokens": 15420,
  "output_tokens": 3210,
  "cache_read_tokens": 8500,
  "cache_creation_tokens": 2100,
  "coste_input_usd": 0.04626,
  "coste_output_usd": 0.04815,
  "coste_cache_usd": 0.00825,
  "sincronizado": false
}
```

**Próxima fase (13b):** Crear tabla `claude_sesiones` en MediDo e implementar
endpoints POST (recibir del hook) y GET (exponer resumen para el portal).

## 2026-03-31

### Centro de Alertas unificado (Fase 12)

Problema detectado: las alertas de cada app (ReDo, MediDo) estaban aisladas.
ReDo las guardaba en BD pero no las mostraba. MediDo tenía su propio tab.
Para verlas había que ir a la app NTFY del móvil. Sin gestión posible.

Se investigó si NTFY podía servir como fuente central, pero su API no permite
eliminar, marcar como leída ni consultar histórico persistente. Solo caché de
unas pocas horas. Conclusión: NTFY sigue como "timbre", la gestión vive en las BDs.

Se evaluaron tres opciones (A: agregador, B: hub central, A+: híbrida).
Se eligió la **Opción A** (agregación desde el portal) para no duplicar datos
y mantener cada app como fuente de verdad de sus alertas.

**Cambios realizados:**

**ReDo** (`app/rutas/alertas.py` nuevo):
- Migración: campo `resuelta` en tabla `alertas`
- 3 endpoints: `GET /api/alertas`, `POST /api/alertas/{id}/resolver`, `DELETE /api/alertas/{id}`
- Respuesta incluye `modulo: "redo"` para el contrato estándar

**MediDo** (`app/rutas/alertas.py` modificado):
- Campo `modulo: "medido"` en la respuesta de `GET /api/alertas`
- Nuevo endpoint `DELETE /api/alertas/{id}`

**Portal** (`portal/index.html`):
- Sustituida sección "Alertas recientes" (solo memoria JS) por Centro de Alertas real
- Consulta `GET /red/api/alertas` y `GET /salud/api/alertas` cada 60 segundos
- Agrega, ordena (activas primero + fecha desc) y renderiza lista unificada
- Filtros por estado (todas/activas/resueltas) y por módulo (todos/ReDo/MediDo)
- Botones Resolver y Eliminar que llaman al API de cada app via proxy
- Etiqueta visual por módulo con colores del design system
- Si una app no responde, muestra aviso sin bloquear las demás

**Documentación:** `analisis-mejoras.md` sección 3, `roadmap.md` Fase 12.

## 2026-03-28

### Correcciones en scripts de backup

Detectados y corregidos tres errores tras ejecutar el backup completo:
- `rsync`: añadido `--no-owner --no-group` (disco USB en FAT32/exFAT no soporta propietarios Unix)
- `rsync`: excluido directorio `dockmon` (no legible por antonio)
- `backup_dumps.sh`: cambiado `--all-databases` por `nextcloud` en mariadb-dump (fallo de permisos en tablas del sistema)

Añadido script `montar_disco.sh` para detección y montaje automático del USB,
con verificación de que es el disco de backups correcto.

El MANIFIESTO ahora captura el detalle completo de errores de cada paso.

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
