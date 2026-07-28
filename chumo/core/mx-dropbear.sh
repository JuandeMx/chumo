#!/bin/bash
# ==============================================================================
#  INSTALADOR AUTÃ‰NTICO DROPBEAR SSH (COMPATIBLE CON HTTP CUSTOM Y UBUNTU 22-26)
# ==============================================================================

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RED='\033[1;31m'
NC='\033[0m'

clear
echo -e "${CYAN}=========================================================${NC}"
echo -e "${YELLOW}             INSTALADOR DROPBEAR SSH${NC}"
echo -e "${CYAN}=========================================================${NC}"

read -p " Puerto Dropbear SSH [Default 442]: " drop_port
[ -z "$drop_port" ] && drop_port=442

echo -e "\n${YELLOW}[+] Instalando paquete Dropbear del sistema...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get install -y dropbear >/dev/null 2>&1

# Generar llaves SSH si faltan
mkdir -p /etc/dropbear
[ -f /etc/dropbear/dropbear_rsa_host_key ] || dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key >/dev/null 2>&1
[ -f /etc/dropbear/dropbear_ecdsa_host_key ] || dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key >/dev/null 2>&1

# Configurar /etc/pam.d/dropbear LIMPIO (SIN pam_exec.so stdout que corrompe el paquete SSH)
cat << 'PAMEOF' > /etc/pam.d/dropbear
@include common-auth
@include common-account
@include common-session
PAMEOF

# Configurar /etc/default/dropbear
cat << EOF > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=$drop_port
DROPBEAR_EXTRA_ARGS="-p 44 -p 109"
DROPBEAR_BANNER=""
DROPBEAR_RECEIVE_WINDOW=65536
EOF

# Reiniciar servicio Dropbear
echo -e "${YELLOW}[+] Reiniciando servicio Dropbear SSH...${NC}"
systemctl unmask dropbear 2>/dev/null
systemctl enable dropbear 2>/dev/null
systemctl restart dropbear 2>/dev/null || /etc/init.d/dropbear restart 2>/dev/null

if lsof -i :$drop_port 2>/dev/null | grep -q LISTEN || netstat -tlpn 2>/dev/null | grep -q ":$drop_port "; then
    echo -e "\n${GREEN}=========================================================${NC}"
    echo -e "${GREEN} âœ… DROPBEAR SSH ACTIVADO EXITOSAMENTE EN PUERTO $drop_port${NC}"
    echo -e "${GREEN}=========================================================${NC}"
else
    echo -e "\n${RED}[!] Advertencia: Dropbear instalado pero verifique con 'netstat -tlpn'.${NC}"
fi
sleep 2