#!/bin/bash
# ChumoGH - Instalador UDP-CUSTOM v2.1
# AutenticaciÃ³n: Usa los mismos usuarios SSH del panel
# Formato cliente: IP:1-65535@usuarioSSH:contraseÃ±aSSH

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}=========================================================${NC}"
echo -e "${YELLOW}         INSTALADOR UDP-CUSTOM (TUNNELING UDP)${NC}"
echo -e "${CYAN}=========================================================${NC}"
echo -e "${WHITE} Los clientes usan sus credenciales SSH locales.${NC}"
echo -e "${CYAN} Formato: IP:7100-7200@usuarioSSH:contraseÃ±aSSH${NC}"
echo -e "${CYAN}=========================================================${NC}"

echo -e "\n${GREEN}[+] Preparando entorno...${NC}"

# Detectar arquitectura
ARCH=$(uname -m)
case $ARCH in
    x86_64)  BIN_ARCH="amd64"  ;;
    aarch64) BIN_ARCH="arm64"  ;;
    armv7l)  BIN_ARCH="arm"    ;;
    *)       echo -e "${RED}âŒ Arquitectura $ARCH no soportada.${NC}"; exit 1 ;;
esac

# Matar procesos previos y limpiar sockets (IMPORTANTE: Antes de descargar para liberar el archivo)
echo -e "${GREEN}[+] Limpiando procesos y sockets previos para liberar el puerto 36712...${NC}"
systemctl stop udp-custom 2>/dev/null
pkill -9 udp-custom 2>/dev/null
killall -9 udp-custom 2>/dev/null
fuser -k 36712/udp 2>/dev/null
rm -f /usr/local/bin/udp-custom 2>/dev/null

# Directorio de trabajo y binario
UDP_DIR="/etc/udp-custom"
mkdir -p "$UDP_DIR"
mkdir -p "/var/log/ChumoGH"

# Intentar copiar desde la bÃ³veda local del panel para evitar descargas
if [ -f "/etc/adm-lite/bin/udp-custom-linux-${BIN_ARCH}" ]; then
    echo -e "${GREEN}[âœ”] Copiando UDP-Custom desde la BÃ³veda Local Maximus...${NC}"
    cp -f "/etc/adm-lite/bin/udp-custom-linux-${BIN_ARCH}" "$UDP_DIR/udp-custom"
else
    # Descargar el binario directamente si no existe localmente
    echo -e "${YELLOW}[+] Descargando UDP-Custom desde la BÃ³veda Remota Maximus...${NC}"
    if curl -sL -f --connect-timeout 10 --max-time 60 -o "$UDP_DIR/udp-custom" "https://raw.githubusercontent.com/JuandeMx/MAXIMUS/main/bin/udp-custom-linux-${BIN_ARCH}"; then
        echo -e "${GREEN}[âœ”] Descarga segura exitosa (BÃ³veda MAXIMUS).${NC}"
    else
        echo -e "${RED}âŒ Error: No se pudo conectar a la BÃ³veda MAXIMUS.${NC}"
        echo -e "${RED}   Verifica la conexiÃ³n a internet del servidor.${NC}"
        exit 1
    fi
fi

# VALIDACIÃ“N CRÃTICA DE INTEGRIDAD (Evitar archivos de 14 bytes/404)
size=$(stat -c%s "$UDP_DIR/udp-custom" 2>/dev/null || echo 0)
if [ "$size" -lt 1000000 ]; then
    echo -e "${RED}âŒ ERROR: El archivo descargado es corrupto o invÃ¡lido ($size bytes).${NC}"
    echo -e "${RED}   Probablemente el enlace Mirror cambiÃ³. Abortando para proteger el sistema.${NC}"
    rm -f "$UDP_DIR/udp-custom"
    exit 1
fi

chmod +x "$UDP_DIR/udp-custom"

# --- PRUEBA DE VUELO (DIAGNÃ“STICO) ---
echo -e "${YELLOW}[+] Verificando integridad del binario...${NC}"
ls -lh "$UDP_DIR/udp-custom"
echo -ne "${YELLOW}[+] Prueba de ejecuciÃ³n manual: ${NC}"
timeout 3s "$UDP_DIR/udp-custom" -h > /tmp/udp_test.log 2>&1
if [ $? -eq 127 ]; then
    echo -e "${RED}[FALLO: LibrerÃ­a faltante]${NC}"
    ldd "$UDP_DIR/udp-custom" 2>/dev/null || echo "No se pudo ejecutar ldd."
elif [ $? -eq 126 ]; then
    echo -e "${RED}[FALLO: Permisos/Arquitectura]${NC}"
else
    echo -e "${GREEN}[OK/Respuesta recibida]${NC}"
fi

# Generar configuraciÃ³n de escucha directa (Puerto :36712)
echo -e "${GREEN}[+] Generando configuraciÃ³n de escucha directa (Puerto :36712)...${NC}"
cat > "$UDP_DIR/config.json" << UDPEOF
{
    "listen": ":36712",
    "stream_buffer": 33554432,
    "receive_buffer": 83886080,
    "auth": {
        "mode": "passwords"
    }
}
UDPEOF

# Crear servicio systemd con Logs de DepuraciÃ³n
echo -e "${GREEN}[+] Creando servicio systemd con registros de error...${NC}"
cat > /etc/systemd/system/udp-custom.service << EOF
[Unit]
Description=ChumoGH UDP-Custom Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$UDP_DIR
ExecStart=${UDP_DIR}/udp-custom server
Restart=always
RestartSec=3
LimitNOFILE=infinity
StandardOutput=append:/var/log/ChumoGH/udp-custom.log
StandardError=append:/var/log/ChumoGH/udp-custom.log

[Install]
WantedBy=multi-user.target
EOF

# Habilitar IP Forwarding (Vital para mÃ©todos de internet gratis)
echo -ne "${GREEN}[+] Habilitando IPv4 Forwarding...${NC}"
sysctl -w net.ipv4.ip_forward=1 > /dev/null
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo -e "${GREEN} [OK]${NC}"

# Puerto configurable y Rango (DinÃ¡mico)
udp_range="${1:-7100:7200}"
# Normalizar formato (ej: 7100-7200 -> 7100:7200)
udp_range=$(echo $udp_range | tr '-' ':')

# Abrir puertos en firewall y configurar REDIRECCIÃ“N ESTRATÃ‰GICA (NAT)
echo -e "${GREEN}[+] Configurando Rango EstratÃ©gico UDP ($udp_range -> 36712)...${NC}"
ufw allow $udp_range/udp 2>/dev/null

# Limpiar reglas previas especÃ­ficas de este rango para evitar duplicados
iptables -t nat -D PREROUTING -p udp --dport $udp_range -j REDIRECT --to-port 36712 2>/dev/null
ip6tables -t nat -D PREROUTING -p udp --dport $udp_range -j REDIRECT --to-port 36712 2>/dev/null

# Aplicar RedirecciÃ³n (IPv4 e IPv6)
iptables -t nat -A PREROUTING -p udp --dport $udp_range -j REDIRECT --to-port 36712
ip6tables -t nat -A PREROUTING -p udp --dport $udp_range -j REDIRECT --to-port 36712

# Guardar reglas para que sean permanentes
if command -v iptables-save > /dev/null; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
fi

# Activar y arrancar
systemctl daemon-reload
systemctl enable --now udp-custom 2>/dev/null
systemctl restart udp-custom 2>/dev/null

# Obtener IP del servidor
SERVER_IP=$(wget -qO- ipv4.icanhazip.com 2>/dev/null)
[ -z "$SERVER_IP" ] && SERVER_IP="TU_IP"

# VerificaciÃ³n
sleep 2
if systemctl is-active --quiet udp-custom; then
    echo -e "\n${GREEN}=========================================================${NC}"
    echo -e "${GREEN} âœ… UDP-CUSTOM INSTALADO CORRECTAMENTE${NC}"
    echo -e "${GREEN}=========================================================${NC}"
    echo -e "${CYAN} Rango de puertos: 7100-7200${NC}"
    echo -e "${CYAN} AutenticaciÃ³n:    Segura (Usuarios SSH)${NC}"
    echo -e "${GREEN}---------------------------------------------------------${NC}"
    echo -e "${YELLOW} ðŸ“‹ CONFIGURACIÃ“N PARA EL CLIENTE:${NC}"
    echo -e "${WHITE} ${SERVER_IP}:7100-7200@USUARIO:CONTRASEÃ‘A${NC}"
    echo -e "${GREEN}=========================================================${NC}"
else
    echo -e "\n${RED}=========================================================${NC}"
    echo -e "${RED} âš ï¸ UDP-CUSTOM no arrancÃ³. Verifica con:${NC}"
    echo -e "${YELLOW} systemctl status udp-custom${NC}"
    echo -e "\n${CYAN}----- ÃšLTIMOS LOGS DE ERROR -----${NC}"
    tail -n 10 /var/log/ChumoGH/udp-custom.log 2>/dev/null || echo "Sin registros disponibles."
    echo -e "${RED}=========================================================${NC}"
fi
sleep 3
