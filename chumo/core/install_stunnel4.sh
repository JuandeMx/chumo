#!/bin/bash
# ChumoGH - Master SSL Installer v4.0 (Agnostic Edition)
# Soporta Modo Directo, Proxy e HÃ­brido Universal

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

clear
echo -e "${CYAN}=======================================================${NC}"
echo -e "${YELLOW}       ðŸ”§ CONFIGURACIÃ“N SUPREMA: STUNNEL (SSL)${NC}"
echo -e "${CYAN}=======================================================${NC}"

# ParÃ¡metros: $1 = opciÃ³n (1,2,3), $2 = puerto SSL (opcional)
option=$1
SSL_PORT=${2:-443}

# Si no se pasa puerto, solicitar al usuario segÃºn modo
if [ -z "$2" ]; then
    echo -e " Elige la modalidad de conexiÃ³n para el puerto $SSL_PORT:"
    echo -ne "${RED}-------------------------------------------------------${NC}\n"
    echo -e " [1] SSL DIRECTO (SSL â†’ SSH)"
    echo -e "     ${YELLOW}* El clÃ¡sico, mÃ¡xima velocidad, sin Payloads ni Websockets.${NC}"
    echo -e " [2] HÃBRIDO MÃXIMO (Puerto 80 + 443)"
    echo -e "     ${YELLOW}* Motor AgnÃ³stico Universal usando puerto 80 (Soporta TODAS las combinaciones).${NC}"
    echo -e " [3] HÃBRIDO UNIVERSAL (Puerto 80 + 443)"
    echo -e "     ${YELLOW}* El modo recomendado, compatible con todos los payloads en puerto 80.${NC}"
    echo -ne "${RED}-------------------------------------------------------${NC}\n"
    read -p " Selecciona una opciÃ³n [1-3]: " mode_opt
else
    mode_opt=$option
fi

# Variables por defecto
BACKEND_PORT=22
CONNECT_TARGET="127.0.0.1:22"

case $mode_opt in
    1)
        echo -e "\n${CYAN}â–¶ MODO DIRECTO SELECCIONADO${NC}"
        if [ -z "$2" ]; then
            read -p " Puerto SSL (Default 443): " SSL_PORT
            [ -z "$SSL_PORT" ] && SSL_PORT=443
        fi
        if systemctl is-active --quiet dropbear; then
            BACKEND_PORT=$(grep "DROPBEAR_PORT=" /etc/default/dropbear | cut -d= -f2 | tr -d '"')
            [ -z "$BACKEND_PORT" ] && BACKEND_PORT=44
        fi
        CONNECT_TARGET="127.0.0.1:$BACKEND_PORT"
        ;;
    2)
        echo -e "\n${CYAN}â–¶ MODO PROXY/HÃBRIDO SELECCIONADO${NC}"
        if [ -z "$2" ]; then
            read -p " Puerto SSL (Default 443): " SSL_PORT
            [ -z "$SSL_PORT" ] && SSL_PORT=443
        fi
        PROXY_PORT=80
        echo -e "${YELLOW}[+] Levantando Proxy en puerto $PROXY_PORT...${NC}"
        bash /etc/adm-lite/modules/install_mx-proxy.sh $PROXY_PORT > /dev/null 2>&1
        CONNECT_TARGET="127.0.0.1:$PROXY_PORT"
        ;;
    3)
        echo -e "\n${CYAN}â–¶ MODO HÃBRIDO UNIVERSAL SELECCIONADO${NC}"
        if [ -z "$2" ]; then
            read -p " Puerto SSL (Default 443): " SSL_PORT
            [ -z "$SSL_PORT" ] && SSL_PORT=443
        fi
        PROXY_PORT=80
        echo -e "${YELLOW}[+] Levantando Proxy Universal (AgnÃ³stico) en puerto $PROXY_PORT...${NC}"
        bash /etc/adm-lite/modules/install_mx-proxy.sh $PROXY_PORT > /dev/null 2>&1
        CONNECT_TARGET="127.0.0.1:$PROXY_PORT"
        ;;
    *)
        echo -e "${RED}OpciÃ³n invÃ¡lida.${NC}"
        exit 1
        ;;
esac

# --- INSTALACIÃ“N Y LIMPIEZA NUCLEAR ---
echo -e "\n${YELLOW}[+] Limpieza de puerto $SSL_PORT y aplicaciÃ³n SSL...${NC}"
fuser -k "$SSL_PORT/tcp" 2>/dev/null
apt-get install stunnel4 -y > /dev/null 2>&1

# Asegurar logs
mkdir -p /var/log/stunnel4
chown stunnel4:stunnel4 /var/log/stunnel4

# Generar ConfiguraciÃ³n
mkdir -p /etc/stunnel
cat > /etc/stunnel/stunnel.conf << EOF
cert = /etc/stunnel/stunnel.pem
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
socket = l:SO_KEEPALIVE=1
socket = r:SO_KEEPALIVE=1
TIMEOUTclose = 0
TIMEOUTconnect = 20
TIMEOUTidle = 28800

# Compatibilidad Suprema
sslVersion = all
options = NO_SSLv2
options = NO_SSLv3
ciphers = HIGH:!aNULL:!MD5

[maximus-ssl]
client = no
accept = $SSL_PORT
connect = $CONNECT_TARGET
EOF

# Certificado (Auto-regeneraciÃ³n)
echo -e "${YELLOW}[+] Generando certificado SSL Premium...${NC}"
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -sha256 -subj "/CN=ChumoGH/O=Maximus/C=US" -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem > /dev/null 2>&1

# Habilitar y Reiniciar
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4 2>/dev/null
ufw allow $SSL_PORT/tcp 2>/dev/null

systemctl daemon-reload
systemctl enable stunnel4 > /dev/null 2>&1
systemctl restart stunnel4
