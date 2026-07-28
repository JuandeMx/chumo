#!/bin/bash
# ChumoGH - Shadowsocks Manager
# Adapta la lÃ³gica de Chumo LATAM a la estÃ©tica de Maximus

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

ui_hr() { echo -e "${CYAN}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"; }
ui_subhr() { echo -e "${CYAN}â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€${NC}"; }
ui_prompt() { echo -ne "${YELLOW}$1${NC}"; }
ui_pause() { read -p "Presiona Enter para continuar..." ; }
ui_header() {
    clear
    ui_hr
    echo -e "${YELLOW}           $1${NC}"
    ui_hr
}

# Obtiene la lista de puertos en uso
mportas() {
    unset portas
    portas_var=$(lsof -V -i tcp -P -n 2>/dev/null | grep -v "ESTABLISHED" | grep -v "COMMAND" | grep "LISTEN")
    while read -r port; do
        var1=$(echo "$port" | awk '{print $1}')
        var2=$(echo "$port" | awk '{print $9}' | awk -F ":" '{print $2}')
        if [[ -n "$var1" && -n "$var2" ]]; then
            if ! echo -e "$portas" | grep -q "$var1 $var2"; then
                portas+="$var1 $var2\n"
            fi
        fi
    done <<<"$portas_var"
    echo -e "$portas"
}

get_public_ip() {
    local ip
    ip=$(wget -qO- ipv4.icanhazip.com 2>/dev/null)
    [ -z "$ip" ] && ip=$(curl -fsSL https://api.ipify.org 2>/dev/null)
    [ -z "$ip" ] && ip="127.0.0.1"
    echo "$ip"
}

# --- SHADOWSOCKS PYTHON (NORMAL) ---
ss_normal_install() {
    ui_header "INSTALAR SHADOWSOCKS PYTHON (NORMAL)"
    
    if [[ -f /etc/shadowsocks.json ]]; then
        echo -e "${YELLOW}[+] Deteniendo ssserver...${NC}"
        killall ssserver >/dev/null 2>&1
        rm -f /etc/shadowsocks.json
        echo -e "${GREEN}âœ“ Shadowsocks Normal desinstalado.${NC}"
        ui_pause
        return 0
    fi
    
    # EncriptaciÃ³n
    ciphers=(aes-256-gcm aes-192-gcm aes-128-gcm aes-256-ctr aes-192-ctr aes-128-ctr aes-256-cfb aes-192-cfb aes-128-cfb chacha20-ietf-poly1305 chacha20-ietf chacha20 rc4-md5)
    echo -e "${WHITE}Elige un mÃ©todo de encriptaciÃ³n:${NC}"
    for ((i=0; i<${#ciphers[@]}; i++)); do
        echo -e "  [${i}] - ${ciphers[$i]}"
    done
    ui_subhr
    while true; do
        read -p "Cifrado [Default 0]: " -e -i 0 idx
        if [[ $idx -ge 0 && $idx -lt ${#ciphers[@]} ]]; then
            cipher="${ciphers[$idx]}"
            break
        fi
    done
    
    ui_hr
    echo -e "${WHITE}Selecciona el puerto para Shadowsocks...${NC}"
    while true; do
        read -p "Puerto: " shadowsocksport
        if ! mportas | grep -q -w "$shadowsocksport"; then
            break
        else
            echo -e "${RED}âŒ Puerto ya en uso. Elige otro.${NC}"
        fi
    done
    
    read -p "ContraseÃ±a para Shadowsocks: " -e -i "maximus" shadowsockspwd
    
    ui_hr
    echo -e "${YELLOW}[+] Instalando dependencias (Python)...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get install python3-pip python3-setuptools libsodium-dev qrencode -y >/dev/null 2>&1
    
    # Intentar instalar shadowsocks via pip
    pip3 install shadowsocks >/dev/null 2>&1 || pip install shadowsocks >/dev/null 2>&1 || pip3 install git+https://github.com/shadowsocks/shadowsocks.git@master >/dev/null 2>&1
    
    # Escribir configuraciÃ³n shadowsocks.json
    cat <<EOF >/etc/shadowsocks.json
{
    "server":"0.0.0.0",
    "server_port":${shadowsocksport},
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":300,
    "method":"${cipher}",
    "fast_open":false
}
EOF

    ufw allow ${shadowsocksport}/tcp >/dev/null 2>&1
    ufw allow ${shadowsocksport}/udp >/dev/null 2>&1
    
    # Lanzar ssserver en screen
    screen -dmS ssnorm ssserver -c /etc/shadowsocks.json
    
    ui_hr
    if ps aux | grep -v grep | grep -q "ssserver"; then
        echo -e "${GREEN}âœ“ SHADOWSOCKS PYTHON INSTALADO CON Ã‰XITO${NC}"
        local ip_pub
        ip_pub=$(get_public_ip)
        local base_link=$(echo -n "${cipher}:${shadowsockspwd}@${ip_pub}:${shadowsocksport}" | base64 -w0)
        echo -e "\n${YELLOW}ðŸ“‹ ENLACE DE CONEXIÃ“N:${NC}"
        echo -e "${WHITE}ss://${base_link}${NC}"
    else
        echo -e "${RED}âŒ Error al iniciar ssserver. AsegÃºrese de que no falte Python.${NC}"
    fi
    ui_pause
}

# --- SHADOWSOCKS LIBEV (LIVE + OBFS) ---
ss_libev_install() {
    ui_header "INSTALAR SHADOWSOCKS LIBEV (LIV + OBFS)"
    
    if [[ -f /etc/shadowsocks-libev/config.json ]]; then
        echo -e "${YELLOW}[+] Deteniendo ss-server...${NC}"
        killall ss-server >/dev/null 2>&1
        rm -rf /etc/shadowsocks-libev
        echo -e "${GREEN}âœ“ Shadowsocks Libev desinstalado.${NC}"
        ui_pause
        return 0
    fi
    
    # Cifrado
    ciphers=(aes-256-gcm aes-192-gcm aes-128-gcm aes-256-ctr aes-192-ctr aes-128-ctr aes-256-cfb aes-192-cfb aes-128-cfb chacha20-ietf-poly1305 chacha20-ietf chacha20 rc4-md5)
    echo -e "${WHITE}Elige un mÃ©todo de encriptaciÃ³n:${NC}"
    for ((i=0; i<${#ciphers[@]}; i++)); do
        echo -e "  [${i}] - ${ciphers[$i]}"
    done
    ui_subhr
    while true; do
        read -p "Cifrado [Default 0]: " -e -i 0 idx
        if [[ $idx -ge 0 && $idx -lt ${#ciphers[@]} ]]; then
            cipher="${ciphers[$idx]}"
            break
        fi
    done
    
    ui_hr
    echo -e "${WHITE}Selecciona el puerto para Shadowsocks Libev...${NC}"
    while true; do
        read -p "Puerto: " shadowsocksport
        if ! mportas | grep -q -w "$shadowsocksport"; then
            break
        else
            echo -e "${RED}âŒ Puerto ya en uso. Elige otro.${NC}"
        fi
    done
    
    read -p "ContraseÃ±a para Shadowsocks Libev: " -e -i "maximus" shadowsockspwd
    
    # Configurar simple-obfs
    read -p "Â¿Deseas instalar simple-obfs para enmascarar trÃ¡fico? [s/n]: " -e -i n simple_obfs_opt
    obfs_plugin=""
    obfs_opts=""
    if [[ "$simple_obfs_opt" == @(s|S|y|Y) ]]; then
        echo -e "\nElija el tipo de OBFS:"
        echo -e "  [1] http"
        echo -e "  [2] tls"
        read -p "OpciÃ³n [1/2]: " -e -i 1 obfs_mode
        if [[ "$obfs_mode" == "2" ]]; then
            obfs_plugin="obfs-server"
            obfs_opts="obfs=tls"
        else
            obfs_plugin="obfs-server"
            obfs_opts="obfs=http"
        fi
    fi
    
    ui_hr
    echo -e "${YELLOW}[+] Instalando dependencias de Shadowsocks-libev (pueden tardar un momento)...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install shadowsocks-libev simple-obfs git build-essential libssl-dev libev-dev libpcre3-dev libsodium-dev libc-ares-dev qrencode -y >/dev/null 2>&1
    
    mkdir -p /etc/shadowsocks-libev
    
    # Escribir config
    if [[ -n "$obfs_plugin" ]]; then
        cat <<EOF >/etc/shadowsocks-libev/config.json
{
    "server":["0.0.0.0"],
    "mode":"tcp_and_udp",
    "server_port":${shadowsocksport},
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":300,
    "method":"${cipher}",
    "plugin":"${obfs_plugin}",
    "plugin_opts":"${obfs_opts}"
}
EOF
    else
        cat <<EOF >/etc/shadowsocks-libev/config.json
{
    "server":["0.0.0.0"],
    "mode":"tcp_and_udp",
    "server_port":${shadowsocksport},
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":300,
    "method":"${cipher}"
}
EOF
    fi

    ufw allow ${shadowsocksport}/tcp >/dev/null 2>&1
    ufw allow ${shadowsocksport}/udp >/dev/null 2>&1
    
    # Detener servicio antiguo
    systemctl stop shadowsocks-libev >/dev/null 2>&1
    systemctl disable shadowsocks-libev >/dev/null 2>&1
    
    # Ejecutar en segundo plano mediante screen para evitar problemas con systemd
    killall -9 ss-server >/dev/null 2>&1
    screen -dmS sslibev ss-server -c /etc/shadowsocks-libev/config.json
    
    ui_hr
    if ps aux | grep -v grep | grep -q "ss-server"; then
        echo -e "${GREEN}âœ“ SHADOWSOCKS LIBEV INSTALADO CON Ã‰XITO${NC}"
        local ip_pub
        ip_pub=$(get_public_ip)
        local base_link=$(echo -n "${cipher}:${shadowsockspwd}@${ip_pub}:${shadowsocksport}" | base64 -w0)
        echo -e "\n${YELLOW}ðŸ“‹ ENLACE DE CONEXIÃ“N:${NC}"
        if [[ -n "$obfs_plugin" ]]; then
            echo -e "${WHITE}ss://${base_link}/?plugin=simple-obfs;${obfs_opts}${NC}"
        else
            echo -e "${WHITE}ss://${base_link}${NC}"
        fi
    else
        echo -e "${RED}âŒ Error al iniciar ss-server. Revise su configuraciÃ³n.${NC}"
    fi
    ui_pause
}

if [[ "$1" == "1" ]]; then
    ss_normal_install
    exit 0
elif [[ "$1" == "2" ]]; then
    ss_libev_install
    exit 0
fi

while true; do
    # TelemetrÃ­a local
    ps aux | grep -v grep | grep -q "ssserver" && st_norm="${GREEN}[ ACTIVO ]${NC}" || st_norm="${RED}[ OFF ]${NC}"
    ps aux | grep -v grep | grep -q "ss-server" && st_lib="${GREEN}[ ACTIVO ]${NC}" || st_lib="${RED}[ OFF ]${NC}"
    
    ui_header "SHADOWSOCKS MANAGER"
    echo -e "  ${CYAN}[1]>${WHITE} SHADOWSOCKS NORMAL (PYTHON) ----------- $st_norm${NC}"
    echo -e "  ${CYAN}[2]>${WHITE} SHADOWSOCKS LIVE + OBFS (LIBEV) -------- $st_lib${NC}"
    ui_hr
    echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
    ui_hr
    ui_prompt "Selecciona una opciÃ³n: "
    read -r opcao
    
    case $opcao in
        1) ss_normal_install ;;
        2) ss_libev_install ;;
        0) break ;;
        *) continue ;;
    esac
done
