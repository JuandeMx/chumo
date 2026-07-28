#!/bin/bash
# ChumoGH - Instalador OpenVPN (Server + Clientes)
# Perfil: clÃ¡sico, estable y compatible (UDP/TCP)

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

OVPN_DIR="/etc/openvpn/server"
EASYRSA_DIR="/etc/openvpn/easy-rsa"
PKI_DIR="${EASYRSA_DIR}/pki"
CLIENTS_DIR="/root/openvpn-clients"

ensure_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}âŒ Solo root puede ejecutar este instalador.${NC}"
    exit 1
  fi
}

get_public_ip() {
  local ip
  ip=$(wget -qO- ipv4.icanhazip.com 2>/dev/null)
  [ -z "$ip" ] && ip=$(curl -fsSL https://api.ipify.org 2>/dev/null)
  [ -z "$ip" ] && ip="TU_IP"
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

enable_forwarding() {
  echo -ne "${GREEN}[+] Habilitando IPv4 Forwarding...${NC}"
  sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
  sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf 2>/dev/null
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  echo -e " ${GREEN}[OK]${NC}"
}

write_iptables_rules() {
  local iface="$1"
  local proto="$2"
  local port="$3"

  mkdir -p /etc/iptables 2>/dev/null

  # Reglas mÃ­nimas para NAT de la red VPN
  iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o "$iface" -j MASQUERADE 2>/dev/null \
    || iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$iface" -j MASQUERADE

  # Aceptar trÃ¡fico VPN
  iptables -C INPUT -p "$proto" --dport "$port" -j ACCEPT 2>/dev/null \
    || iptables -A INPUT -p "$proto" --dport "$port" -j ACCEPT
  iptables -C FORWARD -s 10.8.0.0/24 -j ACCEPT 2>/dev/null \
    || iptables -A FORWARD -s 10.8.0.0/24 -j ACCEPT
  iptables -C FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null \
    || iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

  if command -v iptables-save >/dev/null 2>&1; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null
  fi
  if command -v ip6tables-save >/dev/null 2>&1; then
    ip6tables-save > /etc/iptables/rules.v6 2>/dev/null
  fi
}

install_deps() {
  echo -e "${GREEN}[+] Instalando dependencias (openvpn + easy-rsa)...${NC}"
  apt-get update -y >/dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get install -y openvpn easy-rsa iptables >/dev/null 2>&1

  # Persistencia de iptables si estÃ¡ disponible
  if ! dpkg -l iptables-persistent 2>/dev/null | grep -q "^ii"; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent >/dev/null 2>&1 || true
  fi

  mkdir -p /var/log/ChumoGH 2>/dev/null
  mkdir -p "$OVPN_DIR" "$EASYRSA_DIR" "$CLIENTS_DIR" 2>/dev/null
}

init_pki() {
  echo -e "${GREEN}[+] Preparando PKI (Easy-RSA)...${NC}"
  rm -rf "$EASYRSA_DIR" 2>/dev/null
  mkdir -p "$EASYRSA_DIR" 2>/dev/null
  cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR/" 2>/dev/null || true
  chmod 700 "$EASYRSA_DIR" 2>/dev/null

  cd "$EASYRSA_DIR" || exit 1

  cat > "${EASYRSA_DIR}/vars" <<'EOFVARS'
set_var EASYRSA_ALGO ec
set_var EASYRSA_CURVE prime256v1
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "CA"
set_var EASYRSA_REQ_CITY       "MX"
set_var EASYRSA_REQ_ORG        "ChumoGH"
set_var EASYRSA_REQ_EMAIL      "admin@example.com"
set_var EASYRSA_REQ_OU         "Maximus"
EOFVARS

  ./easyrsa --batch init-pki >/dev/null 2>&1
  ./easyrsa --batch build-ca nopass >/dev/null 2>&1
  ./easyrsa --batch gen-req server nopass >/dev/null 2>&1
  ./easyrsa --batch sign-req server server >/dev/null 2>&1
  ./easyrsa --batch gen-dh >/dev/null 2>&1

  openvpn --genkey --secret "${EASYRSA_DIR}/ta.key" >/dev/null 2>&1
}

write_server_conf() {
  local proto="$1"
  local port="$2"

  mkdir -p "$OVPN_DIR" 2>/dev/null

  # Buscar el plugin PAM de OpenVPN de forma robusta
  local PLUGIN=""
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

  # ConfiguraciÃ³n base de OpenVPN (comentar user/group si usa PAM)
  local run_as_root=""
  if [[ -n "$PLUGIN" ]]; then
    run_as_root="# "
  fi

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

  if [[ -n "$PLUGIN" ]]; then
    cat <<EOF >> "${OVPN_DIR}/server.conf"
client-to-client
$cert_opt
username-as-common-name
plugin $PLUGIN login
EOF
  fi

  mkdir -p /var/log/openvpn 2>/dev/null
}

restart_openvpn() {
  systemctl daemon-reload 2>/dev/null
  systemctl enable --now openvpn-server@server >/dev/null 2>&1
  systemctl restart openvpn-server@server >/dev/null 2>&1
}

open_firewall() {
  local proto="$1"
  local port="$2"
  ufw allow "${port}/${proto}" >/dev/null 2>&1 || true
}

create_client() {
  local client="$1"
  [ -z "$client" ] && return 1

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
  echo -e "${GREEN}âœ… Cliente creado: ${WHITE}${client_conf}${NC}"
  
  # Generar enlace de descarga
  local port_fs=8081
  echo -e "${YELLOW}ðŸ“‹ ENLACE DE DESCARGA:${NC}"
  echo -e "${WHITE}http://${server_ip}:${port_fs}/${client}.ovpn${NC}"
  echo -e "${CYAN}---------------------------------------------------------${NC}"
}

revoke_client() {
  local client="$1"
  [ -z "$client" ] && return 1
  cd "$EASYRSA_DIR" || return 1
  ./easyrsa --batch revoke "$client" >/dev/null 2>&1 || true
  ./easyrsa --batch gen-crl >/dev/null 2>&1 || true
  rm -f "${CLIENTS_DIR}/${client}.ovpn" 2>/dev/null
  echo -e "${YELLOW}âš ï¸ Cliente revocado y archivo .ovpn eliminado: ${client}${NC}"
}

list_clients() {
  if [ ! -f "${PKI_DIR}/index.txt" ]; then
    echo -e "${RED}âŒ No hay PKI. Primero instala OpenVPN.${NC}"
    return 1
  fi

  echo -e "${CYAN}=========================================================${NC}"
  echo -e "${YELLOW}                 CLIENTES OPENVPN (PKI)${NC}"
  echo -e "${CYAN}=========================================================${NC}"
  echo -e "${WHITE} Estado | Cliente | ExpiraciÃ³n${NC}"
  echo -e "${CYAN}---------------------------------------------------------${NC}"

  # Formato index.txt: V\t<exp>\t<rev>\t<serial>\t<file>\t/CN=client
  awk -F'\t' '
    $1 ~ /^[VR]/ {
      st=$1;
      exp=$2;
      cn=$6;
      gsub(/^\/CN=/,"",cn);
      if (cn=="") next;
      printf "  %s     | %s | %s\n", st, cn, exp;
    }
  ' "${PKI_DIR}/index.txt" 2>/dev/null | sed 's/^  V/  âœ…/; s/^  R/  âŒ/'

  echo -e "${CYAN}---------------------------------------------------------${NC}"
  echo -e "${WHITE} Archivos .ovpn en: ${YELLOW}${CLIENTS_DIR}${NC}"
  echo -e "${CYAN}=========================================================${NC}"
}

uninstall_openvpn() {
  read_current_server_settings

  echo -e "${RED}[+] Deteniendo OpenVPN...${NC}"
  systemctl disable --now openvpn-server@server >/dev/null 2>&1 || true

  echo -e "${RED}[+] Cerrando puerto en UFW...${NC}"
  ufw delete allow "${OVPN_PORT}/${OVPN_PROTO}" >/dev/null 2>&1 || true

  echo -e "${RED}[+] Eliminando paquetes y archivos...${NC}"
  DEBIAN_FRONTEND=noninteractive apt-get purge -y openvpn easy-rsa >/dev/null 2>&1 || true
  apt-get autoremove -y >/dev/null 2>&1 || true

  rm -rf /etc/openvpn 2>/dev/null
  rm -rf "$CLIENTS_DIR" 2>/dev/null
  rm -f /etc/systemd/system/openvpn-server@server.service.d/override.conf 2>/dev/null
  systemctl daemon-reload >/dev/null 2>&1 || true

  echo -e "${GREEN}âœ… OpenVPN eliminado completamente.${NC}"
}

usage() {
  echo "Uso:"
  echo "  install_openvpn.sh                # menÃº interactivo"
  echo "  install_openvpn.sh --list-clients"
  echo "  install_openvpn.sh --add-client <nombre>"
  echo "  install_openvpn.sh --revoke-client <nombre>"
  echo "  install_openvpn.sh --status"
  echo "  install_openvpn.sh --uninstall"
}

handle_args() {
  ensure_root

  case "${1:-}" in
    --list-clients)
      list_clients
      exit $?
      ;;
    --add-client)
      shift
      if [ -z "${1:-}" ]; then usage; exit 1; fi
      if [ ! -d "$PKI_DIR" ]; then echo -e "${RED}âŒ Primero instala OpenVPN.${NC}"; exit 1; fi
      create_client "$1"
      exit $?
      ;;
    --revoke-client)
      shift
      if [ -z "${1:-}" ]; then usage; exit 1; fi
      if [ ! -d "$PKI_DIR" ]; then echo -e "${RED}âŒ Primero instala OpenVPN.${NC}"; exit 1; fi
      revoke_client "$1"
      exit $?
      ;;
    --status)
      read_current_server_settings
      systemctl is-active --quiet openvpn-server@server 2>/dev/null && st="ON" || st="OFF"
      echo "OPENVPN_STATUS=${st}"
      echo "OPENVPN_PORT=${OVPN_PORT}"
      echo "OPENVPN_PROTO=${OVPN_PROTO}"
      exit 0
      ;;
    --uninstall)
      uninstall_openvpn
      exit $?
      ;;
    "" )
      return 0
      ;;
    * )
      usage
      exit 1
      ;;
  esac
}

menu() {
  ensure_root

  while true; do
    clear
    read_current_server_settings
    systemctl is-active --quiet openvpn-server@server 2>/dev/null && st="${GREEN}[ON]${NC}" || st="${RED}[OFF]${NC}"
    echo -e "${CYAN}=========================================================${NC}"
    echo -e "${YELLOW}                INSTALADOR OPENVPN (VPN)${NC}"
    echo -e "${CYAN}=========================================================${NC}"
    echo -e " Estado: $st   Puerto: ${WHITE}${OVPN_PORT}/${OVPN_PROTO}${NC}"
    echo -e "${CYAN}---------------------------------------------------------${NC}"
    echo -e " ${CYAN}[1]${WHITE} Instalar / Reinstalar OpenVPN${NC}"
    echo -e " ${CYAN}[2]${WHITE} Crear Cliente (.ovpn)${NC}"
    echo -e " ${CYAN}[3]${WHITE} Revocar Cliente${NC}"
    echo -e " ${CYAN}[4]${RED} Desinstalar OpenVPN${NC}"
    echo -e " ${CYAN}[0]${WHITE} Salir${NC}"
    echo -e "${CYAN}=========================================================${NC}"
    read -p " Selecciona: " opt

    case "$opt" in
      1)
        echo -e "\n${YELLOW}â–¶ ConfiguraciÃ³n del Servidor OpenVPN${NC}"
        read -p " Protocolo (udp/tcp) [Default: udp]: " proto
        [ -z "$proto" ] && proto="udp"
        if [ "$proto" != "udp" ] && [ "$proto" != "tcp" ]; then
          echo -e "${RED}Protocolo invÃ¡lido.${NC}"; sleep 2; continue
        fi
        read -p " Puerto [Default: 1194]: " port
        [ -z "$port" ] && port="1194"

        echo -e "${GREEN}[+] Limpieza de puerto ${port}/${proto}...${NC}"
        fuser -k "${port}/${proto}" >/dev/null 2>&1 || true

        install_deps
        enable_forwarding

        init_pki
        write_server_conf "$proto" "$port"

        open_firewall "$proto" "$port"
        write_iptables_rules "$(detect_iface)" "$proto" "$port"

        restart_openvpn
        
        # Instalar y activar el servidor de descargas
        if [ -f "/etc/adm-lite/modules/install_file-server.sh" ]; then
            bash "/etc/adm-lite/modules/install_file-server.sh"
        fi

        sleep 2
        if systemctl is-active --quiet openvpn-server@server 2>/dev/null; then
          echo -e "\n${GREEN}=========================================================${NC}"
          echo -e "${GREEN} âœ… OPENVPN INSTALADO CORRECTAMENTE${NC}"
          echo -e "${CYAN} Puerto: ${WHITE}${port}/${proto}${NC}"
          echo -e "${CYAN} Clientes: ${WHITE}${CLIENTS_DIR}${NC}"
          echo -e "${GREEN}=========================================================${NC}"
          read -p " Nombre del primer cliente (Default: mx): " c1
          [ -z "$c1" ] && c1="mx"
          create_client "$c1"
        else
          echo -e "\n${RED}âš ï¸ OpenVPN no arrancÃ³. Revisa:${NC} ${YELLOW}systemctl status openvpn-server@server${NC}"
        fi
        read -p "Presiona Enter..." ;;
      2)
        if [ ! -d "$PKI_DIR" ]; then
          echo -e "${RED}Primero instala OpenVPN (OpciÃ³n 1).${NC}"; sleep 2; continue
        fi
        read -p " Nombre del cliente: " c
        if [ -z "$c" ]; then echo -e "${RED}Nombre invÃ¡lido.${NC}"; sleep 2; continue; fi
        create_client "$c"
        read -p "Presiona Enter..." ;;
      3)
        if [ ! -d "$PKI_DIR" ]; then
          echo -e "${RED}Primero instala OpenVPN (OpciÃ³n 1).${NC}"; sleep 2; continue
        fi
        read -p " Cliente a revocar: " c
        if [ -z "$c" ]; then echo -e "${RED}Nombre invÃ¡lido.${NC}"; sleep 2; continue; fi
        revoke_client "$c"
        read -p "Presiona Enter..." ;;
      4)
        echo -e "\n${RED}âš ï¸ Esto eliminarÃ¡ OpenVPN y los clientes.${NC}"
        read -p " Â¿Confirmas? (s/n): " conf
        if [[ "$conf" == "s" || "$conf" == "S" ]]; then
          uninstall_openvpn
        fi
        read -p "Presiona Enter..." ;;
      0) exit 0 ;;
      *) ;;
    esac
  done
}

handle_args "$@"
menu

