#!/bin/bash
# ChumoGH - SSL + PYTHON (Combo Completo)
# Configura Dropbear + Python WebSocket Proxy + Stunnel4 SSL en un solo paso

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

activar_ssl_python() {
    ui_header "INSTALAR SSL + PYTHON (COMBO COMPLETO)"
    echo -e "${WHITE}Este mÃ³dulo configura todo de un solo golpe:${NC}"
    echo -e "  ${CYAN}1.${WHITE} Dropbear SSH (si no estÃ¡ activo)${NC}"
    echo -e "  ${CYAN}2.${WHITE} Proxy Python WebSocket (Puerto 80)${NC}"
    echo -e "  ${CYAN}3.${WHITE} SSL/TLS vÃ­a Stunnel4 (Puerto 443)${NC}"
    ui_hr

    # â•â•â•â•â•â•â•â•â•â•â• PASO 1: PUERTOS â•â•â•â•â•â•â•â•â•â•â•
    echo -e "\n${YELLOW}â•â•â• PASO 1: CONFIGURACIÃ“N DE PUERTOS â•â•â•${NC}\n"

    read -p " Puerto Dropbear SSH [442]: " DROPBEAR_PORT
    [ -z "$DROPBEAR_PORT" ] && DROPBEAR_PORT=442

    read -p " Puerto OpenSSH [22]: " SSH_PORT
    [ -z "$SSH_PORT" ] && SSH_PORT=22

    read -p " Puerto Proxy Python (WebSocket) [80]: " PROXY_PORT
    [ -z "$PROXY_PORT" ] && PROXY_PORT=80

    read -p " Puerto SSL (Stunnel4) [443]: " SSL_PORT
    [ -z "$SSL_PORT" ] && SSL_PORT=443

    # â•â•â•â•â•â•â•â•â•â•â• PASO 2: ESTADO Y ENCABEZADO â•â•â•â•â•â•â•â•â•â•â•
    echo ""
    ui_subhr
    echo -e "${YELLOW}â•â•â• PASO 2: TEXTO DE ESTADO Y ENCABEZADO â•â•â•${NC}\n"

    local default_status="By MAXIMUS | ELITE"
    if [ -f /etc/adm-lite/core/small_banner.txt ]; then
        default_status=$(cat /etc/adm-lite/core/small_banner.txt | tr -d '\r\n')
    fi

    read -p " Texto de Estado [$default_status]: " STATUS_TEXT
    [ -z "$STATUS_TEXT" ] && STATUS_TEXT="$default_status"
    echo "$STATUS_TEXT" > /etc/adm-lite/core/small_banner.txt

    read -p " CÃ³digo de Encabezado (101, 200, 404, 500) [200]: " STATUS_CODE
    [ -z "$STATUS_CODE" ] && STATUS_CODE=200

    # â•â•â•â•â•â•â•â•â•â•â• RESUMEN â•â•â•â•â•â•â•â•â•â•â•
    ui_hr
    echo -e "${YELLOW}           RESUMEN DE CONFIGURACIÃ“N${NC}"
    ui_hr
    echo -e "  ${WHITE}Dropbear SSH:     ${GREEN}Puerto $DROPBEAR_PORT${NC}"
    echo -e "  ${WHITE}OpenSSH:          ${GREEN}Puerto $SSH_PORT${NC}"
    echo -e "  ${WHITE}Proxy Python WS:  ${GREEN}Puerto $PROXY_PORT -> 127.0.0.1:$DROPBEAR_PORT${NC}"
    echo -e "  ${WHITE}SSL Stunnel4:     ${GREEN}Puerto $SSL_PORT -> 127.0.0.1:$PROXY_PORT${NC}"
    echo -e "  ${WHITE}Texto de Estado:  ${GREEN}$STATUS_TEXT${NC}"
    echo -e "  ${WHITE}CÃ³digo Respuesta: ${GREEN}$STATUS_CODE${NC}"
    ui_hr
    read -p " Â¿Deseas continuar con esta configuraciÃ³n? [s/n]: " confirmar
    if [[ "$confirmar" != "s" && "$confirmar" != "S" && "$confirmar" != "" ]]; then
        echo -e "${RED}âŒ InstalaciÃ³n cancelada.${NC}"
        ui_pause
        return 1
    fi

    # â•â•â•â•â•â•â•â•â•â•â• PASO 3: INSTALAR Y COMPILAR DROPBEAR â•â•â•â•â•â•â•â•â•â•â•
    ui_hr
    echo -e "${YELLOW}[1/3] Compilando Dropbear SSH con soporte para HTTP Custom en puerto $DROPBEAR_PORT...${NC}"
    
    # Instalar paquete base para obtener configuraciÃ³n systemd
    DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -y dropbear >/dev/null 2>&1
    
    # Compilar desde fuente con algoritmos heredados
    mkdir -p /var/log/ChumoGH
    echo "=== CompilaciÃ³n Dropbear (SSL+Python combo) ===" > /var/log/ChumoGH/dropbear_compile.log
    
    echo -e "${YELLOW}  [+] Instalando dependencias de compilaciÃ³n...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential zlib1g-dev wget bzip2 libcrypt-dev libpam0g-dev >> /var/log/ChumoGH/dropbear_compile.log 2>&1
    
    cd /tmp
    rm -rf dropbear-2022.83*
    echo -e "${YELLOW}  [+] Descargando cÃ³digo fuente de Dropbear 2022.83...${NC}"
    if wget -q https://matt.ucc.asn.au/dropbear/releases/dropbear-2022.83.tar.bz2 || wget -q https://dropbear.nl/mirror/releases/dropbear-2022.83.tar.bz2; then
        tar -xf dropbear-2022.83.tar.bz2 >> /var/log/ChumoGH/dropbear_compile.log 2>&1
        cd dropbear-2022.83
        
        # localoptions.h con algoritmos heredados para HTTP Custom y #undef para evitar advertencias/errores
        cat <<'LOCALOPT' > localoptions.h
#ifndef DROPBEAR_LOCALOPTIONS_H
#define DROPBEAR_LOCALOPTIONS_H

/* Habilitar CBC mode (deshabilitado por defecto) */
#undef DROPBEAR_ENABLE_CBC_MODE
#define DROPBEAR_ENABLE_CBC_MODE 1

/* Habilitar 3DES (deshabilitado por defecto) */
#undef DROPBEAR_3DES
#define DROPBEAR_3DES 1

/* Habilitar SHA1 HMAC (deshabilitado por defecto en nuevas versiones) */
#undef DROPBEAR_SHA1_HMAC
#define DROPBEAR_SHA1_HMAC 1

#undef DROPBEAR_SHA1_96_HMAC
#define DROPBEAR_SHA1_96_HMAC 1

/* Habilitar RSA con SHA1 (requerido para clientes antiguos como HTTP Custom) */
#undef DROPBEAR_RSA_SHA1
#define DROPBEAR_RSA_SHA1 1

/* Habilitar DH Group14 SHA1 y SHA256 (compatibilidad) */
#undef DROPBEAR_DH_GROUP14_SHA1
#define DROPBEAR_DH_GROUP14_SHA1 1

#undef DROPBEAR_DH_GROUP14_SHA256
#define DROPBEAR_DH_GROUP14_SHA256 1

/* Habilitar DSS (algunos clientes antiguos lo requieren) */
#undef DROPBEAR_DSS
#define DROPBEAR_DSS 1

/* Aumentar lÃ­mites de Banner para soportar HTML banners grandes */
#undef MAX_BANNER_SIZE
#define MAX_BANNER_SIZE 16384

/* Habilitar soporte PAM y deshabilitar PASSWORD directo */
#undef DROPBEAR_SVR_PAM_AUTH
#define DROPBEAR_SVR_PAM_AUTH 1

#undef DROPBEAR_SVR_PASSWORD_AUTH
#define DROPBEAR_SVR_PASSWORD_AUTH 0

#endif /* DROPBEAR_LOCALOPTIONS_H */
LOCALOPT
        
        # Modificar sysoptions.h directamente ya que no tiene guardas #ifndef
        sed -i 's/#define MAX_BANNER_SIZE 2050/#define MAX_BANNER_SIZE 16384/g' sysoptions.h
        sed -i 's/#define MAX_BANNER_LINES 20/#define MAX_BANNER_LINES 100/g' sysoptions.h
        
        echo -e "${YELLOW}  [+] Configurando (./configure --enable-pam)...${NC}"
        if ./configure --enable-pam >> /var/log/ChumoGH/dropbear_compile.log 2>&1; then
            echo -e "${YELLOW}  [+] Compilando binarios...${NC}"
            if make clean >> /var/log/ChumoGH/dropbear_compile.log 2>&1 && make PROGRAMS="dropbear dropbearkey" -j$(nproc) >> /var/log/ChumoGH/dropbear_compile.log 2>&1; then
                systemctl stop dropbear.socket 2>/dev/null || true
                systemctl stop dropbear 2>/dev/null || true
                cp -f dropbear /usr/sbin/dropbear
                cp -f dropbearkey /usr/bin/dropbearkey
                [ -f dropbearconvert ] && cp -f dropbearconvert /usr/bin/dropbearconvert
                
                # Crear configuraciÃ³n PAM para Dropbear si no existe
                mkdir -p /etc/pam.d
                cat <<'PAMEOF' >/etc/pam.d/dropbear
@include common-auth
@include common-account
@include common-session
session optional pam_exec.so stdout /etc/adm-lite/core/maximus_banner.sh
PAMEOF

                echo -e "${GREEN}  âœ“ Dropbear compilado con soporte legacy y PAM exitosamente.${NC}"
            else
                echo -e "${RED}  âŒ Error al compilar. Se usarÃ¡ el binario del sistema (puede fallar con HTTP Custom).${NC}"
                tail -n 15 /var/log/ChumoGH/dropbear_compile.log
            fi
        else
            echo -e "${RED}  âŒ Error en ./configure. Se usarÃ¡ el binario del sistema.${NC}"
        fi
        cd /tmp
    else
        echo -e "${RED}  âš  No se pudo descargar fuente. Se usarÃ¡ el binario del sistema.${NC}"
    fi

    mkdir -p /etc/dropbear
    touch /etc/dropbear/banner
    
    cat <<EOF >/etc/default/dropbear
NO_START=0
DROPBEAR_EXTRA_ARGS="-p $DROPBEAR_PORT -b /etc/dropbear/banner -K 30 -I 0"
DROPBEAR_BANNER="/etc/dropbear/banner"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

    grep -q "^/bin/false" /etc/shells || echo "/bin/false" >>/etc/shells
    
    dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key >/dev/null 2>&1
    dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key >/dev/null 2>&1
    dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key >/dev/null 2>&1
    
    systemctl stop dropbear.socket >/dev/null 2>&1 || true
    systemctl disable dropbear.socket >/dev/null 2>&1 || true
    systemctl mask dropbear.socket >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/dropbear.service.d/override.conf 2>/dev/null
    
    ufw allow $DROPBEAR_PORT/tcp >/dev/null 2>&1
    systemctl daemon-reload
    systemctl enable dropbear >/dev/null 2>&1
    systemctl restart dropbear >/dev/null 2>&1
    
    if systemctl is-active --quiet dropbear; then
        echo -e "${GREEN}  âœ“ Dropbear ACTIVO en puerto $DROPBEAR_PORT${NC}"
    else
        echo -e "${RED}  âŒ Error al iniciar Dropbear${NC}"
    fi

    # â•â•â•â•â•â•â•â•â•â•â• PASO 4: PROXY PYTHON WEBSOCKET â•â•â•â•â•â•â•â•â•â•â•
    echo -e "\n${YELLOW}[2/3] Configurando Proxy Python WebSocket en puerto $PROXY_PORT...${NC}"
    
    # Matar proxy previo en ese puerto si existiera
    fuser -k $PROXY_PORT/tcp >/dev/null 2>&1
    sleep 1

    # Generar script Python dinÃ¡mico
    mkdir -p /etc/adm-lite/core
    cat <<PYEOF >/etc/adm-lite/core/PDirect-${PROXY_PORT}.py
# -*- coding: utf-8 -*-
import socket, threading, select, sys, time

# Config
LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = ${PROXY_PORT}
BUFLEN = 16384
TIMEOUT = 60
DEFAULT_HOST = '127.0.0.1:${DROPBEAR_PORT}'

# Responses based on user status configuration
RESPONSE_WS = f'HTTP/1.1 101 ${STATUS_TEXT}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n'.encode('utf-8')
RESPONSE_STD = f'HTTP/1.1 ${STATUS_CODE} ${STATUS_TEXT}\r\nContent-length: 0\r\n\r\n'.encode('utf-8')
RESPONSE_CONTINUE = b'HTTP/1.1 100 Continue\r\n\r\n'

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port

    def run(self):
        try:
            self.soc = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.soc.settimeout(2)
            self.soc.bind((self.host, self.port))
            self.soc.listen(100)
            self.running = True
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                except socket.timeout:
                    continue
                conn = ConnectionHandler(c, addr)
                conn.daemon = True
                conn.start()
        except:
            pass
        finally:
            self.running = False
            self.soc.close()

def collect_headers(sock, initial_buffer, timeout_sec):
    buf = initial_buffer
    deadline = time.time() + timeout_sec
    while b'\r\n\r\n' not in buf and b'\n\n' not in buf:
        remaining = deadline - time.time()
        if remaining <= 0: break
        r, _, _ = select.select([sock], [], [], min(remaining, 0.5))
        if sock in r:
            chunk = sock.recv(BUFLEN)
            if not chunk: break
            buf += chunk
        else:
            break
    return buf

class ConnectionHandler(threading.Thread):
    def __init__(self, socClient, addr):
        threading.Thread.__init__(self)
        self.client = socClient
        self.addr = addr

    def run(self):
        target = None
        try:
            self.client.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            self.client.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)

            # Peeking the initial packet
            client_buffer = b''
            r, _, _ = select.select([self.client], [], [], 0.5)
            if r:
                client_buffer = self.client.recv(BUFLEN)

            is_ssh = client_buffer.startswith(b'SSH-')
            is_payload = (not is_ssh) and (len(client_buffer) > 0)

            if is_payload:
                client_buffer = collect_headers(self.client, client_buffer, 5)
                is_ws = b'upgrade: websocket' in client_buffer.lower()
                is_split = b'100-continue' in client_buffer.lower()

                if is_split:
                    self.client.sendall(RESPONSE_CONTINUE)
                    second_buffer = b''
                    second_buffer = collect_headers(self.client, second_buffer, 3)
                    if b'websocket' in second_buffer.lower():
                        self.client.sendall(RESPONSE_WS)
                    else:
                        self.client.sendall(RESPONSE_STD)
                elif is_ws:
                    self.client.sendall(RESPONSE_WS)
                else:
                    self.client.sendall(RESPONSE_STD)
                
                time.sleep(0.1)

            # Parse backend from X-Real-Host if present, else fallback
            hostPort = ''
            if is_payload:
                hostPort = self.findHeader(client_buffer, 'X-Real-Host')
            
            if not hostPort:
                hostPort = DEFAULT_HOST

            i = hostPort.find(':')
            if i != -1:
                port = int(hostPort[i+1:])
                host = hostPort[:i]
            else:
                host = '127.0.0.1'
                port = ${DROPBEAR_PORT}

            if host == 'localhost':
                host = '127.0.0.1'

            target = socket.create_connection((host, port), timeout=3)
            target.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

            # Send initial data to backend
            if is_ssh:
                target.sendall(client_buffer)
            elif is_payload:
                header_end = -1
                if b'\r\n\r\n' in client_buffer:
                    header_end = client_buffer.find(b'\r\n\r\n') + 4
                elif b'\n\n' in client_buffer:
                    header_end = client_buffer.find(b'\n\n') + 2
                
                if header_end != -1:
                    leftover = client_buffer[header_end:]
                    if leftover: target.sendall(leftover)

            # Relay loop
            sockets = [self.client, target]
            while True:
                r, _, e = select.select(sockets, [], sockets, 3600)
                if not r or e: break
                for sock in r:
                    data = sock.recv(BUFLEN)
                    if not data: return
                    out = target if sock is self.client else self.client
                    out.sendall(data)

        except:
            pass
        finally:
            try:
                self.client.shutdown(socket.SHUT_RDWR)
                self.client.close()
            except: pass
            try:
                if target:
                    target.shutdown(socket.SHUT_RDWR)
                    target.close()
            except: pass

    def findHeader(self, head, header):
        try:
            if isinstance(head, bytes):
                head = head.decode('utf-8', errors='ignore')
            aux = head.find(header + ': ')
            if aux == -1: return ''
            aux = head.find(':', aux)
            head = head[aux+2:]
            aux = head.find('\r\n')
            if aux == -1: return ''
            return head[:aux]
        except:
            return ''

if __name__ == '__main__':
    try:
        server = Server(LISTENING_ADDR, LISTENING_PORT)
        server.start()
        while True:
            time.sleep(2)
    except:
        pass
PYEOF

    chmod +x /etc/adm-lite/core/PDirect-${PROXY_PORT}.py
    ufw allow ${PROXY_PORT}/tcp >/dev/null 2>&1
    
    # Ejecutar en screen
    screen -dmS pydic-${PROXY_PORT} python3 /etc/adm-lite/core/PDirect-${PROXY_PORT}.py 2>/dev/null
    echo "${PROXY_PORT}" >> /etc/adm-lite/core/PDirect.log
    
    sleep 1
    if ps aux | grep -v grep | grep -q "PDirect-${PROXY_PORT}"; then
        echo -e "${GREEN}  âœ“ Proxy Python WS ACTIVO en puerto $PROXY_PORT -> Dropbear $DROPBEAR_PORT${NC}"
    else
        echo -e "${RED}  âŒ Error al iniciar el proxy Python${NC}"
    fi

    # â•â•â•â•â•â•â•â•â•â•â• PASO 5: SSL STUNNEL4 â•â•â•â•â•â•â•â•â•â•â•
    echo -e "\n${YELLOW}[3/3] Configurando SSL (Stunnel4) en puerto $SSL_PORT...${NC}"
    
    DEBIAN_FRONTEND=noninteractive apt-get install -y stunnel4 openssl >/dev/null 2>&1
    
    mkdir -p /etc/stunnel
    cat <<EOF >/etc/stunnel/stunnel.conf
client = no
[SSL]
cert = /etc/stunnel/stunnel.pem
accept = ${SSL_PORT}
connect = 127.0.0.1:${PROXY_PORT}
EOF

    # Generar certificado auto-firmado si no existe
    if [[ ! -f /etc/stunnel/stunnel.pem ]]; then
        echo -e "${YELLOW}  [+] Generando certificado SSL auto-firmado...${NC}"
        openssl genrsa -out /etc/stunnel/stunnel.key 2048 >/dev/null 2>&1
        (echo "MX" ; echo "Mexico" ; echo "CDMX" ; echo "Maximus" ; echo "Elite" ; echo "MaximusElite" ; echo "admin@maximus.com" ) | openssl req -new -key /etc/stunnel/stunnel.key -x509 -days 1000 -out /etc/stunnel/stunnel.crt >/dev/null 2>&1
        cat /etc/stunnel/stunnel.crt /etc/stunnel/stunnel.key > /etc/stunnel/stunnel.pem
        rm -f /etc/stunnel/stunnel.crt /etc/stunnel/stunnel.key
    fi
    
    sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4 2>/dev/null
    echo "ENABLED=1" >>/etc/default/stunnel4
    
    ufw allow ${SSL_PORT}/tcp >/dev/null 2>&1
    systemctl daemon-reload
    systemctl enable stunnel4 >/dev/null 2>&1
    systemctl restart stunnel4 >/dev/null 2>&1
    
    if systemctl is-active --quiet stunnel4; then
        echo -e "${GREEN}  âœ“ SSL Stunnel4 ACTIVO en puerto $SSL_PORT -> Proxy Python $PROXY_PORT${NC}"
    else
        echo -e "${RED}  âŒ Error al iniciar Stunnel4${NC}"
    fi

    # â•â•â•â•â•â•â•â•â•â•â• RESULTADO FINAL â•â•â•â•â•â•â•â•â•â•â•
    SERVER_IP=$(wget -qO- ipv4.icanhazip.com 2>/dev/null)
    [ -z "$SERVER_IP" ] && SERVER_IP="TU_IP"

    echo ""
    ui_hr
    echo -e "${GREEN}       âœ… SSL + PYTHON INSTALADO CON Ã‰XITO${NC}"
    ui_hr
    echo -e ""
    echo -e "  ${YELLOW}ðŸ“‹ CADENA DE CONEXIÃ“N:${NC}"
    echo -e "  ${WHITE}Cliente -> ${CYAN}SSL:$SSL_PORT${WHITE} -> ${CYAN}Python:$PROXY_PORT${WHITE} -> ${CYAN}Dropbear:$DROPBEAR_PORT${NC}"
    echo -e ""
    echo -e "  ${YELLOW}ðŸ“‹ CONFIGURACIÃ“N PARA HTTP CUSTOM:${NC}"
    echo -e "  ${WHITE}IP/Host:  ${GREEN}$SERVER_IP${NC}"
    echo -e "  ${WHITE}SSH Port: ${GREEN}$DROPBEAR_PORT${NC}"
    echo -e "  ${WHITE}SSL Port: ${GREEN}$SSL_PORT${NC}"
    echo -e "  ${WHITE}WS Port:  ${GREEN}$PROXY_PORT${NC}"
    ui_hr
    ui_pause
}

desactivar_ssl_python() {
    ui_header "DESINSTALAR SSL + PYTHON"
    echo -e "${YELLOW}[+] Deteniendo todos los componentes...${NC}"
    
    # Detener proxies Python
    for pid in $(ps aux | grep 'PDirect-' | grep -v grep | awk '{print $2}'); do
        kill -9 "$pid" 2>/dev/null
    done
    screen -wipe >/dev/null 2>&1
    rm -f /etc/adm-lite/core/PDirect-*.py
    rm -f /etc/adm-lite/core/PDirect.log
    
    # Detener Stunnel
    systemctl stop stunnel4 >/dev/null 2>&1
    systemctl disable stunnel4 >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get purge stunnel4 -y >/dev/null 2>&1
    rm -rf /etc/stunnel/* >/dev/null 2>&1
    
    # Detener Dropbear
    systemctl stop dropbear >/dev/null 2>&1
    systemctl disable dropbear >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get purge dropbear -y >/dev/null 2>&1
    rm -f /etc/default/dropbear 2>/dev/null
    
    ui_hr
    echo -e "${GREEN}âœ“ SSL + PYTHON DESINSTALADO COMPLETAMENTE${NC}"
    ui_pause
}

while true; do
    ui_header "SSL + PYTHON (COMBO COMPLETO)"
    
    # Status
    systemctl is-active --quiet dropbear 2>/dev/null && st_drop="${GREEN}[ ACTIVO ]${NC}" || st_drop="${RED}[ OFF ]${NC}"
    ps aux | grep -v grep | grep -q "PDirect-" && st_py="${GREEN}[ ACTIVO ]${NC}" || st_py="${RED}[ OFF ]${NC}"
    systemctl is-active --quiet stunnel4 2>/dev/null && st_ssl="${GREEN}[ ACTIVO ]${NC}" || st_ssl="${RED}[ OFF ]${NC}"
    
    echo -e "  ${WHITE}Estado Actual:${NC}"
    echo -e "    ${WHITE}Dropbear SSH:    $st_drop"
    echo -e "    ${WHITE}Proxy Python WS: $st_py"
    echo -e "    ${WHITE}SSL Stunnel4:    $st_ssl"
    ui_hr
    echo -e "  ${CYAN}[1]>${WHITE} INSTALAR / CONFIGURAR SSL + PYTHON${NC}"
    echo -e "  ${CYAN}[2]>${WHITE} DESINSTALAR SSL + PYTHON${NC}"
    ui_hr
    echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
    ui_hr
    ui_prompt "Selecciona una opciÃ³n: "
    read -r opcao
    
    case $opcao in
        1) activar_ssl_python ;;
        2) desactivar_ssl_python ;;
        0) break ;;
        *) continue ;;
    esac
done
