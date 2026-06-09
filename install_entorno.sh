#!/bin/bash
# =============================================================================
# install_entorno.sh
# Instalación automatizada y asíncrona del entorno de desarrollo SD (Ubuntu)
# Uso: ./install_entorno.sh <IP_inicial> <IP_final>
# Ejemplo: ./install_entorno.sh 192.168.1.1 192.168.1.30
# =============================================================================

set -euo pipefail

# --- Colores para la salida del maestro ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# --- Argumentos ---
if [ "$#" -ne 2 ]; then
    echo -e "${YELLOW}Uso: $0 <IP_inicial> <IP_final>${NC}"
    echo -e "Ejemplo: $0 192.168.1.1 192.168.1.30"
    exit 1
fi

IP_START="$1"
IP_END="$2"

# --- Solicitar credenciales SSH (una sola vez) ---
echo -e "${BLUE}Introduce las credenciales SSH para los equipos remotos:${NC}"
read -rp "  Usuario: " SSH_USER
read -rsp "  Contraseña: " SSH_PASS
echo ""   # salto de línea tras la contraseña oculta

LOG_DIR="/tmp/install_sd_logs"
mkdir -p "$LOG_DIR"

# --- Extraer base de red y octetos finales ---
BASE_NET=$(echo "$IP_START" | cut -d'.' -f1-3)
START_OCT=$(echo "$IP_START" | cut -d'.' -f4)
END_OCT=$(echo "$IP_END" | cut -d'.' -f4)

# Validación básica
if [ "$START_OCT" -gt "$END_OCT" ]; then
    echo -e "${RED}Error: La IP inicial debe ser menor o igual que la IP final.${NC}"
    exit 1
fi

# --- Verificar sshpass en el equipo del profesor ---
if ! command -v sshpass &>/dev/null; then
    echo -e "${YELLOW}[AVISO] sshpass no encontrado. Instalando en este equipo...${NC}"
    sudo apt-get install -y sshpass
fi

# =============================================================================
# Script remoto que se ejecutará en cada máquina alumno
# =============================================================================
# El heredoc sin comillas expande $SSH_PASS desde el entorno del profesor
read -r -d '' REMOTE_SCRIPT << REMOTE_EOF || true

set -e
export DEBIAN_FRONTEND=noninteractive
SUDO_PASS="${SSH_PASS}"

# Función auxiliar: ejecutar sudo sin prompt de contraseña
sudo_cmd() {
    echo "$SUDO_PASS" | sudo -S "$@" 2>/dev/null
}

echo "[1/4] Actualizando repositorios y paquetes del sistema..."
sudo_cmd apt-get update -y -qq
sudo_cmd apt-get upgrade -y -qq

echo "[2/4] Instalando gcc y paquetes OpenMPI..."
sudo_cmd apt-get install -y -qq gcc openmpi-bin openmpi-doc libopenmpi-dev

echo "[3/4] Instalando Visual Studio Code (snap)..."
# En Ubuntu, snap es el método nativo y más fiable para VS Code
sudo_cmd snap install code --classic

echo "[4/4] Instalando extensión C/C++ Extension Pack..."
# Instalación headless como el usuario eps
# snap añade /snap/bin al PATH; asegurarse de que está disponible
export PATH="/snap/bin:$PATH"
if code --install-extension ms-vscode.cpptools-extension-pack \
        --no-sandbox --force 2>/dev/null; then
    echo "Extensión instalada correctamente."
else
    # Fallback: marcarla para instalación al primer arranque
    mkdir -p "$HOME/.vscode"
    echo "ms-vscode.cpptools-extension-pack" >> "$HOME/.vscode/.pending-extensions"
    echo "[AVISO] La extensión se instalará la primera vez que el usuario abra VS Code."
fi

echo "[OK] Instalación completada."
REMOTE_EOF

# =============================================================================
# Función de instalación para un único host (se lanza en background)
# =============================================================================
install_on_host() {
    local IP="$1"
    local LOG="${LOG_DIR}/install_${IP//./_}.log"
    local START_TIME
    START_TIME=$(date +%s)

    # SSH con timeout y sin comprobación de host conocido
    sshpass -p "$SSH_PASS" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=15 \
        -o ServerAliveInterval=30 \
        -o BatchMode=no \
        "$SSH_USER@$IP" \
        "bash -s" <<< "$REMOTE_SCRIPT" > "$LOG" 2>&1

    local EXIT_CODE=$?
    local END_TIME
    END_TIME=$(date +%s)
    local ELAPSED=$(( END_TIME - START_TIME ))

    if [ "$EXIT_CODE" -eq 0 ]; then
        echo -e "${GREEN}✔ [$(date '+%H:%M:%S')] El equipo con IP ${IP} ha terminado correctamente (${ELAPSED}s).${NC}"
    else
        echo -e "${RED}✘ [$(date '+%H:%M:%S')] El equipo con IP ${IP} ha fallado (código $EXIT_CODE, ${ELAPSED}s).${NC}"
        echo -e "  Ver log detallado: ${LOG}"
    fi
}

# =============================================================================
# Bucle principal: lanzar instalaciones en paralelo
# =============================================================================
TOTAL=$(( END_OCT - START_OCT + 1 ))

echo -e "${BLUE}"
echo "======================================================"
echo "  Instalación masiva del entorno SD"
echo "  Rango: ${IP_START} → ${IP_END}  (${TOTAL} equipos)"
echo "  Usuario SSH: ${SSH_USER}"
echo "  Logs: ${LOG_DIR}/"
echo "======================================================"
echo -e "${NC}"

declare -A JOB_PIDS

for OCT in $(seq "$START_OCT" "$END_OCT"); do
    IP="${BASE_NET}.${OCT}"
    echo -e "${BLUE}▶ Lanzando instalación en ${IP}...${NC}"
    install_on_host "$IP" &
    JOB_PIDS["$IP"]=$!
    # Pequeña pausa para no saturar la red en rangos muy grandes
    sleep 0.5
done

echo ""
echo -e "${YELLOW}⏳ Esperando a que terminen los ${TOTAL} equipos...${NC}"
echo ""

# Esperar todos los trabajos en background
FAILED=0
for IP in "${!JOB_PIDS[@]}"; do
    wait "${JOB_PIDS[$IP]}" || (( FAILED++ )) || true
done

echo ""
echo -e "${BLUE}======================================================"
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}  ✔ Todos los equipos completaron la instalación con éxito.${NC}"
else
    echo -e "${RED}  ✘ ${FAILED} equipo(s) fallaron. Revisa los logs en ${LOG_DIR}/${NC}"
fi
echo -e "${BLUE}======================================================${NC}"
