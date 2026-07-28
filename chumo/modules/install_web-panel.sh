#!/bin/bash
# ChumoGH - Web Panel Installer v1.0 (Premium)
# Port: 8082

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

WEB_DIR="/etc/adm-lite/web-panel"

ensure_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}âŒ Solo root puede ejecutar este mÃ³dulo.${NC}"
        exit 1
    fi
}

install_web_panel() {
    ensure_root
    echo -e "${CYAN}=========================================================${NC}"
    echo -e "${YELLOW}           INSTALANDO MAXIMUS WEB PANEL v2.0 (ROOT)${NC}"
    echo -e "${CYAN}=========================================================${NC}"

    # 1. Instalar dependencias esenciales
    echo -e "${GREEN}[+] Instalando dependencias (Python, SQLite, VNStat)...${NC}"
    apt-get update -y >/dev/null 2>&1
    apt-get install -y python3-flask python3-pip sqlite3 vnstat net-tools curl ufw >/dev/null 2>&1
    
    # 2. Preparar Directorio
    echo -e "${GREEN}[+] Sincronizando archivos del panel...${NC}"
    mkdir -p "$WEB_DIR/backend" "$WEB_DIR/frontend"
    
    if [ -d "./web-panel" ]; then
        cp -r ./web-panel/* "$WEB_DIR/"
    fi

    chmod +x "$WEB_DIR/backend/app.py"

    # 3. Crear Servicio Systemd (Fuerza ROOT)
    echo -e "${GREEN}[+] Configurando servicio mx-webpanel (Privilegios Root)...${NC}"
    cat > /etc/systemd/system/mx-webpanel.service <<EOF
[Unit]
Description=ChumoGH Web Panel Backend v2.0 (Root)
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$WEB_DIR/backend
ExecStart=/usr/bin/python3 app.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # 4. Configurar Firewall
    if ufw status | grep -q "inactive"; then
        echo -e "${YELLOW}[!] UFW estÃ¡ inactivo. Permitiendo puerto 8082...${NC}"
        ufw allow 8082/tcp >/dev/null 2>&1
    else
        echo -e "${GREEN}[+] Ajustando Firewall UFW (Puerto 8082)...${NC}"
        ufw allow 8082/tcp >/dev/null 2>&1
    fi

    # 5. Iniciar y Verificar con Feedback Real
    echo -e "${GREEN}[+] Recargando Systemd y activando servicio...${NC}"
    systemctl daemon-reload
    systemctl enable mx-webpanel >/dev/null 2>&1
    
    echo -e "${YELLOW}[+] Reiniciando Maximus Web Panel Backend...${NC}"
    systemctl restart mx-webpanel >/dev/null 2>&1

    # PequeÃ±a pausa para asegurar el arranque
    sleep 3
    if systemctl is-active --quiet mx-webpanel; then
        IP_PUBLIC=$(curl -s ipv4.icanhazip.com)
        echo -e "${CYAN}---------------------------------------------------------${NC}"
        echo -e "${GREEN}âœ… PANEL WEB v2.1 OPERATIVO Y VINCULADO AL KERNEL${NC}"
        echo -e "${YELLOW} Acceso Local: http://$IP_PUBLIC:8082${NC}"
        echo -e "${BLUE} Tip: Si no abre, verifica que el puerto 8082 estÃ© libre.${NC}"
        echo -e "${CYAN}=========================================================${NC}"
    else
        echo -e "${RED}âŒ ERROR CRÃTICO: El panel no pudo iniciar.${NC}"
        echo -e "${YELLOW} Ejecuta: 'journalctl -u mx-webpanel -n 20' para debug.${NC}"
    fi
}

uninstall_web_panel() {
    echo -e "${RED}[+] Eliminando Panel Web...${NC}"
    systemctl stop mx-webpanel >/dev/null 2>&1
    systemctl disable mx-webpanel >/dev/null 2>&1
    rm -f /etc/systemd/system/mx-webpanel.service
    rm -rf "$WEB_DIR"
    ufw delete allow 8082/tcp >/dev/null 2>&1
    systemctl daemon-reload
    echo -e "${GREEN}âœ… Panel Web desinstalado.${NC}"
}

if [[ "$1" == "--uninstall" ]]; then
    uninstall_web_panel
else
    install_web_panel
fi
