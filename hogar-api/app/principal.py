import json
import os

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

aplicacion = FastAPI()

RUTA_JSON = os.getenv("LANZADOR_JSON", "/app/data/lanzador.json")
RUTA_BACKUP_JSON = os.getenv("BACKUP_JSON", "/app/data/backup_estado.json")

# Config por defecto si no existe el fichero persistido
CONFIG_DEFECTO = {
    "grupos": [
        {
            "id": "externos",
            "titulo": "Servicios Externos",
            "enlaces": [
                {"nombre": "ChatGPT",   "descripcion": "", "url": "https://chatgpt.com/",                              "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/chatgpt.svg",        "nueva_pestana": True},
                {"nombre": "Grok",      "descripcion": "", "url": "https://grok.com/",                                 "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/grok.svg",           "nueva_pestana": True},
                {"nombre": "Gemini",    "descripcion": "", "url": "https://gemini.google.com/",                        "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/google-gemini.svg",   "nueva_pestana": True},
                {"nombre": "Claude",    "descripcion": "", "url": "https://claude.ai",                                 "icono": "emoji:\U0001f9e0",                                                               "nueva_pestana": True},
                {"nombre": "TailScale", "descripcion": "", "url": "https://login.tailscale.com/admin/machines",        "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/tailscale.svg",       "nueva_pestana": True},
            ]
        },
        {
            "id": "produccion",
            "titulo": "Produccion — Dell 7050",
            "enlaces": [
                {"nombre": "ProxMox",       "descripcion": "Dell 7050",         "url": "http://192.168.31.103:8006/#v1:0:18:4::::::::", "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/proxmox.svg",                      "nueva_pestana": True},
                {"nombre": "Portainer",     "descripcion": "MV Debian 12",      "url": "http://192.168.31.131:9000/",                  "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/portainer.svg",                    "nueva_pestana": True},
                {"nombre": "Heimdall",      "descripcion": "MV Debian 12",      "url": "http://192.168.31.131:8091/",                  "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/heimdall.svg",                     "nueva_pestana": True},
                {"nombre": "Home Assistant","descripcion": "MV",                "url": "http://192.168.31.132:8123",                   "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/home-assistant.svg",               "nueva_pestana": True},
                {"nombre": "NodeRed",       "descripcion": "MV Debian 12",      "url": "http://192.168.31.131:1880/",                  "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/node-red.svg",                     "nueva_pestana": True},
                {"nombre": "NextCloud",     "descripcion": "MV Debian 12",      "url": "http://192.168.31.131:8081/",                  "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/nextcloud.svg",                    "nueva_pestana": True},
                {"nombre": "Jupyter Lab",   "descripcion": "MV Debian 12",      "url": "http://192.168.31.131:8888/lab",               "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/jupyter.svg",                      "nueva_pestana": True},
                {"nombre": "N8N",           "descripcion": "MV Debian 12",      "url": "http://192.168.31.131:5678/",                  "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/n8n.svg",                          "nueva_pestana": True},
                {"nombre": "Planka",        "descripcion": "MV Debian 12",      "url": "http://192.168.31.131:3010/",                  "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/planka.svg",                       "nueva_pestana": True},
                {"nombre": "DockMon",       "descripcion": "MV Debian 12",      "url": "https://192.168.31.131:8002",                  "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/docker.svg",                       "nueva_pestana": True},
                {"nombre": "FiDo",          "descripcion": "Finanzas Domesticas","url": "http://192.168.31.131:8082/",                 "icono": "emoji:\U0001f4b0",                                                                            "nueva_pestana": True},
                {"nombre": "hogarOS",       "descripcion": "Portal",            "url": "http://192.168.31.131",                        "icono": "emoji:\U0001f3e0",                                                                            "nueva_pestana": True},
            ]
        },
        {
            "id": "desarrollo",
            "titulo": "Desarrollo — Optiplex 3070",
            "enlaces": [
                {"nombre": "ProxMox",       "descripcion": "Optiplex 3070", "url": "https://192.168.31.101:8006/",    "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/proxmox.svg",                  "nueva_pestana": True},
                {"nombre": "Portainer",     "descripcion": "LXC",           "url": "http://192.168.31.111:9000/",     "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/portainer.svg",                "nueva_pestana": True},
                {"nombre": "NodeRed",       "descripcion": "LXC",           "url": "http://192.168.31.111:1880",      "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/node-red.svg",                 "nueva_pestana": True},
                {"nombre": "MLDonkey",      "descripcion": "LXC",           "url": "http://192.168.31.111:4081/",     "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/transmission.svg",             "nueva_pestana": True},
                {"nombre": "Home Assistant","descripcion": "LXC",           "url": "http://192.168.31.111:8123/",     "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/home-assistant.svg",           "nueva_pestana": True},
                {"nombre": "Heimdall",      "descripcion": "LXC",           "url": "http://192.168.31.111:8091/",     "icono": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/heimdall.svg",                "nueva_pestana": True},
            ]
        },
    ]
}


@aplicacion.get("/lanzador")
def obtener_lanzador():
    if os.path.exists(RUTA_JSON):
        with open(RUTA_JSON, encoding="utf-8") as f:
            return json.load(f)
    return CONFIG_DEFECTO


@aplicacion.put("/lanzador")
async def guardar_lanzador(peticion: Request):
    datos = await peticion.json()
    os.makedirs(os.path.dirname(RUTA_JSON), exist_ok=True)
    with open(RUTA_JSON, "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=2)
    return {"ok": True}


# ── Backup: estado del ultimo backup ──

def normalizar_backup(datos: dict) -> dict:
    """Asegura una respuesta estable aunque el script mande formatos antiguos."""
    if not datos:
        return {"ultima_fecha": None}

    respuesta = dict(datos)
    errores = int(respuesta.get("errores", respuesta.get("conteos", {}).get("errores", 0)) or 0)
    if "estado" not in respuesta:
        respuesta["estado"] = "ok" if errores == 0 else "warning"
    if "detalle" not in respuesta:
        respuesta["detalle"] = {
            clave: valor for clave, valor in respuesta.items()
            if clave not in ("ultima_fecha", "estado", "detalle")
        }
    return respuesta


@aplicacion.get("/backup")
def obtener_backup():
    if os.path.exists(RUTA_BACKUP_JSON):
        with open(RUTA_BACKUP_JSON, encoding="utf-8") as f:
            return normalizar_backup(json.load(f))
    return {"ultima_fecha": None}


@aplicacion.post("/backup")
async def registrar_backup(peticion: Request):
    datos = await peticion.json()
    os.makedirs(os.path.dirname(RUTA_BACKUP_JSON), exist_ok=True)
    with open(RUTA_BACKUP_JSON, "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=2)
    return {"ok": True}
