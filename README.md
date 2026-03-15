# HogarOS

> Portal doméstico unificado — gestiona tu red y tus finanzas desde una única interfaz web, desplegado en tu propio servidor.

![Mockup del portal](captura-portal.png)

---

## ¿Qué es HogarOS?

HogarOS es un portal *self-hosted* que integra las herramientas de gestión doméstica en un único dashboard accesible desde la red local. En lugar de recordar IPs y puertos para cada servicio, todo está bajo una única URL servida por Nginx en un servidor Proxmox.

**Módulos integrados:**

| Módulo | Stack | Función |
|---|---|---|
| 🔍 [ReDo](https://github.com/acabellan1868-prog/ReDo) | Python · FastAPI · nmap | Red doméstica, detección de intrusos, alertas NTFY |
| 💰 [FiDo](https://github.com/acabellan1868-prog/FiDo) | Python · FastAPI · SQLite | Finanzas domésticas, extractos bancarios, categorización |

---

## Arquitectura

```
Usuario → http://192.168.31.131
                │
                ▼
             Nginx (80)
             ├── /          → Portal (dashboard con widgets)
             ├── /red/      → ReDo
             └── /finanzas/ → FiDo
```

Cada app es independiente y se puede actualizar por separado. El portal consume sus APIs para mostrar resúmenes en tiempo real.

---

## Estado del proyecto

🚧 **En desarrollo** — actualmente en fase de diseño y planificación.

- [x] Mockup visual del portal
- [x] Arquitectura definida
- [ ] Portal HTML con widgets reales
- [ ] Nginx reverse proxy configurado
- [ ] docker-compose.yml unificado
- [ ] Despliegue en Proxmox

Consulta el [roadmap completo](roadmap.md) para ver todos los detalles técnicos y próximos pasos.

---

## Estructura del repositorio

```
hogarOS/
├── portal/              ← Frontend del dashboard (HTML/CSS/JS vanilla)
├── nginx.conf           ← Config del reverse proxy
├── docker-compose.yml   ← Orquestación de todos los servicios
├── README.md            ← Este archivo
└── roadmap.md           ← Arquitectura detallada y plan de desarrollo
```

> ReDo y FiDo viven en sus propios repositorios y se referencian como dependencias en el compose.

---

## Tecnologías

| Capa | Tecnología |
|---|---|
| Servidor | Proxmox VE |
| Contenedores | Docker + Compose |
| Reverse proxy | Nginx Alpine |
| Frontend | HTML · CSS · JS vanilla |
| ReDo | Python 3.12 · FastAPI · python-nmap |
| FiDo | Python 3.12 · FastAPI · SQLite |
