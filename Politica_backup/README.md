# Política de Backup — Instrucciones

## Cuándo hacer backup

La tarjeta "Estado del Backup" en el portal hogarOS avisa cuando toca:
- 🟢 Menos de 7 días — todo bien
- 🟠 Entre 7 y 14 días — toca hacer copia
- 🔴 Más de 14 días — urgente

---

## Procedimiento completo

Todo se ejecuta desde **Proxmox (host)**, no desde la VM.

### 1. Conectar el disco externo USB al servidor

### 2. Montar el disco

```bash
bash /root/montar_disco.sh
```

El script detecta el USB automáticamente y verifica que es el disco de backups.
Si hay varios USB conectados, muestra una lista para elegir.

### 3. Ejecutar el backup

```bash
bash /root/backup.sh
```

Hace automáticamente:
- Dump seguro de todas las bases de datos (FiDo, ReDo, Planka, Nextcloud)
- Copia los dumps de VMs 101 y 102 generados por Proxmox
- rsync completo de `/mnt/datos/` desde VM 101
- Rotación: guarda el backup actual y el anterior (2 copias)
- Genera `MANIFIESTO.txt` con el resumen y detalle de errores

### 4. Revisar el resultado

```bash
cat /mnt/usb1/bakup_proxmox/backup_actual/MANIFIESTO.txt
```

### 5. Desmontar el disco

```bash
umount /mnt/usb1
```

### 6. Desconectar el disco externo del servidor

---

## Estructura en el disco externo

```
/mnt/usb1/
└── bakup_proxmox/
    ├── backup_actual/          ← copia más reciente
    │   ├── MANIFIESTO.txt      ← resumen + detalle de errores
    │   ├── dumps.log           ← log completo de dumps de BDs
    │   ├── rsync.log           ← log completo del rsync
    │   ├── vms.log             ← log de copia de VMs
    │   └── datos/              ← copia de /mnt/datos/ de VM 101
    ├── backup_anterior/        ← copia de la vez anterior
    └── dump/                   ← imágenes de VMs (vzdump)
        ├── vzdump-qemu-101-*.vma.zst
        └── vzdump-qemu-102-*.vma.zst
```

---

## Actualizar los scripts en Proxmox

Si se han modificado los scripts en el repositorio:

```bash
wget -O /root/backup.sh https://raw.githubusercontent.com/acabellan1868-prog/hogarOS/main/Politica_backup/backup.sh
wget -O /root/montar_disco.sh https://raw.githubusercontent.com/acabellan1868-prog/hogarOS/main/Politica_backup/montar_disco.sh
chmod +x /root/backup.sh /root/montar_disco.sh
```

`backup_dumps.sh` se actualiza automáticamente con `./actualizar.sh` en la VM,
ya que vive en `/mnt/datos/hogarOS/Politica_backup/`.

---

## Scripts involucrados

| Script | Dónde vive | Qué hace |
|--------|-----------|----------|
| `montar_disco.sh` | `/root/` en Proxmox | Detecta y monta el USB |
| `backup.sh` | `/root/` en Proxmox | Orquesta todo el backup |
| `backup_dumps.sh` | `/mnt/datos/hogarOS/Politica_backup/` en VM 101 | Dumps de BDs (llamado por backup.sh vía SSH) |
