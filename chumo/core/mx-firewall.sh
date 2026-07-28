#!/bin/bash
# Maximus Firewall & Anti-Torrent / Anti-SPAM Block
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
    echo -e "           ${YELLOW}CORTAFUEGOS & SEGURIDAD DEL VPS${NC}"
    ui_hr
}

# detect iptables version
v4iptables="iptables"
v6iptables="ip6tables"

smtp_ports="25,26,465,587"
pop3_ports="109,110,995"
imap_ports="143,218,220,993"
other_ports="24,50,57,105,106,158,209,1109,24554,60177,60179"

bt_keywords="torrent
.torrent
peer_id=
announce
info_hash
get_peers
find_node
BitTorrent
announce_peer
BitTorrent protocol
announce.php?passkey=
magnet:
xunlei
sandai
Thunder
XLLiveUD"

save_rules() {
    # Guardar persistencia
    ip6tables-save >/etc/ip6tables.up.rules 2>/dev/null
    iptables-save >/etc/iptables.up.rules 2>/dev/null
    
    # Crear script de restauraciÃ³n al iniciar si no existe
    if [ ! -f /etc/network/if-pre-up.d/iptables ]; then
        echo -e "#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules 2>/dev/null\n/sbin/ip6tables-restore < /etc/ip6tables.up.rules 2>/dev/null" >/etc/network/if-pre-up.d/iptables
        chmod +x /etc/network/if-pre-up.d/iptables
    fi
}

set_keyword_rule() {
    local action="$1" # A=add, D=delete
    local keyword="$2"
    iptables -t mangle -$action OUTPUT -m string --string "$keyword" --algo bm --to 65535 -j DROP 2>/dev/null
    ip6tables -t mangle -$action OUTPUT -m string --string "$keyword" --algo bm --to 65535 -j DROP 2>/dev/null
}

set_port_rule() {
    local action="$1" # A=add, D=delete
    local ports="$2"
    
    # Reject TCP
    iptables -t filter -$action OUTPUT -p tcp -m multiport --dports "$ports" -m state --state NEW,ESTABLISHED -j REJECT --reject-with icmp-port-unreachable 2>/dev/null
    ip6tables -t filter -$action OUTPUT -p tcp -m multiport --dports "$ports" -m state --state NEW,ESTABLISHED -j REJECT --reject-with tcp-reset 2>/dev/null
    
    # Drop UDP
    iptables -t filter -$action OUTPUT -p udp -m multiport --dports "$ports" -j DROP 2>/dev/null
    ip6tables -t filter -$action OUTPUT -p udp -m multiport --dports "$ports" -j DROP 2>/dev/null
}

block_torrent() {
    echo -e "\n${YELLOW}[+] Aplicando reglas de bloqueo Torrent en el trÃ¡fico saliente...${NC}"
    while read -r word; do
        [ -z "$word" ] && continue
        set_keyword_rule "A" "$word"
    done <<<"$bt_keywords"
    save_rules
    echo -e "${GREEN}[âœ“] Bloqueo de Torrent activado correctamente.${NC}"
}

unblock_torrent() {
    echo -e "\n${YELLOW}[+] Removiendo reglas de bloqueo Torrent...${NC}"
    while read -r word; do
        [ -z "$word" ] && continue
        set_keyword_rule "D" "$word"
    done <<<"$bt_keywords"
    save_rules
    echo -e "${GREEN}[âœ“] Bloqueo de Torrent desactivado correctamente.${NC}"
}

block_spam() {
    echo -e "\n${YELLOW}[+] Bloqueando puertos de correo SPAM...${NC}"
    for ports in $smtp_ports $pop3_ports $imap_ports $other_ports; do
        set_port_rule "A" "$ports"
    done
    save_rules
    echo -e "${GREEN}[âœ“] Puertos de correo SPAM bloqueados con Ã©xito.${NC}"
}

unblock_spam() {
    echo -e "\n${YELLOW}[+] Desbloqueando puertos de correo SPAM...${NC}"
    for ports in $smtp_ports $pop3_ports $imap_ports $other_ports; do
        set_port_rule "D" "$ports"
    done
    save_rules
    echo -e "${GREEN}[âœ“] Puertos de correo SPAM desbloqueados con Ã©xito.${NC}"
}

block_custom_port() {
    echo -e "\n${YELLOW}=== BLOQUEAR PUERTO PERSONALIZADO ===${NC}"
    echo -e "Ejemplos: 25 | 80,443 | 1000:2000"
    ui_prompt "Ingresa el puerto a bloquear: "
    read custom_port
    if [ -n "$custom_port" ]; then
        set_port_rule "A" "$custom_port"
        save_rules
        echo -e "\n${GREEN}[âœ“] Puerto $custom_port bloqueado correctamente.${NC}"
    else
        echo -e "\n${RED}Cancelado.${NC}"
    fi
}

unblock_custom_port() {
    echo -e "\n${YELLOW}=== DESBLOQUEAR PUERTO PERSONALIZADO ===${NC}"
    ui_prompt "Ingresa el puerto a desbloquear: "
    read custom_port
    if [ -n "$custom_port" ]; then
        set_port_rule "D" "$custom_port"
        save_rules
        echo -e "\n${GREEN}[âœ“] Puerto $custom_port desbloqueado correctamente.${NC}"
    else
        echo -e "\n${RED}Cancelado.${NC}"
    fi
}

reset_iptables() {
    echo -e "\n${RED}[!] Restableciendo todas las reglas de iptables a por defecto...${NC}"
    iptables -F && iptables -X && iptables -t nat -F && iptables -t nat -X 2>/dev/null
    iptables -t mangle -F && iptables -t mangle -X 2>/dev/null
    iptables -P INPUT ACCEPT && iptables -P FORWARD ACCEPT && iptables -P OUTPUT ACCEPT 2>/dev/null
    
    ip6tables -F && ip6tables -X && ip6tables -t nat -F && ip6tables -t nat -X 2>/dev/null
    ip6tables -t mangle -F && ip6tables -t mangle -X 2>/dev/null
    ip6tables -P INPUT ACCEPT && ip6tables -P FORWARD ACCEPT && ip6tables -P OUTPUT ACCEPT 2>/dev/null
    
    save_rules
    echo -e "${GREEN}[âœ“] Reglas restablecidas con Ã©xito.${NC}"
}

get_current_blocks() {
    torrent_active="${RED}[Inactivo]${NC}"
    spam_active="${RED}[Inactivo]${NC}"
    
    # Check if Torrent blocking is active
    if iptables -t mangle -L OUTPUT -n 2>/dev/null | grep -q "BitTorrent"; then
        torrent_active="${GREEN}[ACTIVO]${NC}"
    fi
    
    # Check if SPAM ports are active
    if iptables -t filter -L OUTPUT -n 2>/dev/null | grep -q "REJECT" | grep -q "dpt:25"; then
        spam_active="${GREEN}[ACTIVO]${NC}"
    fi
}

while true; do
    get_current_blocks
    ui_header
    echo -e "  ${CYAN}BLOQUEO TORRENT/P2P:  $torrent_active${NC}"
    echo -e "  ${CYAN}BLOQUEO CORREO SPAM:  $spam_active${NC}"
    ui_subhr
    
    echo -e "  ${CYAN}[1]>${WHITE} Bloquear Torrent y Redes P2P (Anti-Abuso)${NC}"
    echo -e "  ${CYAN}[2]>${WHITE} Desbloquear Torrent y Redes P2P${NC}"
    ui_subhr
    echo -e "  ${CYAN}[3]>${WHITE} Bloquear Puertos de Correo SPAM (Evita Listas Negras)${NC}"
    echo -e "  ${CYAN}[4]>${WHITE} Desbloquear Puertos de Correo SPAM${NC}"
    ui_subhr
    echo -e "  ${CYAN}[5]>${WHITE} Bloquear Puerto Personalizado (TCP/UDP)${NC}"
    echo -e "  ${CYAN}[6]>${WHITE} Desbloquear Puerto Personalizado${NC}"
    ui_subhr
    echo -e "  ${CYAN}[7]>${RED} [!] Restablecer todo Iptables (Limpiar Filtros)${NC}"
    ui_hr
    echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
    ui_hr
    ui_prompt " Selecciona una opciÃ³n: "
    read opt
    
    case $opt in
        1) block_torrent ; ui_pause ;;
        2) unblock_torrent ; ui_pause ;;
        3) block_spam ; ui_pause ;;
        4) unblock_spam ; ui_pause ;;
        5) block_custom_port ; ui_pause ;;
        6) unblock_custom_port ; ui_pause ;;
        7) reset_iptables ; ui_pause ;;
        0) exit 0 ;;
        *) continue ;;
    esac
done
