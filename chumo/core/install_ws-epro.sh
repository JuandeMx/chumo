#!/bin/bash
# ChumoGH - Instalador WS-EPRO (Python Engine)

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}=======================================================${NC}"
echo -e "${YELLOW}        ðŸ”Œ INSTALADOR WS-EPRO (MAXIMUS ENGINE)${NC}"
echo -e "${CYAN}=======================================================${NC}"
echo -e " Este proxy envolverÃ¡ trÃ¡fico SSH en WebSockets puros."

# Puertos por defecto
DEFAULT_PORT=80
DEFAULT_TARGET=44

# AutodetecciÃ³n de backend sugerido
if systemctl is-active --quiet dropbear; then
    DEFAULT_TARGET=$(grep "DROPBEAR_PORT=" /etc/default/dropbear | cut -d= -f2 | tr -d '"')
    [ -z "$DEFAULT_TARGET" ] && DEFAULT_TARGET=44
fi

read -p " Puerto para escuchar WS (Recomendado 80 o 8080) [$DEFAULT_PORT]: " WS_PORT
[ -z "$WS_PORT" ] && WS_PORT=$DEFAULT_PORT

read -p " Puerto destino (Dropbear/OpenSSH) [$DEFAULT_TARGET]: " WS_TARGET
[ -z "$WS_TARGET" ] && WS_TARGET=$DEFAULT_TARGET

# Detectar choque de puertos
if netstat -tuln | grep -q ":$WS_PORT "; then
    echo -e "\n${RED}âš ï¸  ERROR FATAL: El puerto $WS_PORT ya estÃ¡ siendo usado por otro servicio.${NC}"
    echo -e "${YELLOW}Revisa si mx-proxy o apache ya estÃ¡n corriendo ahÃ­.${NC}"
    sleep 3
    exit 1
fi

instalar_psutil_local() {
    local ARCH=$(uname -m)
    local ARCH_DEB="amd64"
    if [[ "$ARCH" == "aarch64" ]]; then
        ARCH_DEB="arm64"
    fi
    
    # Detectar SO y versiÃ³n
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        local OS_NAME=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
        local OS_VER=$(echo "$VERSION_ID" | cut -d. -f1)
    else
        local OS_NAME="ubuntu"
        local OS_VER="22"
    fi

    # Determinar quÃ© deb local usar
    local DEB_NAME=""
    if [[ "$OS_NAME" == "ubuntu" ]]; then
        if [[ "$OS_VER" == "20" ]]; then
            DEB_NAME="python3-psutil_ubuntu20_${ARCH_DEB}.deb"
        elif [[ "$OS_VER" == "24" ]]; then
            DEB_NAME="python3-psutil_ubuntu24_${ARCH_DEB}.deb"
        else
            DEB_NAME="python3-psutil_ubuntu22_${ARCH_DEB}.deb"
        fi
    elif [[ "$OS_NAME" == "debian" ]]; then
        if [[ "$OS_VER" == "11" ]]; then
            DEB_NAME="python3-psutil_debian11_${ARCH_DEB}.deb"
        else
            DEB_NAME="python3-psutil_debian12_${ARCH_DEB}.deb"
        fi
    else
        DEB_NAME="python3-psutil_ubuntu22_${ARCH_DEB}.deb"
    fi

    local DEB_FILE=""
    local S_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
    if [ -f "$S_DIR/offline/deb/$DEB_NAME" ]; then
        DEB_FILE="$S_DIR/offline/deb/$DEB_NAME"
    elif [ -f "/etc/adm-lite/modules/offline/deb/$DEB_NAME" ]; then
        DEB_FILE="/etc/adm-lite/modules/offline/deb/$DEB_NAME"
    fi

    if ! python3 -c "import psutil" 2>/dev/null; then
        if [ -n "$DEB_FILE" ] && [ -f "$DEB_FILE" ]; then
            echo -e "\e[1;33m[âš ï¸] apt no pudo instalar python3-psutil. Instalando paquete local: $(basename $DEB_FILE)... \e[0m"
            dpkg -i "$DEB_FILE" >/dev/null 2>&1
            apt-get install -y -f >/dev/null 2>&1
        else
            echo -e "\e[1;33m[âš ï¸] Instalando psutil vÃ­a pip3 fallback...\e[0m"
            pip3 install psutil --break-system-packages >/dev/null 2>&1 || pip3 install psutil >/dev/null 2>&1
        fi
    fi
}

echo -e "\n${GREEN}[+] Instalando Maximus WS-Engine...${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install -y python3 python3-psutil > /dev/null 2>&1
instalar_psutil_local

mkdir -p /etc/adm-lite/core

# Descargar desde la bÃ³veda local si existe, si no, se asume que se clonÃ³ con la rama main
if [ ! -f "/etc/adm-lite/core/ws-epro.py" ]; then
    wget -qO /etc/adm-lite/core/ws-epro.py "https://raw.githubusercontent.com/JuandeMx/MAXIMUS/main/core/ws-epro.py"
fi
chmod +x /etc/adm-lite/core/ws-epro.py

echo -e "${GREEN}[+] Configurando servicio systemd...${NC}"
cat > /etc/systemd/system/ws-epro.service << EOF
[Unit]
Description=ChumoGH WS-EPRO Proxy
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/adm-lite
ExecStart=/usr/bin/python3 /etc/adm-lite/core/ws-epro.py $WS_PORT $WS_TARGET
Restart=always
RestartSec=3
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# Reiniciar y habilitar
systemctl daemon-reload
systemctl enable --now ws-epro > /dev/null 2>&1
systemctl restart ws-epro

sleep 2
if systemctl is-active --quiet ws-epro; then
    echo -e "\n${GREEN}=======================================================${NC}"
    echo -e "${GREEN} âœ… WS-EPRO INSTALADO SATISFACTORIAMENTE${NC}"
    echo -e "${CYAN} Puerto Entrada (Payload): $WS_PORT${NC}"
    echo -e "${CYAN} Puerto Destino (Backend):  $WS_TARGET${NC}"
    echo -e "${GREEN}=======================================================${NC}"
else
    echo -e "\n${RED}=======================================================${NC}"
    echo -e "${RED} âš ï¸ Fallo al iniciar el servicio WS-EPRO.${NC}"
    echo -e "${RED}=======================================================${NC}"
fi
sleep 3
