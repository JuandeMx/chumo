#!/bin/bash
# ==============================================================================
#  MÃ“DULO SSL -> PYTHON (OPCIÃ“N 15) - COMPATIBLE CON PYTHON 3 Y UBUNTU 22/24/26
# ==============================================================================

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

clear
echo -e "${CYAN}======================================================${NC}"
echo -e "${GREEN}  CONFIGURADOR SSL -> PYTHON (PORT 443 -> PORT 80 -> SSH 22)${NC}"
echo -e "${CYAN}======================================================${NC}"

# 1. Verificar e instalar paquetes en silencio
echo -e "${YELLOW}[+] Verificando e instalando dependencias (Python 3, Stunnel, OpenSSL)...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 stunnel4 openssl lsof >/dev/null 2>&1

# 2. Detener instancias antiguas y liberar puertos
pkill -f PDirect.py 2>/dev/null
pkill -f PDirect80.py 2>/dev/null
systemctl stop stunnel4 2>/dev/null
systemctl stop stunnel 2>/dev/null

echo -e "\n${CYAN}------------------------------------------------------${NC}"
read -p " Puerto Proxy Python (WebSocket) [Default 80]: " PY_PORT
[ -z "$PY_PORT" ] && PY_PORT=80

read -p " Puerto SSL Stunnel4 [Default 443]: " SSL_PORT
[ -z "$SSL_PORT" ] && SSL_PORT=443

read -p " Puerto SSH Destino [Default 22]: " SSH_PORT
[ -z "$SSH_PORT" ] && SSH_PORT=22
echo -e "${CYAN}------------------------------------------------------${NC}"

# Liberar puertos si estan ocupados por procesos colgados
fuser -k ${PY_PORT}/tcp 2>/dev/null
fuser -k ${SSL_PORT}/tcp 2>/dev/null

echo -e "\n${YELLOW}[+] Iniciando Proxy Python 3 en puerto $PY_PORT -> SSH $SSH_PORT...${NC}"

# Asegurar que PDirect.py existe en /etc/adm-lite/
if [ ! -f /etc/adm-lite/PDirect.py ]; then
    if [ -f /etc/ADMcgh/PDirect.py ]; then
        cp /etc/ADMcgh/PDirect.py /etc/adm-lite/PDirect.py 2>/dev/null
    else
        curl -sL "https://github.com/JuandeMx/chumo/raw/main/chumo/modules/PDirect.py" -o /etc/adm-lite/PDirect.py 2>/dev/null
    fi
fi

# Iniciar Proxy Python 3 en segundo plano
nohup python3 /etc/adm-lite/PDirect.py -p "$PY_PORT" -l "$SSH_PORT" >/dev/null 2>&1 &

# Generar Certificado SSL OpenSSL
echo -e "${YELLOW}[+] Generando Certificado SSL Stunnel...${NC}"
mkdir -p /etc/stunnel
openssl req -new -x509 -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem -days 3650 -nodes -subj "/C=MX/ST=CDMX/L=CDMX/O=Chumo/OU=VPS/CN=chumo" >/dev/null 2>&1

# Configurar /etc/stunnel/stunnel.conf
echo -e "${YELLOW}[+] Configurando Stunnel4 (Puerto $SSL_PORT -> Python $PY_PORT)...${NC}"
cat << EOF > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel4.pid
cert = /etc/stunnel/stunnel.pem
client = no

[ssl_python]
accept = $SSL_PORT
connect = 127.0.0.1:$PY_PORT
EOF

# Enable y restart stunnel4
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4 2>/dev/null
systemctl restart stunnel4 2>/dev/null || systemctl restart stunnel 2>/dev/null || /etc/init.d/stunnel4 restart 2>/dev/null

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN} [OK] MODULO SSL -> PYTHON ACTIVADO CORRECTAMENTE${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e " * Proxy Python 3: Puerto \e[1;33m$PY_PORT\e[0m"
echo -e " * SSL/TLS (Stunnel): Puerto \e[1;33m$SSL_PORT\e[0m"
echo -e " * Redireccion SSH: Puerto \e[1;33m$SSH_PORT\e[0m"
echo -e "${CYAN}======================================================${NC}"
sleep 3