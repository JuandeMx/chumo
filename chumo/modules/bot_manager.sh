#!/bin/bash
# ==========================================
# GESTOR NATIVO DE TELEGRAM BOT - MAXIMUS MX
# ==========================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

CONF_FILE="/etc/adm-lite/bot_config.json"

ui_hr() { echo -e "${CYAN}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"; }

# FunciÃ³n para instalar dependencias de Python
install_deps() {
    echo -e "${YELLOW}[+] Verificando dependencias de Python y Herramientas de CompilaciÃ³n...${NC}"
    rm -f /etc/apt/sources.list.d/monarx.list 2>/dev/null
    apt-get update -y >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pip python3-dev sqlite3 gcc make >/dev/null 2>&1
    pip3 install --upgrade pip --break-system-packages >/dev/null 2>&1
    pip3 install pyTelegramBotAPI psutil --break-system-packages >/dev/null 2>&1
    echo -e "${GREEN}[OK] Dependencias listas.${NC}"
}

# FunciÃ³n para configurar credenciales
config_bot() {
    ui_hr
    echo -e "       ${YELLOW}âš™ï¸ CONFIGURACIÃ“N DEL BOT DE TELEGRAM${NC}"
    ui_hr
    read -p " ðŸ”¹ Bot Token (de @BotFather): " TOKEN
    read -p " ðŸ”¹ Admin ID (tu ID de Telegram): " ADMIN_ID
    read -p " ðŸ”¹ Dominio/IP (Enter si no tienes): " DOMAIN
    
    read -p " ðŸ”¹ Comando de inicio (Ej: start, vip, free) [Default: vip]: " BOT_COMMAND
    BOT_COMMAND=${BOT_COMMAND:-vip}
    
    mkdir -p /etc/adm-lite/core
    cat <<EOF > "$CONF_FILE"
{
    "BOT_TOKEN": "$TOKEN",
    "ADMIN_ID": $ADMIN_ID,
    "HOST_DOMAIN": "$DOMAIN",
    "BOT_COMMAND": "$BOT_COMMAND"
}
EOF
    echo -e "${GREEN}âœ… ConfiguraciÃ³n guardada en $CONF_FILE${NC}"
    sleep 2
}

# Principal
while true; do
    clear
    ui_hr
    echo -e "          ${GREEN}ðŸ¤– GESTOR DE TELEGRAM BOT PREMIUM${NC}"
    ui_hr
    
    # DetecciÃ³n de Estado
    systemctl is-active --quiet maximus-bot && st="${GREEN}[ACTIVO]${NC}" || st="${RED}[APAGADO]${NC}"
    
    echo -e "  Estado actual: $st"
    ui_hr
    echo -e "  ${CYAN}[1]>${WHITE} INSTALAR / REINSTALAR MOTOR BOT${NC}"
    echo -e "  ${CYAN}[2]>${WHITE} CONFIGURAR CREDENCIALES (Token/ID)${NC}"
    echo -e "  ${CYAN}[3]>${GREEN} INICIAR BOT${NC}"
    echo -e "  ${CYAN}[4]>${RED} DETENER BOT${NC}"
    echo -e "  ${CYAN}[5]>${WHITE} VER REGISTRO DE ACTIVIDAD (LOGS)${NC}"
    ui_hr
    echo -e "  ${WHITE}[0] VOLVER AL PANEL MX${NC}"
    ui_hr
    read -p " Selecciona una opciÃ³n: " opt
    
    case $opt in
        1) 
            install_deps
            # Crear servicio si no existe
            if [ ! -f /etc/systemd/system/maximus-bot.service ]; then
                cat <<EOF > /etc/systemd/system/maximus-bot.service
[Unit]
Description=Maximus Elite Telegram Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/adm-lite
ExecStart=/usr/bin/python3 /etc/adm-lite/bot.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
                systemctl daemon-reload
                echo -e "${GREEN}âœ… Servicio systemd creado.${NC}"
            fi
            echo -e "${GREEN}âœ… Motor del bot instalado.${NC}"
            sleep 2 ;;
        2) config_bot ;;
        3) 
            if [ ! -f "$CONF_FILE" ]; then
                echo -e "${RED}âŒ Error: Primero debes configurar las credenciales (OpciÃ³n 2).${NC}"
                sleep 2
            else
                systemctl enable --now maximus-bot
                echo -e "${GREEN}âœ… Bot iniciado.${NC}"
                sleep 1
            fi ;;
        4) systemctl stop maximus-bot; echo -e "${RED}âš ï¸ Bot detenido.${NC}"; sleep 1 ;;
        5) ui_hr ; journalctl -u maximus-bot -n 20 --no-pager ; ui_hr ; read -p "Presiona Enter..." ;;
        0) break ;;
    esac
done
