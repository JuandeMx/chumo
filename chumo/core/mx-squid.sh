#!/bin/bash
# ChumoGH - Squid Proxy Manager
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

# Obtener puertos en uso
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

# Obtener IP del VPS
fun_ip() {
    MEU_IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
    MEU_IP2=$(wget -qO- ipv4.icanhazip.com)
    [[ "$MEU_IP" != "$MEU_IP2" ]] && IP="$MEU_IP2" || IP="$MEU_IP"
}

# Optimizador de red SSH via ethtool
fun_eth() {
    # Detectar interfaz
    eth=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    if [[ -n "$eth" ]]; then
        echo -e "${YELLOW}Â¿Deseas optimizar la interfaz de red con ethtool?${NC}"
        echo -e "Esta opciÃ³n mejora el flujo de paquetes para conexiones SSH lentas."
        read -p "[s/n]: " -e -i n sshsn
        if [[ "$sshsn" = @(s|S|y|Y) ]]; then
            read -p "Cual es la tasa RX (por defecto 999999999): " rx
            [[ -z "$rx" ]] && rx="999999999"
            read -p "Cual es la tasa TX (por defecto 999999999): " tx
            [[ -z "$tx" ]] && tx="999999999"
            
            echo -e "${YELLOW}[+] Aplicando correcciÃ³n de ethtool a $eth...${NC}"
            DEBIAN_FRONTEND=noninteractive apt-get install ethtool -y >/dev/null 2>&1
            ethtool -G "$eth" rx "$rx" tx "$tx" >/dev/null 2>&1
            echo -e "${GREEN}âœ“ OptimizaciÃ³n de ethtool aplicada.${NC}"
        fi
    fi
}

# Obtiene la ruta del archivo squid.conf
get_squid_conf() {
    if [[ -d /etc/squid ]]; then
        echo "/etc/squid/squid.conf"
    elif [[ -d /etc/squid3 ]]; then
        echo "/etc/squid3/squid.conf"
    else
        echo ""
    fi
}

instalar_squid() {
    ui_header "INSTALACIÃ“N DE SQUID PROXY"
    fun_ip
    
    read -p "Confirme la IP de su VPS: " -e -i "$IP" ip
    
    echo -e "\n${WHITE}Puedes activar varios puertos de forma secuencial (separados por espacio)${NC}"
    echo -e "Ejemplo: ${GREEN}80 8080 8799 3128${NC}\n"
    
    read -p "Digite los Puertos: " -e -i "8080 3128" portasx
    
    totalporta=($portasx)
    PORT=""
    for ((i = 0; i < ${#totalporta[@]}; i++)); do
        if [[ -z "$(mportas | grep -w "${totalporta[$i]}")" ]]; then
            echo -e "${YELLOW}â–¶ Puerto Elegido: ${GREEN}${totalporta[$i]} OK${NC}"
            PORT+="${totalporta[$i]}\n"
        else
            echo -e "${YELLOW}â–¶ Puerto Elegido: ${RED}${totalporta[$i]} FAIL (En Uso)${NC}"
        fi
    done
    
    if [[ -z "$PORT" ]]; then
        echo -e "${RED}âŒ NingÃºn puerto vÃ¡lido fue elegido.${NC}"
        ui_pause
        return 1
    fi
    
    ui_hr
    echo -e "${YELLOW}[+] Instalando Squid Proxy...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install squid unzip -y >/dev/null 2>&1
    
    # Asegurar directorios
    mkdir -p /etc/squid
    
    # Escribir payloads por defecto
    echo -e ".bookclaro.com.br/\n.claro.com.ar/\n.claro.com.br/\n.claro.com.co/\n.claro.com.ec/\n.claro.com.gt/\n.cloudfront.net/\n.claro.com.ni/\n.claro.com.pe/\n.claro.com.sv/\n.claro.cr/\n.clarocurtas.com.br/\n.claroideas.com/\n.claroideias.com.br/\n.claromusica.com/\n.clarosomdechamada.com.br/\n.clarovideo.com/\n.facebook.net/\n.facebook.com/\n.netclaro.com.br/\n.oi.com.br/\n.oimusica.com.br/\n.speedtest.net/\n.tim.com.br/\n.timanamaria.com.br/\n.vivo.com.br/\n.rdio.com/\n.compute-1.amazonaws.com/\n.portalrecarga.vivo.com.br/\n.vivo.ddivulga.com/" > /etc/payloads
    
    ui_hr
    echo -e "${WHITE}Elija la configuraciÃ³n para su Squid Proxy:${NC}"
    echo -e "  [1] Basico (Filtrado estÃ¡ndar por IP destino del VPS)"
    echo -e "  [2] Avanzado (Headers Forcing para payloads directos)"
    read -p "OpciÃ³n [1/2]: " -e -i "1" proxy_opt
    
    var_squid=$(get_squid_conf)
    if [[ -z "$var_squid" ]]; then
        var_squid="/etc/squid/squid.conf"
    fi
    
    if [[ "$proxy_opt" == "2" ]]; then
        echo -e "${YELLOW}[+] Escribiendo Squid Avanzado...${NC}"
        cat <<EOF >"$var_squid"
# Squid Avanzado
acl url1 dstdomain -i $ip
acl url2 dstdomain -i 127.0.0.1
acl url3 url_regex -i '/etc/payloads'
acl url4 url_regex -i '/etc/opendns'
acl url5 dstdomain -i localhost
acl accept dstdomain -i GET
acl accept dstdomain -i POST
acl accept dstdomain -i OPTIONS
acl accept dstdomain -i CONNECT
acl accept dstdomain -i PUT
acl HEAD dstdomain -i HEAD
acl accept dstdomain -i TRACE
acl accept dstdomain -i OPTIONS
acl accept dstdomain -i PATCH
acl accept dstdomain -i PROPATCH
acl accept dstdomain -i DELETE
acl accept dstdomain -i REQUEST
acl accept dstdomain -i METHOD
acl accept dstdomain -i NETDATA
acl accept dstdomain -i MOVE
acl all src 0.0.0.0/0
http_access allow url1
http_access allow url2
http_access allow url3
http_access allow url4
http_access allow url5
http_access allow accept
http_access allow HEAD
http_access deny all

# Request Headers Forcing
request_header_access Allow allow all
request_header_access Authorization allow all
request_header_access WWW-Authenticate allow all
request_header_access Proxy-Authorization allow all
request_header_access Proxy-Authenticate allow all
request_header_access Cache-Control allow all
request_header_access Content-Encoding allow all
request_header_access Content-Length allow all
request_header_access Content-Type allow all
request_header_access Date allow all
request_header_access Expires allow all
request_header_access Host allow all
request_header_access If-Modified-Since allow all
request_header_access Last-Modified allow all
request_header_access Location allow all
request_header_access Pragma allow all
request_header_access Accept allow all
request_header_access Accept-Charset allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Content-Language allow all
request_header_access Mime-Version allow all
request_header_access Retry-After allow all
request_header_access Title allow all
request_header_access Connection allow all
request_header_access Proxy-Connection allow all
request_header_access User-Agent allow all
request_header_access Cookie allow all
EOF
    else
        echo -e "${YELLOW}[+] Escribiendo Squid BÃ¡sico...${NC}"
        cat <<EOF >"$var_squid"
# Squid Basico
acl localhost src 127.0.0.1/32 ::1
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32 ::1
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT
acl SSH dst $ip-$ip/255.255.255.255
http_access allow SSH
http_access allow manager localhost
http_access deny manager
http_access allow localhost
http_access deny all
coredump_dir /var/spool/squid
EOF
    fi

    # Escribir puertos en config
    for pts in $(echo -e "$PORT"); do
        echo "http_port $pts" >> "$var_squid"
        ufw allow $pts/tcp >/dev/null 2>&1
    done
    
    echo -e "
visible_hostname SCRIPT-LATAM
via off
forwarded_for off
pipeline_prefetch off" >> "$var_squid"

    touch /etc/opendns
    fun_eth
    
    ui_hr
    echo -e "${YELLOW}[+] Reiniciando servicios de red y Squid...${NC}"
    systemctl restart squid >/dev/null 2>&1
    systemctl restart squid3 >/dev/null 2>&1
    service ssh restart >/dev/null 2>&1
    
    echo -e "${GREEN}âœ“ SQUID CONFIGURADO CON Ã‰XITO${NC}"
    ui_pause
}

desinstalar_squid() {
    ui_header "DESINSTALAR SQUID PROXY"
    echo -e "${YELLOW}[+] Deteniendo Squid...${NC}"
    systemctl stop squid >/dev/null 2>&1
    systemctl stop squid3 >/dev/null 2>&1
    
    echo -e "${YELLOW}[+] Eliminando paquetes de Squid...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get remove --purge squid squid3 -y >/dev/null 2>&1
    rm -rf /etc/squid 2>/dev/null
    rm -rf /etc/squid3 2>/dev/null
    rm -f /etc/payloads 2>/dev/null
    
    ui_hr
    echo -e "${GREEN}âœ“ SQUID DESINSTALADO CON Ã‰XITO${NC}"
    ui_pause
}

colocar_host() {
    ui_header "COLOCAR HOST EN SQUID"
    payload="/etc/payloads"
    if [[ ! -f "$payload" ]]; then
        touch "$payload"
    fi
    
    echo -e "${WHITE}Hosts actuales dentro de Squid:${NC}"
    ui_subhr
    cat "$payload" | awk -F "/" '{print $1,$2,$3}'
    ui_subhr
    
    while true; do
        read -p "Escriba el nuevo host (debe empezar con punto, ej: .google.com): " hos
        if [[ "$hos" == .* ]]; then
            break
        else
            echo -e "${RED}âŒ El host debe iniciar con punto (.).${NC}"
        fi
    done
    
    host="$hos/"
    if grep -q "^$host" "$payload"; then
        echo -e "${RED}âŒ El host ya existe en Squid.${NC}"
    else
        echo "$host" >> "$payload"
        # Limpiar vacios
        grep -v "^$" "$payload" > /tmp/payload_tmp && mv /tmp/payload_tmp "$payload"
        echo -e "${GREEN}âœ“ Host agregado con Ã©xito.${NC}"
        
        # Reiniciar Squid
        systemctl reload squid >/dev/null 2>&1
        systemctl restart squid >/dev/null 2>&1
    fi
    ui_pause
}

remover_host() {
    ui_header "REMOVER HOST DE SQUID"
    payload="/etc/payloads"
    if [[ ! -f "$payload" ]]; then
        echo -e "${RED}âŒ Archivo de payloads no existe.${NC}"
        ui_pause
        return 1
    fi
    
    echo -e "${WHITE}Hosts actuales dentro de Squid:${NC}"
    ui_subhr
    cat "$payload" | awk -F "/" '{print $1,$2,$3}'
    ui_subhr
    
    read -p "Digite el host a remover (ej: .google.com): " hos
    host="$hos/"
    
    if grep -q "^$host" "$payload"; then
        grep -v "^$host" "$payload" > /tmp/payload_tmp && mv /tmp/payload_tmp "$payload"
        echo -e "${GREEN}âœ“ Host removido con Ã©xito.${NC}"
        systemctl reload squid >/dev/null 2>&1
        systemctl restart squid >/dev/null 2>&1
    else
        echo -e "${RED}âŒ Host no encontrado.${NC}"
    fi
    ui_pause
}

extra_squid() {
    while true; do
        ui_header "CONFIGURACIONES EXTRA PARA SQUID"
        echo -e "  ${CYAN}[1]>${WHITE} COLOCAR HOST EN SQUID${NC}"
        echo -e "  ${CYAN}[2]>${WHITE} REMOVER HOST DE SQUID${NC}"
        echo -e "  ${CYAN}[3]>${RED} DESINSTALAR SQUID PROXY${NC}"
        ui_hr
        echo -e "  ${WHITE}[0] VOLVER AL MENÃš DE INICIO${NC}"
        ui_hr
        ui_prompt "Selecciona una opciÃ³n: "
        read -r varpay
        
        case $varpay in
            1) colocar_host ;;
            2) remover_host ;;
            3) desinstalar_squid; break ;;
            0) break ;;
            *) continue ;;
        esac
    done
}

# Cargar flujo inicial
conf_dir=$(get_squid_conf)
if [[ -n "$conf_dir" && -f "$conf_dir" ]]; then
    extra_squid
else
    instalar_squid
fi
