#!/bin/bash
# ChumoGH - OpenVPN Manager
# Adapta la lÃ³gica de Chumo LATAM a la estÃ©tica de Maximus

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

OVPN_DIR="/etc/openvpn/server"
EASYRSA_DIR="/etc/openvpn/easy-rsa"
PKI_DIR="${EASYRSA_DIR}/pki"
CLIENTS_DIR="/root/openvpn-clients"

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

# Obtiene la IP del VPS
get_public_ip() {
    local ip
    ip=$(wget -qO- ipv4.icanhazip.com 2>/dev/null)
    [ -z "$ip" ] && ip=$(curl -fsSL https://api.ipify.org 2>/dev/null)
    [ -z "$ip" ] && ip="127.0.0.1"
    echo "$ip"
}

detect_iface() {
    local iface
    iface=$(ip -4 route ls 2>/dev/null | awk '/default/ {print $5; exit}')
    [ -z "$iface" ] && iface="eth0"
    echo "$iface"
}

read_current_server_settings() {
    OVPN_PORT=""
    OVPN_PROTO=""
    if [ -f "${OVPN_DIR}/server.conf" ]; then
        OVPN_PORT=$(grep -E '^port ' "${OVPN_DIR}/server.conf" 2>/dev/null | awk '{print $2}' | head -1)
        OVPN_PROTO=$(grep -E '^proto ' "${OVPN_DIR}/server.conf" 2>/dev/null | awk '{print $2}' | head -1)
    fi
    [ -z "$OVPN_PORT" ] && OVPN_PORT="1194"
    [ -z "$OVPN_PROTO" ] && OVPN_PROTO="udp"
}

# Habilitar forwarding en sysctl
enable_forwarding() {
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf 2>/dev/null
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
}

write_iptables_rules() {
    local iface="$1"
    local proto="$2"
    local port="$3"

    mkdir -p /etc/iptables 2>/dev/null
    iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o "$iface" -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$iface" -j MASQUERADE
    iptables -C INPUT -p "$proto" --dport "$port" -j ACCEPT 2>/dev/null || iptables -A INPUT -p "$proto" --dport "$port" -j ACCEPT
    iptables -C FORWARD -s 10.8.0.0/24 -j ACCEPT 2>/dev/null || iptables -A FORWARD -s 10.8.0.0/24 -j ACCEPT
    iptables -C FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

    if command -v iptables-save >/dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    fi
}

install_openvpn() {
    ui_header "INSTALAR OPENVPN (SERVIDOR + CLIENTE)"
    
    read -p "Protocolo (udp/tcp) [Default: udp]: " proto
    [ -z "$proto" ] && proto="udp"
    if [ "$proto" != "udp" ] && [ "$proto" != "tcp" ]; then
        echo -e "${RED}âŒ Protocolo invÃ¡lido.${NC}"; sleep 2; return 1
    fi
    
    read -p "Puerto [Default: 1194]: " port
    [ -z "$port" ] && port="1194"

    ui_hr
    echo -e "${YELLOW}[+] Instalando dependencias de OpenVPN...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -y openvpn easy-rsa iptables >/dev/null 2>&1
    
    mkdir -p "$OVPN_DIR" "$EASYRSA_DIR" "$CLIENTS_DIR" 2>/dev/null
    enable_forwarding
    
    echo -e "${YELLOW}[+] Preparando PKI y Easy-RSA...${NC}"
    rm -rf "$EASYRSA_DIR" 2>/dev/null
    mkdir -p "$EASYRSA_DIR" 2>/dev/null
    cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR/" 2>/dev/null || true
    chmod 700 "$EASYRSA_DIR" 2>/dev/null
    
    cd "$EASYRSA_DIR" || return 1
    cat > "${EASYRSA_DIR}/vars" <<'EOF'
set_var EASYRSA_ALGO ec
set_var EASYRSA_CURVE prime256v1
set_var EASYRSA_REQ_COUNTRY    "MX"
set_var EASYRSA_REQ_PROVINCE   "CDMX"
set_var EASYRSA_REQ_CITY       "Maximus"
set_var EASYRSA_REQ_ORG        "ChumoGH"
set_var EASYRSA_REQ_EMAIL      "admin@maximus.com"
set_var EASYRSA_REQ_OU         "Maximus"
EOF

    ./easyrsa --batch init-pki >/dev/null 2>&1
    ./easyrsa --batch build-ca nopass >/dev/null 2>&1
    ./easyrsa --batch gen-req server nopass >/dev/null 2>&1
    ./easyrsa --batch sign-req server server >/dev/null 2>&1
    ./easyrsa --batch gen-dh >/dev/null 2>&1
    
    openvpn --genkey --secret "${EASYRSA_DIR}/ta.key" >/dev/null 2>&1
    
    # Buscar el plugin PAM de OpenVPN de forma robusta
    PLUGIN=""
    for path in \
        "/usr/lib/openvpn/openvpn-plugin-auth-pam.so" \
        "/usr/lib/openvpn/plugins/openvpn-plugin-auth-pam.so" \
        "/usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so" \
        "/usr/lib/aarch64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so" \
        "/usr/lib/i386-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so" \
        "/usr/lib/arm-linux-gnueabihf/openvpn/plugins/openvpn-plugin-auth-pam.so" \
        "/usr/lib/openvpn/openvpn-auth-pam.so"; do
        if [ -f "$path" ]; then
            PLUGIN="$path"
            break
        fi
    done
    if [ -z "$PLUGIN" ]; then
        if command -v locate >/dev/null 2>&1; then
            if command -v updatedb >/dev/null 2>&1; then
                updatedb >/dev/null 2>&1
            fi
            PLUGIN=$(locate openvpn-plugin-auth-pam.so 2>/dev/null | head -n 1)
        fi
    fi
    if [ -z "$PLUGIN" ]; then
        PLUGIN=$(find /usr/ -name "openvpn-plugin-auth-pam.so" 2>/dev/null | head -n 1)
    fi

    # Verificar versiÃ³n de OpenVPN para compatibilidad con la directiva de certificado
    local ovpn_ver
    ovpn_ver=$(openvpn --version 2>/dev/null | head -n 1 | awk '{print $2}')
    local cert_opt="client-cert-not-required"
    if [[ "$ovpn_ver" =~ ^2\.[5-9] || "$ovpn_ver" =~ ^[3-9]\. ]]; then
        cert_opt="verify-client-cert none"
    fi

    # ConfiguraciÃ³n base de OpenVPN
    local run_as_root=""
    if [[ -n "$PLUGIN" ]]; then
        run_as_root="# "
    fi

    # Escribir server.conf
    cat > "${OVPN_DIR}/server.conf" <<EOF
port ${port}
proto ${proto}
dev tun
${run_as_root}user nobody
${run_as_root}group nogroup
persist-key
persist-tun
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
ca ${PKI_DIR}/ca.crt
cert ${PKI_DIR}/issued/server.crt
key ${PKI_DIR}/private/server.key
dh ${PKI_DIR}/dh.pem
tls-auth ${EASYRSA_DIR}/ta.key 0
key-direction 0
auth SHA256
cipher AES-256-GCM
ncp-ciphers AES-256-GCM:AES-128-GCM
tls-version-min 1.2
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
explicit-exit-notify 1
verb 3
status /var/log/openvpn/openvpn-status.log
log-append /var/log/ChumoGH/openvpn.log
EOF

    mkdir -p /var/log/openvpn 2>/dev/null
    
    # Integrar plugin PAM si existe para permitir usuarios de sistema SSH
    if [[ -n "$PLUGIN" ]]; then
        cat <<EOF >> "${OVPN_DIR}/server.conf"
client-to-client
$cert_opt
username-as-common-name
plugin $PLUGIN login
EOF
    fi

    # Configurar Firewall e Iptables
    ufw allow "${port}/${proto}" >/dev/null 2>&1
    write_iptables_rules "$(detect_iface)" "$proto" "$port"
    
    # Arrancar servicio
    systemctl daemon-reload
    systemctl enable --now openvpn-server@server >/dev/null 2>&1
    systemctl restart openvpn-server@server >/dev/null 2>&1
    
    # Generar primer perfil de cliente
    if systemctl is-active --quiet openvpn-server@server; then
        echo -e "${GREEN}âœ“ OPENVPN INSTALADO CORRECTAMENTE.${NC}"
        read -p "Escribe el nombre para tu primer perfil (.ovpn) [Default: mx]: " c1
        [ -z "$c1" ] && c1="mx"
        create_client "$c1"
    else
        echo -e "${RED}âŒ OpenVPN no arrancÃ³. Revisa logs con journalctl -u openvpn-server@server${NC}"
    fi
    ui_pause
}

create_client() {
    local client="$1"
    if [[ -z "$client" ]]; then
        read -p "Nombre del nuevo cliente (.ovpn): " client
    fi
    [ -z "$client" ] && return 1
    
    if [[ ! -d "$PKI_DIR" ]]; then
        echo -e "${RED}âŒ OpenVPN no estÃ¡ instalado.${NC}"
        ui_pause
        return 1
    fi
    
    ui_header "CREAR CLIENTE OPENVPN"
    echo -e "${YELLOW}[+] Generando llaves para cliente $client...${NC}"
    
    cd "$EASYRSA_DIR" || return 1
    ./easyrsa --batch gen-req "$client" nopass >/dev/null 2>&1
    ./easyrsa --batch sign-req client "$client" >/dev/null 2>&1
    
    local server_ip
    server_ip=$(get_public_ip)
    read_current_server_settings
    
    local client_conf="${CLIENTS_DIR}/${client}.ovpn"
    cat > "$client_conf" <<EOF
client
dev tun
proto ${OVPN_PROTO}
remote ${server_ip} ${OVPN_PORT}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth-user-pass
auth SHA256
cipher AES-256-GCM
verb 3
key-direction 1

<ca>
$(cat "${PKI_DIR}/ca.crt")
</ca>
<cert>
$(cat "${PKI_DIR}/issued/${client}.crt")
</cert>
<key>
$(cat "${PKI_DIR}/private/${client}.key")
</key>
<tls-auth>
$(cat "${EASYRSA_DIR}/ta.key")
</tls-auth>
EOF

    chmod 600 "$client_conf" 2>/dev/null
    echo -e "${GREEN}âœ“ Perfil creado con Ã©xito: ${WHITE}${client_conf}${NC}"
    ui_pause
}

revoke_client() {
    ui_header "REVOCAR CLIENTE OPENVPN"
    
    if [[ ! -d "$PKI_DIR" ]]; then
        echo -e "${RED}âŒ OpenVPN no estÃ¡ instalado.${NC}"
        ui_pause
        return 1
    fi
    
    read -p "Escribe el nombre del cliente a revocar: " client
    if [[ -z "$client" ]]; then
        echo -e "${RED}âŒ Cancelado.${NC}"
        ui_pause
        return 1
    fi
    
    cd "$EASYRSA_DIR" || return 1
    if ./easyrsa --batch revoke "$client" >/dev/null 2>&1; then
        ./easyrsa --batch gen-crl >/dev/null 2>&1
        rm -f "${CLIENTS_DIR}/${client}.ovpn" 2>/dev/null
        echo -e "${GREEN}âœ“ Cliente $client revocado y archivo .ovpn eliminado.${NC}"
    else
        echo -e "${RED}âŒ Error al revocar cliente. AsegÃºrese de que existe.${NC}"
    fi
    ui_pause
}

edit_ovpn_host() {
    ui_header "CONFIGURACIÃ“N HOST/DNS OPENVPN"
    echo -e "${WHITE}Este menÃº permite agregar hosts al archivo /etc/hosts.${NC}"
    ui_hr
    
    read -p "Ingresa el Host DNS a agregar (ej: claro.com.ni): " SDNS
    if [[ -n "$SDNS" ]]; then
        cat /etc/hosts | grep -v "$SDNS" >/etc/hosts.bak && mv -f /etc/hosts.bak /etc/hosts
        echo "127.0.0.1 $SDNS" >> /etc/hosts
        echo -e "${GREEN}âœ“ Host agregado a /etc/hosts.${NC}"
    fi
    ui_pause
}

toggle_openvpn() {
    ui_header "INICIAR / DETENER OPENVPN"
    if systemctl is-active --quiet openvpn-server@server; then
        echo -e "${YELLOW}[+] Deteniendo el servicio OpenVPN...${NC}"
        systemctl stop openvpn-server@server >/dev/null 2>&1
        echo -e "${RED}âœ“ OpenVPN Detenido.${NC}"
    else
        echo -e "${YELLOW}[+] Iniciando el servicio OpenVPN...${NC}"
        systemctl start openvpn-server@server >/dev/null 2>&1
        echo -e "${GREEN}âœ“ OpenVPN Iniciado.${NC}"
    fi
    ui_pause
}

uninstall_openvpn() {
    ui_header "DESINSTALAR OPENVPN"
    read_current_server_settings
    
    read -p "Â¿EstÃ¡s seguro que deseas eliminar OpenVPN por completo? [s/n]: " conf
    if [[ "$conf" == "s" || "$conf" == "S" ]]; then
        echo -e "${YELLOW}[+] Deteniendo servicios...${NC}"
        systemctl disable --now openvpn-server@server >/dev/null 2>&1 || true
        
        echo -e "${YELLOW}[+] Removiendo reglas de firewall...${NC}"
        ufw delete allow "${OVPN_PORT}/${OVPN_PROTO}" >/dev/null 2>&1 || true
        
        echo -e "${YELLOW}[+] Desinstalando paquetes...${NC}"
        DEBIAN_FRONTEND=noninteractive apt-get purge -y openvpn easy-rsa >/dev/null 2>&1 || true
        apt-get autoremove -y >/dev/null 2>&1 || true
        
        rm -rf /etc/openvpn 2>/dev/null
        rm -rf "$CLIENTS_DIR" 2>/dev/null
        systemctl daemon-reload >/dev/null 2>&1
        echo -e "${GREEN}âœ“ OpenVPN eliminado completamente de su VPS.${NC}"
    fi
    ui_pause
}

while true; do
    read_current_server_settings
    if systemctl is-active --quiet openvpn-server@server 2>/dev/null; then
        st="${GREEN}[ ACTIVO ]${NC}"
    else
        st="${RED}[ OFF ]${NC}"
    fi
    
    ui_header "OPENVPN MANAGER"
    echo -e " Estado: $st    Puerto actual: ${WHITE}${OVPN_PORT}/${OVPN_PROTO}${NC}"
    ui_hr
    if [ ! -f "${OVPN_DIR}/server.conf" ]; then
        echo -e "  ${CYAN}[1]>${WHITE} INSTALAR OPENVPN${NC}"
    else
        echo -e "  ${CYAN}[1]>${RED} DESINSTALAR OPENVPN${NC}"
        echo -e "  ${CYAN}[2]>${WHITE} CREAR NUEVO CLIENTE (.ovpn)${NC}"
        echo -e "  ${CYAN}[3]>${WHITE} REVOCAR CLIENTE (.ovpn)${NC}"
        echo -e "  ${CYAN}[4]>${WHITE} EDITAR CONF CLIENTE (NANO)${NC}"
        echo -e "  ${CYAN}[5]>${WHITE} EDITAR CONF SERVIDOR (NANO)${NC}"
        echo -e "  ${CYAN}[6]>${WHITE} AGREGAR HOST A /ETC/HOSTS${NC}"
        echo -e "  ${CYAN}[7]>${WHITE} INICIAR / APAGAR SERVICIO OPENVPN${NC}"
    fi
    ui_hr
    echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
    ui_hr
    ui_prompt "Selecciona una opciÃ³n: "
    read -r opcao
    
    case $opcao in
        1) 
            if [ -f "${OVPN_DIR}/server.conf" ]; then
                uninstall_openvpn
            else
                install_openvpn
            fi
            ;;
        2) create_client ;;
        3) revoke_client ;;
        4) [ -f /etc/openvpn/server/client-common.txt ] && nano /etc/openvpn/server/client-common.txt || nano /etc/openvpn/client-common.txt ;;
        5) nano /etc/openvpn/server/server.conf ;;
        6) edit_ovpn_host ;;
        7) toggle_openvpn ;;
        0) break ;;
        *) continue ;;
    esac
done
