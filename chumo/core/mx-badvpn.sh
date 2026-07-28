#!/bin/bash
# ChumoGH - BadVPN UDPGW Manager
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

# Instalar BadVPN binario si no existe
check_binary() {
    if [[ ! -f /usr/local/bin/badvpn-udpgw ]]; then
        echo -e "${YELLOW}[+] Descargando ejecutable BadVPN UDPGW...${NC}"
        wget -qO /usr/local/bin/badvpn-udpgw "https://raw.githubusercontent.com/NetVPS/LATAM_Oficial/main/Ejecutables/badvpn-udpgw"
        chmod 755 /usr/local/bin/badvpn-udpgw
    fi
}

activar_badvpn() {
    ui_header "ACTIVAR BADVPN (UDPGW)"
    check_binary
    
    echo -e "${WHITE}Escribe los puertos a activar de forma secuencial (separados por espacio)${NC}"
    echo -e "Ejemplo: ${GREEN}7300 7200 7100${NC} (Recomendado: ${GREEN}7300${NC})\n"
    
    read -p "Puertos: " -e -i "7300" portasx
    mkdir -p /etc/adm-lite/PortM
    echo "$portasx" > /etc/adm-lite/PortM/Badvpn.log
    
    ui_hr
    totalporta=($portasx)
    unset PORT
    for ((i = 0; i < ${#totalporta[@]}; i++)); do
        if [[ -z "$(mportas | grep -w "${totalporta[$i]}")" ]]; then
            echo -e "${YELLOW}â–¶ Puerto Elegido: ${GREEN}${totalporta[$i]} OK${NC}"
            PORT+="${totalporta[$i]}\n"
            screen -dmS badvpn-${totalporta[$i]} /usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:${totalporta[$i]} --max-clients 1000 --max-connections-for-client 10
            # Abrir puerto en firewall
            ufw allow ${totalporta[$i]}/udp >/dev/null 2>&1
        else
            echo -e "${YELLOW}â–¶ Puerto Elegido: ${RED}${totalporta[$i]} FAIL (En Uso)${NC}"
        fi
    done
    
    ui_hr
    if [[ -n "$PORT" ]]; then
        echo -e "${GREEN}âœ“ BADVPN INSTALADO/ACTIVADO CON Ã‰XITO${NC}"
    else
        echo -e "${RED}âŒ No se pudo activar ningÃºn puerto vÃ¡lido.${NC}"
    fi
    ui_pause
}

desactivar_badvpn() {
    ui_header "DESACTIVAR BADVPN"
    echo -e "${YELLOW}[+] Deteniendo todos los procesos BadVPN UDPGW...${NC}"
    
    # Detener screens
    for pid in $(ps aux | grep 'badvpn-udpgw' | grep -v grep | awk '{print $2}'); do
        kill -9 "$pid" 2>/dev/null
    done
    killall -9 badvpn-udpgw 2>/dev/null
    screen -wipe >/dev/null 2>&1
    
    rm -f /etc/adm-lite/PortM/Badvpn.log 2>/dev/null
    echo -e "${GREEN}âœ“ BADVPN DESINSTALADO / DETENIDO CON Ã‰XITO${NC}"
    ui_pause
}

while true; do
    ui_header "BADVPN UDPGW (GAMING)"
    echo -e "  ${CYAN}[1]>${WHITE} INSTALAR / ACTIVAR BADVPN${NC}"
    echo -e "  ${CYAN}[2]>${WHITE} DETENER TODOS LOS BADVPN${NC}"
    ui_hr
    echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
    ui_hr
    ui_prompt "Selecciona una opciÃ³n: "
    read -r opcao
    
    case $opcao in
        1) activar_badvpn ;;
        2) desactivar_badvpn ;;
        0) break ;;
        *) continue ;;
    esac
done
