"""
hogar-api — Módulo de briefing diario.
Recopila datos del ecosistema y envía el resumen matutino por NTFY.
"""

import json
import logging
import os
from datetime import date, datetime, timedelta

import httpx

logger = logging.getLogger("hogar-api.briefing")

# ── Variables de entorno ──────────────────────────────────────────────────────
NTFY_URL            = os.getenv("NTFY_URL", "https://ntfy.sh")
NTFY_TOPIC          = os.getenv("NTFY_TOPIC_ALERTAS", "")
HA_HOST             = os.getenv("HA_HOST", "192.168.31.132")
HA_TOKEN            = os.getenv("HA_TOKEN", "")
HA_WEATHER_ENTITY   = os.getenv("BRIEFING_HA_WEATHER_ENTITY", "weather.forecast_home")
RUTA_BACKUP_JSON    = os.getenv("BACKUP_JSON", "/app/data/backup_estado.json")

_DIAS_ES   = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]
_MESES_ES  = ["", "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]


# ── Recolectores de datos ─────────────────────────────────────────────────────

def _obtener_sistema() -> dict:
    """Consulta MediDo: CPU, RAM, disco y estado de servicios."""
    try:
        resp = httpx.get("http://medido:8084/api/resumen", timeout=5)
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        logger.warning(f"No se pudo consultar MediDo: {e}")
        return {}


def _obtener_backup() -> dict:
    """Lee el estado del último backup desde el fichero local compartido."""
    if os.path.exists(RUTA_BACKUP_JSON):
        try:
            with open(RUTA_BACKUP_JSON, encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            logger.warning(f"No se pudo leer backup_estado.json: {e}")
    return {}


def _obtener_gasto_semana() -> dict:
    """Consulta FiDo: gasto total de la semana en curso (todas las cuentas)."""
    try:
        resp = httpx.get("http://fido:8080/api/resumen?periodo=semana", timeout=5)
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        logger.warning(f"No se pudo consultar FiDo: {e}")
        return {}


def _obtener_temperatura() -> dict:
    """
    Consulta Home Assistant: temperatura actual y previsión min/max de hoy.
    Usa la entidad weather configurada en BRIEFING_HA_WEATHER_ENTITY.
    El primer elemento del forecast corresponde al día actual.
    """
    if not HA_TOKEN:
        logger.warning("HA_TOKEN no configurado, temperatura no disponible")
        return {}
    try:
        url = f"http://{HA_HOST}:8123/api/states/{HA_WEATHER_ENTITY}"
        cabeceras = {"Authorization": f"Bearer {HA_TOKEN}"}
        resp = httpx.get(url, headers=cabeceras, timeout=5)
        resp.raise_for_status()
        datos = resp.json()
        atributos = datos.get("attributes", {})
        temp_actual = atributos.get("temperature")
        forecast = atributos.get("forecast", [])
        temp_min = temp_max = None
        if forecast:
            temp_max = forecast[0].get("temperature")
            temp_min = forecast[0].get("templow")
        return {"actual": temp_actual, "min": temp_min, "max": temp_max}
    except Exception as e:
        logger.warning(f"No se pudo consultar Home Assistant: {e}")
        return {}


# ── Composición del mensaje ───────────────────────────────────────────────────

def _antiguedad_backup(ultima_fecha_str: str | None) -> str:
    """Devuelve texto legible sobre la antigüedad del último backup."""
    if not ultima_fecha_str:
        return "sin datos ⚠️"
    try:
        ultima = datetime.fromisoformat(ultima_fecha_str.replace("Z", "+00:00")).date()
        dias = (date.today() - ultima).days
        if dias == 0:
            return "hoy ✅"
        if dias == 1:
            return "hace 1 día ✅"
        if dias <= 3:
            return f"hace {dias} días ✅"
        return f"hace {dias} días ⚠️"
    except Exception:
        return "fecha inválida ⚠️"


def _componer(sistema: dict, backup: dict, finanzas: dict, temperatura: dict) -> tuple[str, str, str]:
    """
    Compone el título, cuerpo y prioridad del mensaje NTFY.
    Devuelve (titulo, cuerpo, prioridad).
    Prioridad 'high' si hay servicios caídos o backup muy antiguo.
    """
    hoy = date.today()
    titulo = f"☀️ Buenos días — {_DIAS_ES[hoy.weekday()]} {hoy.day} {_MESES_ES[hoy.month]}"
    lineas = []
    hay_problemas = False

    # Sistema (MediDo)
    if sistema:
        cpu   = sistema.get("pve_cpu_percent")
        ram   = sistema.get("pve_memoria_percent")
        disco = sistema.get("vm_disco_percent")
        partes = []
        if cpu   is not None: partes.append(f"CPU {cpu:.0f}%")
        if ram   is not None: partes.append(f"RAM {ram:.0f}%")
        if disco is not None: partes.append(f"Disco {disco:.0f}%")
        metricas = " · ".join(partes) if partes else "sin métricas"

        ok    = sistema.get("servicios_ok", 0)
        total = sistema.get("servicios_total", 0)
        caidos = total - ok
        if caidos > 0:
            hay_problemas = True
            srv = f"servicios" if caidos > 1 else "servicio"
            lineas.append(f"🖥️ Sistema: {metricas} | ⚠️ {caidos} {srv} caído{'s' if caidos > 1 else ''}")
        else:
            lineas.append(f"🖥️ Sistema: {metricas} ✅")
    else:
        lineas.append("🖥️ Sistema: sin datos")

    # Backup (hogar-api, fichero local)
    antiguedad = _antiguedad_backup(backup.get("ultima_fecha"))
    if "⚠️" in antiguedad:
        hay_problemas = True
    lineas.append(f"💾 Backup: {antiguedad}")

    # Finanzas (FiDo, semana)
    if finanzas:
        gastos  = finanzas.get("gastos", 0.0)
        semana  = finanzas.get("semana", "esta semana")
        lineas.append(f"💶 {semana}: {gastos:.2f} € gastados")
    else:
        lineas.append("💶 Semana: sin datos")

    # Temperatura (Home Assistant)
    if temperatura:
        actual = temperatura.get("actual")
        tmin   = temperatura.get("min")
        tmax   = temperatura.get("max")
        partes_t = []
        if actual is not None: partes_t.append(f"{actual}°C")
        if tmin is not None and tmax is not None: partes_t.append(f"↓{tmin}° ↑{tmax}°")
        lineas.append(f"🌡️ Exterior: {' · '.join(partes_t)}" if partes_t else "🌡️ Exterior: sin datos")
    else:
        lineas.append("🌡️ Exterior: sin datos")

    prioridad = "high" if hay_problemas else "default"
    return titulo, "\n".join(lineas), prioridad


# ── Envío NTFY ────────────────────────────────────────────────────────────────

def _enviar_ntfy(titulo: str, cuerpo: str, prioridad: str):
    """
    Publica el briefing en el topic NTFY configurado.
    Usa la API JSON de NTFY: POST al URL base con el topic en el body.
    Esto evita que la app muestre el JSON crudo como texto del mensaje.
    """
    if not NTFY_TOPIC:
        logger.warning("NTFY_TOPIC_ALERTAS no configurado, briefing no enviado")
        return
    try:
        httpx.post(
            NTFY_URL,
            json={
                "topic": NTFY_TOPIC,
                "title": titulo,
                "message": cuerpo,
                "priority": prioridad,
                "tags": ["house", "calendar"],
            },
            timeout=10,
        )
        logger.info(f"Briefing enviado: {titulo}")
    except Exception as e:
        logger.error(f"Error al enviar briefing por NTFY: {e}")


# ── Punto de entrada ──────────────────────────────────────────────────────────

def enviar_briefing():
    """Recopila datos de todo el ecosistema y envía el briefing diario por NTFY."""
    logger.info("Iniciando briefing diario...")
    sistema     = _obtener_sistema()
    backup      = _obtener_backup()
    finanzas    = _obtener_gasto_semana()
    temperatura = _obtener_temperatura()
    titulo, cuerpo, prioridad = _componer(sistema, backup, finanzas, temperatura)
    _enviar_ntfy(titulo, cuerpo, prioridad)
