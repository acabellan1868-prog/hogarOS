# Análisis: Integración de Polar Flow en hogarOS

> Documento de análisis para integrar datos de actividad física de Polar Flow.
> Última actualización: 2026-05-06

---

## 1. Qué es Polar Flow

**Polar Flow** es la plataforma de análisis de entrenamiento del fabricante **Polar** (relojes deportivos y smartwatches). Ofrece:

- Tracking de actividades deportivas (correr, ciclismo, natación, entrenamiento con pesas, etc.)
- Análisis detallado: distancia, duración, calorías quemadas, frecuencia cardíaca promedio/máxima
- Sincronización automática desde smartwatch Polar
- API REST pública para acceso a datos de usuario

### Constraint crítico: solo última actividad

La API pública de Polar **solo devuelve datos de la última actividad completada**. No existe endpoint para obtener histórico completo de un vistazo. Esto implica:

- **Necesario almacenar localmente** — consultar la API periódicamente (cada 2-3 horas) y guardar en BD
- **Construcción gradual del histórico** — el primer mes sin datos, luego se va acumulando
- **Idempotencia crítica** — evitar duplicados al consultar la misma actividad varias veces

---

## 2. Autenticación con Polar Flow

### OAuth 2.0

Polar usa OAuth 2.0. El flujo es:
1. Usuario autoriza la app en el portal de Polar
2. Recibimos un `access_token` (duración ~1 hora) y `refresh_token` (duración ~30 días)
3. Guardamos tokens en `.env` o en BD (si es refresh_token)
4. Las consultas se hacen con `Authorization: Bearer <access_token>`

### Variables de entorno

```bash
# En hogarOS/.env (orquestador)
POLAR_CLIENT_ID=<client-id-de-polar>
POLAR_CLIENT_SECRET=<client-secret-de-polar>
POLAR_ACCESS_TOKEN=<token-inicial>
POLAR_REFRESH_TOKEN=<token-para-renovar>
```

---

## 3. Opciones de integración

### Opción A: Widget ligero en hogar-api

**Descripción:** Micro-servicio `hogar-api` almacena datos de Polar en SQLite. Portal muestra tarjeta con resumen.

**Ventajas:**
- Mínimo código
- Reutiliza infraestructura existente (hogar-api + APScheduler)
- Sin nuevo contenedor

**Desventajas:**
- hogar-api se convierte en "todo para todos" (ya gestiona lanzador + backup + Polar)
- Difícil escalar si queremos análisis avanzado después

**Complejidad:** ⭐⭐ Baja-Media

---

### Opción B: App independiente PolarDo

**Descripción:** Servicio FastAPI dedicado, patrón ReDo/FiDo/MediDo.

**Ventajas:**
- Escalable — análisis IA, gráficas avanzadas, integración con otros datos
- Independencia total — puede correr sin hogarOS
- Patrón establecido en el ecosistema

**Desventajas:**
- Más código (FastAPI boilerplate)
- Nuevo contenedor que mantener
- Más lógica operacional

**Complejidad:** ⭐⭐⭐ Media

---

### Opción C: **Integración en MediDo (RECOMENDADA)**

**Descripción:** Ampliar la app existente `MediDo` con módulo deportivo. Polar se integra como fuente de datos de salud del usuario, junto a sensores Proxmox (CPU, memoria, salud del sistema).

**Ventajas:**
- **Lógica coherente:** salud del usuario + salud del sistema bajo un mismo paraguas
- **Reutiliza infraestructura:** MediDo ya tiene APScheduler + SQLite + frontend Cockpit
- **Menos contenedores:** no duplica servicios
- **Correlación interesante:** esfuerzo deportivo vs. picos de consumo del servidor (ej: ¿subió el CPU cuando corrí?)

**Desventajas:**
- MediDo es específico del hogar (no funciona desacoplado como ReDo/FiDo)
- Aumenta responsabilidad de MediDo

**Complejidad:** ⭐⭐ Baja-Media

---

## 4. Decisión: Opción C (MediDo)

**Razones:**
1. MediDo ya monitorea "salud" del ecosistema — Polar encaja naturalmente como "salud del usuario"
2. Aprovechar APScheduler existente en MediDo (no duplicar scheduler)
3. Menos operacional (menos contenedores)
4. Patrón establecido: MediDo ya sincroniza datos Proxmox, añadir Polar es extensión natural

---

## 5. Arquitectura de la integración

### 5.1 Base de datos (MediDo)

Nueva tabla en `esquema.sql`:

```sql
CREATE TABLE actividades_polar (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha_actividad DATETIME NOT NULL,
    tipo TEXT NOT NULL,                    -- "Running", "Cycling", "Swimming", etc.
    distancia_km REAL NOT NULL,             -- en kilómetros
    duracion_segundos INTEGER NOT NULL,     -- en segundos
    calorias INTEGER NOT NULL,
    hr_promedio INTEGER NOT NULL,           -- beats per minute
    hr_maxima INTEGER NOT NULL,
    temperatura_ambiente REAL,              -- opcional, si está disponible
    notas TEXT,
    fecha_sincronizacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    polar_activity_id TEXT UNIQUE NOT NULL  -- ID de Polar para evitar duplicados
);

-- Índices para consultas rápidas
CREATE INDEX idx_actividades_polar_fecha ON actividades_polar(fecha_actividad DESC);
CREATE INDEX idx_actividades_polar_tipo ON actividades_polar(tipo);
```

### 5.2 Sincronización (MediDo backend)

**Archivo:** `app/rutas/polar.py` (nuevo)

```python
# Pseudocódigo de estructura

async def sincronizar_polar():
    """
    Llamado por APScheduler cada 2-3 horas.
    1. Consulta API Polar (última actividad)
    2. Si es nueva (no existe en BD por polar_activity_id), guarda
    3. Devuelve resumen de sincronización
    """
    
async def obtener_resumen_deportivo(dias=7):
    """
    Agrega datos de los últimos N días.
    Devuelve: nº actividades, km totales, calorías, hr promedio, últimas actividades.
    """

async def obtener_historial(limite=30):
    """
    Todas las actividades (limitadas a últimas N) ordenadas por fecha.
    """
    
async def obtener_estadisticas_tipo():
    """
    Agrupación por tipo de deporte: nº actividades, km, calorías, tiempo.
    """
```

**Registrar en `principal.py`:**
```python
from app.rutas import polar
app.include_router(polar.router, prefix="/api")
```

### 5.3 APScheduler en MediDo

En `app/principal.py` (ya existe scheduler, solo añadir trigger):

```python
scheduler.add_job(
    sincronizar_polar,
    CronTrigger(hour="*/3"),  # Cada 3 horas
    id="sincronizar_polar",
    name="Sincronizar Polar Flow",
)
```

### 5.4 Frontend (MediDo)

Nueva pestaña en `MediDo/static/index.html`: **"🏃 Entrenamientos"**

**Contenido:**
- **Gráfico superior:** kilómetros por semana (barras) + calorías (línea superpuesta)
- **Grid de estadísticas:** nº actividades mes, km totales, calorías, tiempo total
- **Tabla de actividades:** últimas 20, con columnas (fecha, tipo, distancia, duración, HR avg)
- **Filtro por tipo de deporte** (opcional)

**JavaScript:**
- Cargar datos via `GET /salud/api/polar/resumen`
- Renderizar gráfico con SVG vanilla (no ApexCharts, para coherencia Cockpit)
- Tabla con scrollable horizontal en móvil

### 5.5 Portal hogarOS

**Tarjeta MediDo** ampliada con mini-resumen deportivo:
- Línea actual: "Sistema OK, T interior 22.3°C"
- Nueva línea: "🏃 7 km esta semana | 💪 4 actividades"
- Al hacer click en la tarjeta, va a MediDo pestaña Entrenamientos

Alternativa: **Tarjeta compacta separada "🏃 Entrenamientos"**
- Últimas 3 actividades en miniatura
- Click → pestaña en MediDo

---

## 6. Endpoints API de MediDo

### GET `/api/polar/resumen?dias=7`

```json
{
  "periodo_dias": 7,
  "nro_actividades": 4,
  "km_totales": 24.5,
  "calorias_totales": 2840,
  "duracion_total_minutos": 195,
  "hr_promedio_general": 145,
  "ultimas_actividades": [
    {
      "id": 123,
      "fecha": "2026-05-05T18:30:00",
      "tipo": "Running",
      "distancia_km": 8.2,
      "duracion_minutos": 65,
      "calorias": 720,
      "hr_promedio": 152,
      "hr_maxima": 178
    }
  ],
  "actividades_por_tipo": {
    "Running": { "count": 2, "km": 16.4, "calorias": 1440 },
    "Cycling": { "count": 1, "km": 7.2, "calorias": 850 },
    "Swimming": { "count": 1, "km": 0.75, "calorias": 550 }
  }
}
```

### GET `/api/polar/historial?limite=30`

```json
{
  "total": 247,
  "actividades": [
    { "id": 123, "fecha": "2026-05-05", "tipo": "Running", "distancia_km": 8.2, ... },
    ...
  ]
}
```

### POST `/api/polar/sincronizar` (manual)

Fuerza sincronización inmediata. Respuesta:
```json
{
  "exito": true,
  "nuevas_actividades": 1,
  "ultima_consulta": "2026-05-06T14:30:00",
  "proxima_programada": "2026-05-06T17:30:00"
}
```

---

## 7. Variables de entorno

En `hogarOS/.env`:

```bash
# Polar Flow — credenciales OAuth
POLAR_CLIENT_ID=tu_client_id
POLAR_CLIENT_SECRET=tu_client_secret
POLAR_ACCESS_TOKEN=tu_access_token
POLAR_REFRESH_TOKEN=tu_refresh_token

# MediDo heredará estas variables via docker-compose
# (ver CLAUDE.md de hogarOS para convención)
```

En `docker-compose.yml` de hogarOS:
```yaml
services:
  medido:
    environment:
      - POLAR_CLIENT_ID=${POLAR_CLIENT_ID}
      - POLAR_CLIENT_SECRET=${POLAR_CLIENT_SECRET}
      - POLAR_ACCESS_TOKEN=${POLAR_ACCESS_TOKEN}
      - POLAR_REFRESH_TOKEN=${POLAR_REFRESH_TOKEN}
```

---

## 8. Plan de trabajo

### Fase 1: Preparación y API de Polar
- [ ] 🤖 Registrarse en [Polar Developer Portal](https://developer.polar.com/)
- [ ] 🤖 Crear app y obtener Client ID + Secret
- [ ] 👤 Autorizar la app en portal Polar personal → obtener Access Token + Refresh Token
- [ ] 🤖 Crear módulo `app/polar_client.py` en MediDo:
  - Función `obtener_ultima_actividad()` — consulta API Polar
  - Función `renovar_token()` — refresh automático si caduca
  - Manejo de errores y reintentos

### Fase 2: Base de datos y sincronización
- [ ] 🤖 Añadir tabla `actividades_polar` a `esquema.sql`
- [ ] 🤖 Crear `app/rutas/polar.py` con:
  - `sincronizar_polar()` — obtiene última actividad y la guarda si es nueva
  - `obtener_resumen_deportivo()` — agrega datos
  - `obtener_historial()` — lista actividades
  - `obtener_estadisticas_tipo()` — agrupa por tipo
- [ ] 🤖 Registrar endpoints en `principal.py`
- [ ] 🤖 Añadir APScheduler trigger `sincronizar_polar` cada 3 horas

### Fase 3: Frontend MediDo
- [ ] 🤖 Nueva pestaña "🏃 Entrenamientos" en `index.html`
- [ ] 🤖 Gráfico SVG: kilómetros/semana + calorías
- [ ] 🤖 Tabla de actividades (últimas 30)
- [ ] 🤖 Grid de estadísticas (nº actividades, km totales, etc.)
- [ ] 🤖 `app.js`: cargar datos via `/salud/api/polar/resumen` + renderizar

### Fase 4: Portal hogarOS
- [ ] 🤖 Ampliación tarjeta MediDo: agregar mini-resumen deportivo
- [ ] 👤 Ejecutar `actualizar.sh` en la VM
- [ ] 👤 Verificar sincronización automática cada 3 horas

### Fase 5: Pulido
- [ ] 🤖 Documentación: actualizar `CLAUDE.md` de MediDo
- [ ] 🤖 Actualizar `analisis.md` de hogarOS (sección nuevos módulos)
- [ ] 🤖 `.env.example`: añadir variables POLAR_*
- [ ] 👤 Probar en móvil (responsive)
- [ ] 👤 Verificar en producción: gráficas, tabla, datos reales

---

## 9. Decisiones de diseño

### Por qué no es una app separada (Opción B)

1. **Coherencia conceptual:** Polar mide "salud del usuario" — MediDo ya mide "salud del sistema"
2. **Menos contenedores:** simplifica `docker-compose.yml`
3. **Scheduler compartido:** evita N schedulers consultando N APIs
4. **UI unificada:** una sola app "Salud", con pestañas para sistema/usuario

### Por qué no es hogar-api (Opción A)

1. **hogar-api es orquestador:** lanzador + backup. Polar es lógica de dominio.
2. **MediDo es el lugar natural:** ya es la app de salud/monitoreo
3. **Separación de responsabilidades:** hogar-api no debe tener BD propia (excepto lanzador.json)

### Autenticación OAuth

- Tokens guardados en `.env` (production-ready)
- Refresh automático cuando caduca access_token
- No requiere interacción del usuario cada 24h

### Almacenamiento local

- Polar es fuente única — consultamos cada 3h
- SQLite local es caché + histórico
- Idempotencia por `polar_activity_id` UNIQUE

---

## 10. Roadmap de futuro

Una vez que Polar esté integrado, posibles mejoras:

- **Análisis IA:** Patrón de entrenamientos + predicción de próxima sesión recomendada
- **Correlación:** Esfuerzo deportivo vs consumo de energía en Proxmox
- **Integración NTFY:** Alerta si han pasado >7 días sin actividad
- **Comparativa:** Mes vs mes anterior (rentabilidad deportiva)
- **Exportación:** CSV de actividades para análisis externo

---

## 11. Referencias

- [Polar Developer Portal](https://developer.polar.com/)
- [Polar API Documentation](https://www.polar.com/en/sports/smartwatches) (buscar "API" en la documentación)
- OAuth 2.0: [RFC 6749](https://tools.ietf.org/html/rfc6749)

---

## Resumen ejecutivo

✅ **Decisión:** Integrar Polar Flow en **MediDo** (no app separada)
✅ **Almacenamiento:** SQLite local, sincronización cada 3 horas
✅ **API:** Endpoints `/api/polar/*` en MediDo
✅ **Frontend:** Nueva pestaña "🏃 Entrenamientos" en MediDo
✅ **Portal:** Mini-resumen deportivo en tarjeta MediDo
⏱️ **Estimado:** 2-3 sesiones de trabajo (Auth + BD + Frontend)
