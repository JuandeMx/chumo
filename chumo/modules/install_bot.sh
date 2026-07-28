#!/bin/bash
# ==========================================
# INSTALADOR INTERACTIVO MAXIMUS BOT v4.0
# ==========================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}ðŸ›¡ï¸ Iniciando InstalaciÃ³n de Maximus Bot Premium...${NC}"

# 1. Instalar dependencias
echo -e "${YELLOW}[1/5] Instalando dependencias de Python...${NC}"
apt-get update -y
apt-get install -y python3-pip sqlite3
pip3 install pyTelegramBotAPI psutil --break-system-packages

# 2. ConfiguraciÃ³n Interactiva
echo -e "${GREEN}âš™ï¸ CONFIGURACIÃ“N DEL BOT${NC}"
read -p "ðŸ”¹ Ingresa tu BOT_TOKEN de Telegram: " TOKEN
read -p "ðŸ”¹ Ingresa tu Admin ID (puedes verlo en @userinfobot): " ADMIN_ID
read -p "ðŸ”¹ Ingresa tu Dominio/Cloudflare (Opcional, Enter para omitir): " DOMAIN

read -p "ðŸ”¹ Comando de inicio (Ej: start, vip, free) [Default: vip]: " BOT_COMMAND
BOT_COMMAND=${BOT_COMMAND:-vip}

# 3. Crear archivo de configuraciÃ³n JSON
mkdir -p /etc/adm-lite/core
cat <<EOF > /etc/adm-lite/bot_config.json
{
    "BOT_TOKEN": "$TOKEN",
    "ADMIN_ID": $ADMIN_ID,
    "HOST_DOMAIN": "$DOMAIN",
    "BOT_COMMAND": "$BOT_COMMAND"
}
EOF

# 4. Eliminar Panel Web para liberar recursos (Como se solicitÃ³)
echo -e "${RED}[3/5] Eliminando Panel Web para optimizar sistema...${NC}"
systemctl stop maximus-panel 2>/dev/null
systemctl disable maximus-panel 2>/dev/null
rm -rf /etc/adm-lite/web-panel
rm -f /etc/systemd/system/maximus-panel.service
systemctl daemon-reload

# 5. Crear Servicio del Bot
echo -e "${YELLOW}[4/5] Configurando servicio Maximus Bot...${NC}"
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
systemctl enable maximus-bot
systemctl start maximus-bot

echo -e "${GREEN}âœ… Â¡INSTALACIÃ“N COMPLETADA!${NC}"
echo -e "ðŸ¤– Tu bot debe estar online en t.me/$(curl -s "https://api.telegram.org/bot$TOKEN/getMe" | jq -r '.result.username')"
