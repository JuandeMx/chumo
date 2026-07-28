#!/bin/bash
# Maximus Active Port Editor
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
    echo -e "           ${YELLOW}EDITOR DE PUERTOS DE SERVICIOS${NC}"
    ui_hr
}

# helper to check if a port is in use by another service
verify_port() {
    local service="$1"
    local port_to_check="$2"
    
    # check if port is currently in use
    local port_in_use=$(netstat -tuln 2>/dev/null | grep -v "127.0.0.1" | grep -w ":$port_to_check ")
    if [ -n "$port_in_use" ]; then
        # check if it is used by the same service we are modifying
        if echo "$port_in_use" | grep -q "$service"; then
            return 0 # OK, same service
        fi
        return 1 # FAIL, another service
    fi
    return 0 # OK, free
}

get_service_ports() {
    ssh_ports=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
    [ -z "$ssh_ports" ] && ssh_ports="22"
    
    dropbear_ports="Inactivo"
    if [ -f /etc/default/dropbear ]; then
        dropbear_ports=$(grep -E "^DROPBEAR_PORT=" /etc/default/dropbear 2>/dev/null | cut -d= -f2 | tr -d '"')
        extra_args=$(grep -E "^DROPBEAR_EXTRA_ARGS=" /etc/default/dropbear 2>/dev/null | cut -d= -f2 | tr -d '"')
        if [ -n "$extra_args" ]; then
            extra_ports=$(echo "$extra_args" | grep -oE "\-p [0-9]+" | awk '{print $2}' | tr '\n' ' ')
            dropbear_ports="$dropbear_ports $extra_ports"
        fi
    fi
    
    squid_ports="Inactivo"
    if [ -f /etc/squid/squid.conf ]; then
        squid_ports=$(grep -E "^http_port " /etc/squid/squid.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
    elif [ -f /etc/squid3/squid.conf ]; then
        squid_ports=$(grep -E "^http_port " /etc/squid3/squid.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
    fi
}

edit_ssh_port() {
    echo -e "\n${YELLOW}=== REDEFINIR PUERTOS OPENSSH ===${NC}"
    echo -e "Puertos actuales: ${GREEN}$ssh_ports${NC}"
    ui_prompt "Ingresa los nuevos puertos (separados por espacio, ej: 22 80): "
    read -r new_ports
    
    [ -z "$new_ports" ] && return
    
    # validate
    for p in $new_ports; do
        if ! verify_port "ssh" "$p"; then
            echo -e "${RED}âŒ Puerto $p ya estÃ¡ en uso por otro servicio.${NC}"
            sleep 2
            return
        fi
    done
    
    # modify sshd_config
    local config="/etc/ssh/sshd_config"
    sed -i '/^Port /d' "$config"
    for p in $new_ports; do
        echo "Port $p" >> "$config"
        ufw allow "$p"/tcp >/dev/null 2>&1
    done
    
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    echo -e "\n${GREEN}[âœ“] Puertos SSH redefinidos con Ã©xito.${NC}"
}

edit_dropbear_port() {
    if [ ! -f /etc/default/dropbear ]; then
        echo -e "\n${RED}âŒ Dropbear no estÃ¡ instalado en este sistema.${NC}"
        sleep 2
        return
    fi
    echo -e "\n${YELLOW}=== REDEFINIR PUERTOS DROPBEAR ===${NC}"
    echo -e "Puertos actuales: ${GREEN}$dropbear_ports${NC}"
    ui_prompt "Ingresa los nuevos puertos (separados por espacio, ej: 44 80): "
    read -r new_ports
    
    [ -z "$new_ports" ] && return
    
    # validate
    for p in $new_ports; do
        if ! verify_port "dropbear" "$p"; then
            echo -e "${RED}âŒ Puerto $p ya estÃ¡ en uso por otro servicio.${NC}"
            sleep 2
            return
        fi
    done
    
    # split main port and extra args
    local main_port=$(echo "$new_ports" | awk '{print $1}')
    local extra_ports=$(echo "$new_ports" | cut -d' ' -f2-)
    
    local config="/etc/default/dropbear"
    sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$main_port/g" "$config"
    
    local extra_args="-b /etc/dropbear/banner -K 30 -I 0"
    if [ -n "$extra_ports" ] && [ "$extra_ports" != "$main_port" ]; then
        for ep in $extra_ports; do
            extra_args="$extra_args -p $ep"
            ufw allow "$ep"/tcp >/dev/null 2>&1
        done
    fi
    ufw allow "$main_port"/tcp >/dev/null 2>&1
    
    sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"$extra_args\"/g" "$config"
    
    systemctl restart dropbear >/dev/null 2>&1
    echo -e "\n${GREEN}[âœ“] Puertos Dropbear redefinidos con Ã©xito.${NC}"
}

edit_squid_port() {
    local config=""
    if [ -f /etc/squid/squid.conf ]; then
        config="/etc/squid/squid.conf"
    elif [ -f /etc/squid3/squid.conf ]; then
        config="/etc/squid3/squid.conf"
    else
        echo -e "\n${RED}âŒ Squid Proxy no estÃ¡ instalado en este sistema.${NC}"
        sleep 2
        return
    fi
    
    echo -e "\n${YELLOW}=== REDEFINIR PUERTOS SQUID ===${NC}"
    echo -e "Puertos actuales: ${GREEN}$squid_ports${NC}"
    ui_prompt "Ingresa los nuevos puertos (separados por espacio, ej: 8080 3128): "
    read -r new_ports
    
    [ -z "$new_ports" ] && return
    
    # validate
    for p in $new_ports; do
        if ! verify_port "squid" "$p"; then
            echo -e "${RED}âŒ Puerto $p ya estÃ¡ en uso por otro servicio.${NC}"
            sleep 2
            return
        fi
    done
    
    # remove old ports
    sed -i '/^http_port /d' "$config"
    
    # add new ports
    for p in $new_ports; do
        echo "http_port $p" >> "$config"
        ufw allow "$p"/tcp >/dev/null 2>&1
    done
    
    systemctl restart squid 2>/dev/null || systemctl restart squid3 2>/dev/null
    echo -e "\n${GREEN}[âœ“] Puertos Squid redefinidos con Ã©xito.${NC}"
}

while true; do
    get_service_ports
    ui_header
    echo -e "  ${CYAN}PUERTOS SSH:       ${GREEN}$ssh_ports${NC}"
    echo -e "  ${CYAN}PUERTOS DROPBEAR:  ${GREEN}$dropbear_ports${NC}"
    echo -e "  ${CYAN}PUERTOS SQUID:     ${GREEN}$squid_ports${NC}"
    ui_subhr
    
    echo -e "  ${CYAN}[1]>${WHITE} Redefinir puertos OpenSSH${NC}"
    echo -e "  ${CYAN}[2]>${WHITE} Redefinir puertos Dropbear${NC}"
    echo -e "  ${CYAN}[3]>${WHITE} Redefinir puertos Squid Proxy${NC}"
    ui_hr
    echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
    ui_hr
    ui_prompt " Selecciona una opciÃ³n: "
    read opt
    
    case $opt in
        1) edit_ssh_port ; ui_pause ;;
        2) edit_dropbear_port ; ui_pause ;;
        3) edit_squid_port ; ui_pause ;;
        0) exit 0 ;;
        *) continue ;;
    esac
done
