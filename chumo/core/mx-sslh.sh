#!/bin/bash
# ChumoGH - SSLH Multiplexer Manager
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

sslh_inicial() {
    if dpkg -l | grep -q "sslh"; then
        ui_header "DESINSTALAR SSLH MULTIPLEXER"
        echo -e "${YELLOW}[+] Deteniendo sslh...${NC}"
        systemctl stop sslh >/dev/null 2>&1
        systemctl disable sslh >/dev/null 2>&1
        DEBIAN_FRONTEND=noninteractive apt-get purge sslh -y >/dev/null 2>&1
        ui_hr
        echo -e "${GREEN}âœ“ SSLH DESINSTALADO CON Ã‰XITO${NC}"
        ui_pause
        return 0
    fi
    
    ui_header "INSTALAR SSLH MULTIPLEXER"
    echo -e "${WHITE}Durante la instalaciÃ³n se abrirÃ¡ un cuadro azul preguntando el tipo.${NC}"
    echo -e "Selecciona la opciÃ³n ${YELLOW}standalone${NC} y presiona ENTER para continuar.\n"
    
    read -p "Presiona Enter para continuar con la instalaciÃ³n..."
    ui_hr
    echo -e "${YELLOW}[+] Instalando sslh...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install sslh -y
    
    ui_hr
    echo -e "${GREEN}âœ“ SSLH INSTALADO CON Ã‰XITO${NC}"
    ui_pause
}

edit_sslh() {
    ui_header "CONFIGURAR E INICIAR SSLH"
    
    if ! dpkg -l | grep -q "sslh"; then
        echo -e "${RED}âŒ SSLH no estÃ¡ instalado. InstÃ¡lalo primero.${NC}"
        ui_pause
        return 1
    fi
    
    systemctl stop sslh >/dev/null 2>&1
    
    echo -e "${WHITE}Selecciona el puerto principal donde escucharÃ¡ SSLH (ej: 443)${NC}"
    while true; do
        read -p "Puerto Principal SSLH: " -e -i "443" SSLHPORT
        if ! mportas | grep -q -w "$SSLHPORT"; then
            break
        else
            echo -e "${RED}âŒ El puerto $SSLHPORT ya estÃ¡ ocupado por otro servicio.${NC}"
        fi
    done
    
    ui_hr
    PORTSSHF=""
    read -p "Â¿Deseas redirigir SSH? [s/n]: " -e -i s ssh_opt
    if [[ "$ssh_opt" == @(s|S|y|Y) ]]; then
        read -p "Puerto SSH local: " -e -i "22" SSHPORT
        PORTSSHF="--ssh 127.0.0.1:$SSHPORT"
    fi
    
    PORTSSLF=""
    read -p "Â¿Deseas redirigir SSL (Stunnel)? [s/n]: " -e -i s ssl_opt
    if [[ "$ssl_opt" == @(s|S|y|Y) ]]; then
        read -p "Puerto SSL local: " -e -i "442" SSLPORT
        PORTSSLF="--ssl 127.0.0.1:$SSLPORT"
    fi
    
    PORTOPENVPNF=""
    read -p "Â¿Deseas redirigir OpenVPN? [s/n]: " -e -i n ovpn_opt
    if [[ "$ovpn_opt" == @(s|S|y|Y) ]]; then
        read -p "Puerto OpenVPN local: " -e -i "1194" OPENVPNPORT
        PORTOPENVPNF="--openvpn 127.0.0.1:$OPENVPNPORT"
    fi
    
    AUTOMATICO=""
    read -p "Â¿Deseas redirigir otro protocolo (Automatico/HTTP)? [s/n]: " -e -i n any_opt
    if [[ "$any_opt" == @(s|S|y|Y) ]]; then
        read -p "Puerto local adicional: " -e -i "80" AUTOMATICOPORT
        AUTOMATICO="--anyprot 127.0.0.1:$AUTOMATICOPORT"
    fi
    
    ui_hr
    echo -e "${YELLOW}[+] Escribiendo configuraciÃ³n de SSLH...${NC}"
    
    cat <<EOF >/etc/default/sslh
DAEMON=/usr/sbin/sslh
Run=yes
DAEMON_OPTS="--user sslh --listen 0.0.0.0:${SSLHPORT} ${PORTSSHF} ${PORTSSLF} ${PORTOPENVPNF} ${AUTOMATICO} --pidfile /var/run/sslh/sslh.pid"
EOF

    chmod +x /etc/default/sslh
    ufw allow ${SSLHPORT}/tcp >/dev/null 2>&1
    
    systemctl enable sslh >/dev/null 2>&1
    systemctl restart sslh >/dev/null 2>&1
    
    ui_hr
    if systemctl is-active --quiet sslh 2>/dev/null; then
        echo -e "${GREEN}âœ“ SSLH INICIADO CON Ã‰XITO EN EL PUERTO $SSLHPORT${NC}"
    else
        echo -e "${RED}âŒ FallÃ³ al arrancar SSLH. Verifica la configuraciÃ³n o puerto ocupado.${NC}"
    fi
    ui_pause
}

while true; do
    dpkg -l | grep -q "sslh" && st="${GREEN}[ INSTALADO ]${NC}" || st="${RED}[ NO INSTALADO ]${NC}"
    ui_header "SSLH MULTIPLEXER"
    echo -e " Estado: $st"
    ui_hr
    echo -e "  ${CYAN}[1]>${WHITE} INSTALAR / DESINSTALAR SSLH MULTIPLEXER${NC}"
    echo -e "  ${CYAN}[2]>${WHITE} CONFIGURAR E INICIAR REDIRECCIONES SSLH${NC}"
    ui_hr
    echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
    ui_hr
    ui_prompt "Selecciona una opciÃ³n: "
    read -r opcao
    
    case $opcao in
        1) sslh_inicial ;;
        2) edit_sslh ;;
        0) break ;;
        *) continue ;;
    esac
done
