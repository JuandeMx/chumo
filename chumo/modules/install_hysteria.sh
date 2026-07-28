#!/bin/bash
# ChumoGH - Instalador Hysteria 2
# Protocolo QUIC/UDP de alta velocidad con mascarada anti-DPI

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}=========================================================${NC}"
echo -e "${YELLOW}          INSTALADOR HYSTERIA v2 (QUIC/UDP)${NC}"
echo -e "${CYAN}=========================================================${NC}"

# Puerto configurable y Rango de Port-Hopping (DinÃ¡mico)
hy_range="${1:-2000:5000}"
# Normalizar formato (ej: 2000-5000 -> 2000:5000)
hy_range=$(echo $hy_range | tr '-' ':')
hy_port=36713

# ContraseÃ±a de autenticaciÃ³n por defecto (AutomÃ¡tica)
hy_pass="maximus"

echo -e "\n${GREEN}[+] Preparando entorno e instalando dependencias...${NC}"
apt-get update -y && apt-get install -y python3 wget openssl 2>/dev/null

# Detectar arquitectura
ARCH=$(uname -m)
case $ARCH in
    x86_64)  BIN_ARCH="amd64"  ;;
    aarch64) BIN_ARCH="arm64"  ;;
    armv7l)  BIN_ARCH="armv7"  ;;
    *)       echo -e "${RED}âŒ Arquitectura $ARCH no soportada.${NC}"; exit 1 ;;
esac

# Directorio de trabajo
HY_DIR="/etc/hysteria"
mkdir -p "$HY_DIR"

# Intentar copiar desde la bÃ³veda local del panel para evitar descargas
if [ -f "/etc/adm-lite/bin/hysteria-linux-${BIN_ARCH}" ]; then
    echo -e "${GREEN}[âœ”] Copiando Hysteria v2 desde la BÃ³veda Local Maximus...${NC}"
    cp -f "/etc/adm-lite/bin/hysteria-linux-${BIN_ARCH}" "$HY_DIR/hysteria"
else
    # Descargar el binario directamente si no existe localmente
    echo -e "${YELLOW}[+] Descargando Hysteria v2 desde la BÃ³veda Remota Maximus...${NC}"
    LATEST_URL="https://raw.githubusercontent.com/JuandeMx/MAXIMUS/main/bin/hysteria-linux-${BIN_ARCH}"
    if curl -sL -f --connect-timeout 10 --max-time 60 -o "$HY_DIR/hysteria" "$LATEST_URL"; then
        echo -e "${GREEN}[âœ”] Descarga segura exitosa.${NC}"
    else
        echo -e "${RED}âŒ Error: No se pudo conectar a la BÃ³veda Remota para Hysteria.${NC}"
        exit 1
    fi
fi

chmod +x "$HY_DIR/hysteria"

# Instalar motor de autenticaciÃ³n
echo -e "${GREEN}[+] Instalando motor de autenticaciÃ³n dinÃ¡mico...${NC}"
mkdir -p /etc/adm-lite/core
cat > /etc/adm-lite/core/hysteria_auth.py << 'PYEOF'
#!/usr/bin/env python3
import sys
import json
import datetime
import os

DB_PATH = "/etc/adm-lite/hysteria_users.db"

def log_debug(msg):
    try:
        with open("/var/log/ChumoGH/hysteria_auth_debug.log", "a") as f:
            f.write(f"[{datetime.datetime.now()}] {msg}\n")
    except:
        pass

def check_auth():
    try:
        line = sys.stdin.readline()
        if not line:
            return
        
        data = json.loads(line)
        client_auth = data.get("auth", "")
        
        if not os.path.exists(DB_PATH):
            print(json.dumps({"ok": False, "msg": "No DB found"}))
            return

        with open(DB_PATH, "r") as f:
            for line in f:
                parts = line.strip().split(":")
                if len(parts) < 5:
                    continue
                
                user, password, expiry_str, up_m, down_m = parts
                
                if password == client_auth:
                    expiry_date = datetime.datetime.strptime(expiry_str, "%Y-%m-%d")
                    if datetime.datetime.now() <= expiry_date:
                        up_bps = int(up_m) * 1000000
                        down_bps = int(down_m) * 1000000
                        
                        resp = {
                            "ok": True,
                            "id": user,
                            "up": up_bps,
                            "down": down_bps
                        }
                        print(json.dumps(resp))
                        return
                    else:
                        print(json.dumps({"ok": False, "msg": "Account expired"}))
                        return

        print(json.dumps({"ok": False, "msg": "Invalid credentials"}))

    except Exception as e:
        log_debug(f"Error: {str(e)}")
        print(json.dumps({"ok": False, "msg": "Internal server error"}))

if __name__ == "__main__":
    check_auth()
PYEOF
chmod +x /etc/adm-lite/core/hysteria_auth.py
touch /etc/adm-lite/hysteria_users.db

# Generar certificado auto-firmado para TLS/QUIC
echo -e "${GREEN}[+] Generando certificado SSL para QUIC...${NC}"
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -sha256 \
    -subj "/CN=bing.com/O=Microsoft/C=US" \
    -keyout "$HY_DIR/hysteria.key" \
    -out "$HY_DIR/hysteria.crt" >/dev/null 2>&1

# Generar configuraciÃ³n YAML (Hysteria v2 Multi-User)
echo -e "${GREEN}[+] Generando configuraciÃ³n con motor de autenticaciÃ³n dinÃ¡mico...${NC}"
cat > "$HY_DIR/config.yaml" << HYEOF
listen: :$hy_port

tls:
  cert: $HY_DIR/hysteria.crt
  key: $HY_DIR/hysteria.key

auth:
  type: command
  command: /etc/adm-lite/core/hysteria_auth.py

obfs:
  type: salamander
  salamander:
    password: maximus_obfs_maestra

masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true

bandwidth:
  up: 100 mbps
  down: 100 mbps
HYEOF

# Matar procesos previos
fuser -k "$hy_port/udp" 2>/dev/null

# Crear servicio systemd
echo -e "${GREEN}[+] Creando servicio systemd...${NC}"
cat > /etc/systemd/system/hysteria.service << EOF
[Unit]
Description=ChumoGH Hysteria v2 QUIC Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$HY_DIR
ExecStart=${HY_DIR}/hysteria server -c ${HY_DIR}/config.yaml
Restart=always
RestartSec=3
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# Abrir puerto en firewall local
ufw allow ${hy_port}/udp 2>/dev/null
ufw allow ${hy_range}/udp 2>/dev/null

# EXCLUSIÃ“N Y PORT-HOPPING NAT
echo -e "${YELLOW}[+] Configurando Port-Hopping (Rango $hy_range -> Interno $hy_port)...${NC}"
# Limpiar previas si las hay
iptables -t nat -D PREROUTING -p udp --dport ${hy_range} -j REDIRECT --to-port ${hy_port} 2>/dev/null
ip6tables -t nat -D PREROUTING -p udp --dport ${hy_range} -j REDIRECT --to-port ${hy_port} 2>/dev/null

iptables -t nat -I PREROUTING -p udp --dport ${hy_range} -j REDIRECT --to-port ${hy_port}
ip6tables -t nat -I PREROUTING -p udp --dport ${hy_range} -j REDIRECT --to-port ${hy_port} 2>/dev/null

# Guardar reglas iptables
if command -v iptables-save > /dev/null; then
    iptables-save > /etc/iptables/rules.v4
fi
# Activar y arrancar
systemctl daemon-reload
systemctl enable --now hysteria 2>/dev/null
systemctl restart hysteria 2>/dev/null

# VerificaciÃ³n
sleep 2
if systemctl is-active --quiet hysteria; then
    echo -e "\n${GREEN}=========================================================${NC}"
    echo -e "${GREEN} âœ… HYSTERIA v2 INSTALADO CORRECTAMENTE${NC}"
    echo -e "${CYAN} Rango Port-Hopping: $hy_range${NC}"
    echo -e "${CYAN} ContraseÃ±a:      $hy_pass${NC}"
    echo -e "${CYAN} Mascarada:       bing.com (Anti-DPI)${NC}"
    echo -e "${GREEN}=========================================================${NC}"
    echo -e "${YELLOW} NOTA: Tu enlace serÃ¡ IP:$hy_range${NC}"
else
    echo -e "\n${RED}=========================================================${NC}"
    echo -e "${RED} âš ï¸ Hysteria se instalÃ³ pero no arrancÃ³ correctamente.${NC}"
    echo -e "${YELLOW} Verifica con: systemctl status hysteria${NC}"
    echo -e "${RED}=========================================================${NC}"
fi
sleep 3
