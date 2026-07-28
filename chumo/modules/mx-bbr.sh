#!/bin/bash
# Maximus BBR TCP Acceleration (NetSpeed)
# Adapted from Chumo's LATAM script

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# UI helpers
ui_hr() { echo -e "${CYAN}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"; }
ui_subhr() { echo -e "${CYAN}â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€${NC}"; }
ui_prompt() { echo -ne "${YELLOW}$1${NC}"; }
ui_pause() { read -p "Presiona Enter para volver..." ; }

draw_banner() {
    clear
    if [ -f "/etc/adm-lite/ascii-text-art.txt" ]; then
        cat "/etc/adm-lite/ascii-text-art.txt"
    else
        echo -e "${CYAN}   __  __             _                      "
        echo "  |  \/  |           (_)                     "
        echo "  | \  / | __ ___  ___ _ __ ___  _   _ ___   "
        echo "  | |\/| |/ _\` \ \/ / | '_ \` _ \ \| | | / __|  "
        echo "  | |  | | (_| |>  <| | | | | | | |_| \__ \  "
        echo "  |_|  |_|\__,_/_/\_\_|_| |_| |_|\__,_|___/  ${NC}"
    fi
}

ui_header() {
    draw_banner
    ui_hr
    echo -e "           ${YELLOW}ACELERACIÃ“N TCP BBR / NETSPEED${NC}"
    ui_hr
}

# detect architecture and system
release="ubuntu"
bit="x64"
[ "$(uname -m)" == "aarch64" ] && bit="arm64"

remove_all() {
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sed -i '/fs.file-max/d' /etc/sysctl.conf
    sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
    sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
    sed -i '/net.core.rmem_default/d' /etc/sysctl.conf
    sed -i '/net.core.wmem_default/d' /etc/sysctl.conf
    sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
    sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_keepalive_time/d' /etc/sysctl.conf
    sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
}

check_status() {
    kernel_version=$(uname -r | awk -F "-" '{print $1}')
    kernel_version_full=$(uname -r)
    
    if [[ ${kernel_version_full} == *"bbrplus"* ]]; then
        kernel_status="BBRplus"
    elif [[ $(echo ${kernel_version} | awk -F'.' '{print $1}') -ge 4 ]] && [[ $(echo ${kernel_version} | awk -F'.' '{print $2}') -ge 9 ]] || [[ $(echo ${kernel_version} | awk -F'.' '{print $1}') -ge 5 ]]; then
        kernel_status="BBR"
    else
        kernel_status="Stock / No acelerado"
    fi
    
    active_congestion=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk -F "=" '{print $2}' | tr -d ' ')
    if [ -z "$active_congestion" ]; then
        active_congestion="Ninguno"
    fi
}

start_bbr() {
    remove_all
    echo "net.core.default_qdisc=fq" >>/etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    echo -e "\n${GREEN}[âœ“] BBR activado exitosamente en el kernel actual.${NC}"
}

start_bbrplus() {
    remove_all
    echo "net.core.default_qdisc=fq" >>/etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbrplus" >>/etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    echo -e "\n${GREEN}[âœ“] AceleraciÃ³n BBRplus activada exitosamente.${NC}"
}

install_bbrplus_kernel() {
    echo -e "\n${YELLOW}[+] Descargando e instalando Kernel con soporte BBRplus...${NC}"
    mkdir -p /tmp/bbrplus && cd /tmp/bbrplus
    
    # Descargar versiÃ³n precompilada del kernel bbrplus para Debian/Ubuntu
    github_bbr="raw.githubusercontent.com/cx9208/Linux-NetSpeed/master"
    kernel_ver="4.14.129-bbrplus"
    
    wget -N --no-check-certificate "http://${github_bbr}/bbrplus/debian-ubuntu/x64/linux-headers-${kernel_ver}.deb"
    wget -N --no-check-certificate "http://${github_bbr}/bbrplus/debian-ubuntu/x64/linux-image-${kernel_ver}.deb"
    
    if [ -f "linux-image-${kernel_ver}.deb" ]; then
        dpkg -i linux-headers-${kernel_ver}.deb linux-image-${kernel_ver}.deb
        /usr/sbin/update-grub
        cd /root && rm -rf /tmp/bbrplus
        echo -e "\n${GREEN}[âœ“] Kernel BBRplus instalado correctamente.${NC}"
        echo -e "${YELLOW}[!] Se requiere reiniciar el VPS para iniciar con el nuevo Kernel.${NC}"
        read -p "Â¿Deseas reiniciar el VPS ahora? [s/n]: " yn
        if [[ "$yn" == "s" || "$yn" == "S" ]]; then
            reboot
        fi
    else
        echo -e "\n${RED}âŒ Error al descargar el Kernel BBRplus. Verifica tu conexiÃ³n.${NC}"
    fi
}

optimize_system() {
    remove_all
    echo -e "\n${YELLOW}[+] Optimizando lÃ­mites de archivos y buffers de red...${NC}"
    
    # Escribir optimizaciones a sysctl
    echo "fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 32768
net.ipv4.ip_forward = 1" >>/etc/sysctl.conf
    
    sysctl -p >/dev/null 2>&1
    
    # LÃ­mites de seguridad PAM
    echo "*               soft    nofile           1000000
*               hard    nofile          1000000" >/etc/security/limits.conf
    
    # Aplicar a perfil
    grep -q "ulimit -SHn 1000000" /etc/profile || echo "ulimit -SHn 1000000" >>/etc/profile
    
    echo -e "\n${GREEN}[âœ“] ConfiguraciÃ³n del sistema optimizada correctamente.${NC}"
}

while true; do
    check_status
    ui_header
    
    echo -e "  ${CYAN}ESTADO KERNEL: ${WHITE}${kernel_status} (${kernel_version_full})${NC}"
    echo -e "  ${CYAN}ACELERACIÃ“N ACTIVA: ${GREEN}${active_congestion}${NC}"
    ui_subhr
    
    echo -e "  ${CYAN}[1]>${WHITE} Activar Acelerador BBR (Recomendado para Ubuntu 18/20/22+)${NC}"
    echo -e "  ${CYAN}[2]>${WHITE} Instalar Kernel BBRplus Especial (Requiere Reinicio)${NC}"
    echo -e "  ${CYAN}[3]>${WHITE} Activar Acelerador BBRplus (Solo tras instalar Kernel 2)${NC}"
    echo -e "  ${CYAN}[4]>${WHITE} Optimizar lÃ­mites del Sistema y Buffers de Red${NC}"
    echo -e "  ${CYAN}[5]>${RED} Desinstalar todas las aceleraciones y reiniciar sysctl${NC}"
    ui_hr
    echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
    ui_hr
    ui_prompt " Selecciona una opciÃ³n: "
    read opt
    
    case $opt in
        1) start_bbr ; ui_pause ;;
        2) install_bbrplus_kernel ; ui_pause ;;
        3) start_bbrplus ; ui_pause ;;
        4) optimize_system ; ui_pause ;;
        5) remove_all ; echo -e "\n${GREEN}[âœ“] AceleraciÃ³n removida.${NC}" ; ui_pause ;;
        0) exit 0 ;;
        *) continue ;;
    esac
done
