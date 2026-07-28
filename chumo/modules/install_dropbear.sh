#!/bin/bash
# ==============================================================================
#  INSTALADOR Y COMPILADOR DROPBEAR SSH (COMPATIBLE CON HTTP CUSTOM Y UBUNTU 22-26)
# ==============================================================================

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RED='\033[1;31m'
NC='\033[0m'

clear
echo -e "${CYAN}=========================================================${NC}"
echo -e "${YELLOW}       INSTALADOR DROPBEAR CON ALGORITMOS HEREDADOS${NC}"
echo -e "${CYAN}=========================================================${NC}"

read -p " Puerto Dropbear SSH [Default 442]: " drop_port
[ -z "$drop_port" ] && drop_port=442

echo -e "\n${YELLOW}[+] Instalando dependencias de compilacion...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get install -y dropbear build-essential zlib1g-dev bzip2 libcrypt-dev libpam0g-dev >/dev/null 2>&1

echo -e "${YELLOW}[+] Compilando Dropbear 2022.83 con soporte CBC, 3DES, SHA1 y DH-Group14...${NC}"
cd /tmp
rm -rf dropbear-2022.83*
if wget -q https://matt.ucc.asn.au/dropbear/releases/dropbear-2022.83.tar.bz2 || wget -q https://dropbear.nl/mirror/releases/dropbear-2022.83.tar.bz2; then
    tar -xf dropbear-2022.83.tar.bz2
    cd dropbear-2022.83

    cat << 'LOCALOPT' > localoptions.h
#ifndef DROPBEAR_LOCALOPTIONS_H
#define DROPBEAR_LOCALOPTIONS_H

#undef DROPBEAR_ENABLE_CBC_MODE
#define DROPBEAR_ENABLE_CBC_MODE 1

#undef DROPBEAR_3DES
#define DROPBEAR_3DES 1

#undef DROPBEAR_SHA1_HMAC
#define DROPBEAR_SHA1_HMAC 1

#undef DROPBEAR_SHA1_96_HMAC
#define DROPBEAR_SHA1_96_HMAC 1

#undef DROPBEAR_RSA_SHA1
#define DROPBEAR_RSA_SHA1 1

#undef DROPBEAR_DH_GROUP14_SHA1
#define DROPBEAR_DH_GROUP14_SHA1 1

#undef DROPBEAR_DH_GROUP1_SHA1
#define DROPBEAR_DH_GROUP1_SHA1 1

#undef DROPBEAR_DSS
#define DROPBEAR_DSS 1

#undef DROPBEAR_SVR_PAM_AUTH
#define DROPBEAR_SVR_PAM_AUTH 1

#endif
LOCALOPT

    sed -i 's/#define MAX_BANNER_SIZE 2050/#define MAX_BANNER_SIZE 16384/g' sysoptions.h 2>/dev/null
    sed -i 's/#define MAX_BANNER_LINES 20/#define MAX_BANNER_LINES 100/g' sysoptions.h 2>/dev/null

    ./configure --enable-pam >/dev/null 2>&1
    make clean >/dev/null 2>&1
    make PROGRAMS="dropbear dropbearkey" -j$(nproc) >/dev/null 2>&1

    systemctl stop dropbear.socket 2>/dev/null || true
    systemctl stop dropbear 2>/dev/null || true
    
    cp -f dropbear /usr/sbin/dropbear
    cp -f dropbear /usr/bin/dropbear 2>/dev/null || true
    cp -f dropbearkey /usr/bin/dropbearkey 2>/dev/null || true
    chmod +x /usr/sbin/dropbear /usr/bin/dropbear
fi

# PAM configuracion limpia
cat << 'PAMEOF' > /etc/pam.d/dropbear
@include common-auth
@include common-account
@include common-session
PAMEOF

# Default config
cat << EOF > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=$drop_port
DROPBEAR_EXTRA_ARGS="-p 44 -p 109"
DROPBEAR_BANNER=""
DROPBEAR_RECEIVE_WINDOW=65536
EOF

# Reiniciar Dropbear
systemctl unmask dropbear 2>/dev/null
systemctl enable dropbear 2>/dev/null
systemctl restart dropbear 2>/dev/null || /etc/init.d/dropbear restart 2>/dev/null

if lsof -i :$drop_port 2>/dev/null | grep -q LISTEN || netstat -tlpn 2>/dev/null | grep -q ":$drop_port "; then
    echo -e "\n${GREEN}=========================================================${NC}"
    echo -e "${GREEN} âœ… DROPBEAR COMPILADO Y ACTIVADO EN PUERTO $drop_port${NC}"
    echo -e "${GREEN}=========================================================${NC}"
else
    echo -e "\n${RED}[!] Error al iniciar Dropbear. Verifique logs.${NC}"
fi
sleep 2