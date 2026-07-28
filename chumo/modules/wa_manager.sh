#!/bin/bash
# ==========================================
# GESTOR NATIVO DE WHATSAPP BOT - MAXIMUS MX
# ==========================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ui_hr() { echo -e "${CYAN}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"; }

# FunciÃ³n para instalar dependencias
install_deps() {
    echo -e "${YELLOW}[+] Verificando e instalando Node.js y dependencias del sistema...${NC}"
    
    # 1. Instalar Node.js y npm si no existen
    if ! command -v node >/dev/null 2>&1; then
        echo -e "${YELLOW}[+] Node.js no detectado. Instalando Node.js 18...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
        apt-get install -y nodejs >/dev/null 2>&1
    fi
    
    if ! command -v node >/dev/null 2>&1; then
        echo -e "${RED}âŒ Error: No se pudo instalar Node.js. Por favor instÃ¡lelo manualmente.${NC}"
        sleep 2
        return 1
    fi
    
    echo -e "${GREEN}[OK] Node.js versiÃ³n: $(node -v) detectado.${NC}"

    # 2. Instalar mÃ³dulos npm locales de Baileys
    echo -e "${YELLOW}[+] Instalando mÃ³dulos de Node.js locales (Baileys, Pino, QR)...${NC}"
    if [ -d "/etc/adm-lite/core/MaximusWA" ]; then
        cd /etc/adm-lite/core/MaximusWA || exit 1
        
        # Limpieza previa para evitar incompatibilidades
        rm -f package-lock.json
        rm -rf node_modules
        
        # Ejecutar instalador mostrando la salida y verificando errores
        if npm install --no-audit --no-fund; then
            echo -e "${GREEN}[OK] MÃ³dulos de Node.js instalados con Ã©xito.${NC}"
        else
            echo -e "${YELLOW}[!] Reintentando instalaciÃ³n con --legacy-peer-deps...${NC}"
            if npm install --no-audit --no-fund --legacy-peer-deps; then
                echo -e "${GREEN}[OK] MÃ³dulos de Node.js instalados con Ã©xito.${NC}"
            else
                echo -e "${RED}âŒ Error: No se pudieron instalar las dependencias de Node.js.${NC}"
                echo -e "${YELLOW}Intenta ejecutar manualmente: cd /etc/adm-lite/core/MaximusWA && npm install${NC}"
                sleep 5
                return 1
            fi
        fi
    else
        echo -e "${RED}âŒ Error: No se encontrÃ³ el directorio /etc/adm-lite/core/MaximusWA${NC}"
        sleep 2
        return 1
    fi

    # 3. Crear el servicio de systemd para el daemon
    echo -e "${YELLOW}[+] Registrando el servicio del Bot de WhatsApp en systemd...${NC}"
    NODE_PATH=$(which node || echo "/usr/bin/node")
    cat <<EOF > /etc/systemd/system/maximus-wa.service
[Unit]
Description=Maximus WhatsApp Moderation Bot Daemon
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/adm-lite/core/MaximusWA
ExecStart=$NODE_PATH bot.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    echo -e "${GREEN}[OK] Servicio systemd maximus-wa.service registrado exitosamente.${NC}"
    sleep 2
}

# Vincular cuenta y elegir grupos
vincular_bot() {
    clear
    ui_hr
    echo -e "       ${YELLOW}ðŸ“² VINCULAR WHATSAPP Y SELECCIONAR GRUPOS${NC}"
    ui_hr
    echo -e "1. Se detendrÃ¡ el bot temporalmente (si estÃ¡ corriendo)."
    echo -e "2. AparecerÃ¡ un cÃ³digo QR grande en pantalla."
    echo -e "3. EscanÃ©alo con tu app de WhatsApp (Dispositivos Vinculados)."
    echo -e "4. Selecciona quÃ© grupos va a administrar el bot."
    ui_hr
    read -p "Presiona Enter para continuar..."
    
    # Detener el bot por si estÃ¡ activo
    systemctl stop maximus-wa 2>/dev/null
    
    cd /etc/adm-lite/core/MaximusWA || exit 1
    
    # Ejecutar en primer plano interactivo
    node get_groups.js
    
    ui_hr
    echo -e "${GREEN}VÃ­nculo completado. Ya puedes iniciar el bot en la opciÃ³n 3.${NC}"
    read -p "Presiona Enter para volver..."
}

# Principal loop
while true; do
    clear
    ui_hr
    echo -e "          ${GREEN}ðŸ¤– GESTOR DE WHATSAPP BOT PREMIUM${NC}"
    ui_hr
    
    # DetecciÃ³n de Estado
    systemctl is-active --quiet maximus-wa && st_wa="${GREEN}[ACTIVO]${NC}" || st_wa="${RED}[APAGADO]${NC}"
    
    echo -e "  Estado del Bot WA : $st_wa"
    ui_hr
    echo -e "  ${CYAN}[1]>${WHITE} INSTALAR / REINSTALAR MOTOR Y DEPENDENCIAS${NC}"
    echo -e "  ${CYAN}[2]>${YELLOW} VINCULAR DISPOSITIVO Y SELECCIONAR GRUPOS${NC}"
    echo -e "  ${CYAN}[3]>${GREEN} INICIAR BOT WHATSAPP${NC}"
    echo -e "  ${CYAN}[4]>${RED} DETENER BOT WHATSAPP${NC}"
    echo -e "  ${CYAN}[5]>${WHITE} VER REGISTRO DE ACTIVIDAD (LOGS)${NC}"
    ui_hr
    echo -e "  ${WHITE}[0] VOLVER AL PANEL AJUSTES${NC}"
    ui_hr
    read -p " Selecciona una opciÃ³n: " opt
    
    case $opt in
        1) install_deps ;;
        2) 
            if [ ! -d "/etc/adm-lite/core/MaximusWA/node_modules" ]; then
                echo -e "${RED}âŒ Error: Primero instala el motor y dependencias (OpciÃ³n 1).${NC}"
                sleep 2
            else
                vincular_bot
            fi
            ;;
        3) 
            if [ ! -f "/etc/adm-lite/wa_groups.json" ]; then
                echo -e "${RED}âŒ Error: Debes vincular tu dispositivo y seleccionar grupos (OpciÃ³n 2).${NC}"
                sleep 2
            else
                echo -e "${YELLOW}[+] Levantando servicios de WhatsApp...${NC}"
                systemctl enable maximus-wa 2>/dev/null
                systemctl start maximus-wa 2>/dev/null
                echo -e "${GREEN}âœ… Bot de WhatsApp iniciado.${NC}"
                sleep 1.5
            fi
            ;;
        4) 
            systemctl stop maximus-wa 2>/dev/null
            echo -e "${RED}âš ï¸ Bot de WhatsApp detenido.${NC}"
            sleep 1.5
            ;;
        5) 
            ui_hr
            journalctl -u maximus-wa -n 30 --no-pager
            ui_hr
            read -p "Presiona Enter..."
            ;;
        0) break ;;
    esac
done
