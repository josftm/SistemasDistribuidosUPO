# Entorno Automatizado — Sistemas Distribuidos

Script de instalación masiva y automatizada del entorno de desarrollo para la asignatura de **Sistemas Distribuidos** (EPS, Universidad Pablo de Olavide).

## ¿Qué hace?

Dado un rango de IPs, el script se conecta por SSH a cada equipo del aula de forma **asíncrona** e instala el siguiente software:

- Actualización completa del sistema (`apt update` + `apt upgrade`)
- **Visual Studio Code** (vía snap) con la extensión **C/C++ Extension Pack**
- **GCC** — compilador de C/C++
- **OpenMPI** — `openmpi-bin`, `openmpi-doc`, `libopenmpi-dev`

Al terminar cada equipo, el script notifica al profesor con la IP, la hora y el tiempo empleado.

## Requisitos

- El equipo del profesor debe tener **Ubuntu** y acceso por red a los equipos del aula.
- Los equipos remotos deben tener **Ubuntu** con el servidor SSH activo (`openssh-server`).
- El usuario remoto debe tener permisos `sudo`.
- `sshpass` — el script lo instala automáticamente si no está disponible.

## Uso

```bash
chmod +x install_entorno.sh
./install_entorno.sh <IP_inicial> <IP_final>
```

**Ejemplo** — instalar en 30 equipos del rango `192.168.1.1` a `192.168.1.30`:

```bash
./install_entorno.sh 192.168.1.1 192.168.1.30
```

Al iniciar, el script solicitará las credenciales SSH **una única vez**:

```
Introduce las credenciales SSH para los equipos remotos:
  Usuario: eps
  Contraseña:
```

La contraseña no se almacena en ningún fichero; reside únicamente en memoria durante la ejecución.

## Salida esperada

```
======================================================
  Instalación masiva del entorno SD
  Rango: 192.168.1.1 → 192.168.1.30  (30 equipos)
  Usuario SSH: eps
  Logs: /tmp/install_sd_logs/
======================================================

▶ Lanzando instalación en 192.168.1.1...
▶ Lanzando instalación en 192.168.1.2...
...

⏳ Esperando a que terminen los 30 equipos...

✔ [10:03:42] El equipo con IP 192.168.1.3 ha terminado correctamente (187s).
✔ [10:04:01] El equipo con IP 192.168.1.1 ha terminado correctamente (201s).
...
```

## Logs

Cada equipo genera un log individual en el equipo del profesor:

```
/tmp/install_sd_logs/install_192_168_1_1.log
/tmp/install_sd_logs/install_192_168_1_2.log
...
```

Útil para depurar si algún equipo falla.

## Seguridad

> El script está diseñado para redes de aula controladas.  
> Para entornos más seguros, se recomienda distribuir una **clave SSH pública** en los equipos y prescindir de `sshpass` y autenticación por contraseña.

## Estructura del repositorio

```
.
├── install_entorno.sh   # Script principal
└── README.md
```
