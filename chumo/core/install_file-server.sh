#!/bin/bash
# ChumoGH - File Server Module (HTTP Downloads)
# Port: 8888

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

FILES_DIR="/root/openvpn-clients"
PORT=8081

ensure_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}âŒ Solo root puede ejecutar este mÃ³dulo.${NC}"
        exit 1
    fi
}

install_fileserver() {
    ensure_root
    echo -e "${CYAN}=========================================================${NC}"
    echo -e "${YELLOW}           INSTALANDO SERVIDOR DE DESCARGAS${NC}"
    echo -e "${CYAN}=========================================================${NC}"

    mkdir -p "$FILES_DIR" 2>/dev/null
    chmod 755 "$FILES_DIR" 2>/dev/null

    echo -ne "${GREEN}[+] Creando servicio mx-fileserver...${NC}"
    cat > /etc/systemd/system/mx-fileserver.service <<EOF
[Unit]
Description=ChumoGH File Server for Downloads
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$FILES_DIR
ExecStart=/usr/bin/python3 -m http.server $PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    echo -e " ${GREEN}[OK]${NC}"

    echo -ne "${GREEN}[+] Abriendo puerto $PORT en UFW...${NC}"
    ufw allow $PORT/tcp >/dev/null 2>&1 || true
    echo -e " ${GREEN}[OK]${NC}"

    echo -ne "${GREEN}[+] Iniciando servicio...${NC}"
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable mx-fileserver >/dev/null 2>&1
    systemctl restart mx-fileserver >/dev/null 2>&1
    echo -e " ${GREEN}[OK]${NC}"

    echo -e "${CYAN}---------------------------------------------------------${NC}"
    echo -e "${GREEN}âœ… Servidor activo en puerto: ${WHITE}$PORT${NC}"
    echo -e "${GREEN}âœ… Carpeta: ${WHITE}$FILES_DIR${NC}"
    echo -e "${CYAN}=========================================================${NC}"
}

uninstall_fileserver() {
    echo -e "${RED}[+] Eliminando servidor de descargas...${NC}"
    systemctl stop mx-fileserver >/dev/null 2>&1 || true
    systemctl disable mx-fileserver >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/mx-fileserver.service >/dev/null 2>&1
    ufw delete allow $PORT/tcp >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1
    echo -e "${GREEN}âœ… Servidor eliminado.${NC}"
}

if [[ "$1" == "--uninstall" ]]; then
    uninstall_fileserver
else
    install_fileserver
fi
