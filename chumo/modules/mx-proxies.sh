#!/bin/bash
# ChumoGH - Python Proxies & Tunnels Manager
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

get_public_ip() {
    local ip
    ip=$(wget -qO- ipv4.icanhazip.com 2>/dev/null)
    [ -z "$ip" ] && ip=$(curl -fsSL https://api.ipify.org 2>/dev/null)
    [ -z "$ip" ] && ip="127.0.0.1"
    echo "$ip"
}

# --- 12) WEBSOCKET STATUS EDITABLE ---
ws_editable() {
    activar_ws() {
        ui_header "ACTIVAR PROXY WEBSOCKET EDITABLE"
        while true; do
            read -p "Digite el Puerto para el Websocket: " -e -i "8081" porta_socket
            if ! mportas | grep -q -w "$porta_socket"; then
                break
            else
                echo -e "${RED}âŒ Puerto ya en uso. Elige otro.${NC}"
            fi
        done
        
        local default_status="By SCRIPT | LATAM"
        if [ -f /etc/adm-lite/core/small_banner.txt ]; then
            default_status=$(cat /etc/adm-lite/core/small_banner.txt | tr -d '\r\n')
        fi

        read -p "Introduzca el texto de estado (HTML permitido): " -e -i "$default_status" texto_soket
        echo "$texto_soket" > /etc/adm-lite/core/small_banner.txt
        read -p "Digite puerto local de anclaje (ej: SSH 22 / Dropbear 44): " -e -i "444" puetoantla
        read -p "Estatus de encabezado (101, 200, 404, 500): " -e -i "200" rescabeza
        
        ui_hr
        echo -e "${YELLOW}[+] Generando y configurando proxy WebSocket...${NC}"
        
        # Escribir script Python dinÃ¡mico
        cat <<EOF >/etc/adm-lite/core/PDirect-${porta_socket}.py
# -*- coding: utf-8 -*-
import socket, threading, select, sys, time

# Config
LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = ${porta_socket}
BUFLEN = 16384
TIMEOUT = 60
DEFAULT_HOST = '127.0.0.1:${puetoantla}'

# Responses based on user status configuration
RESPONSE_WS = f'HTTP/1.1 101 ${texto_soket}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n'.encode('utf-8')
RESPONSE_STD = f'HTTP/1.1 ${rescabeza} ${texto_soket}\r\nContent-length: 0\r\n\r\n'.encode('utf-8')
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
                port = ${puetoantla}

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
EOF

        chmod +x /etc/adm-lite/core/PDirect-${porta_socket}.py
        ufw allow ${porta_socket}/tcp >/dev/null 2>&1
        
        # Ejecutar
        screen -dmS pydic-${porta_socket} python /etc/adm-lite/core/PDirect-${porta_socket}.py 2>/dev/null || screen -dmS pydic-${porta_socket} python3 /etc/adm-lite/core/PDirect-${porta_socket}.py 2>/dev/null
        
        echo "${porta_socket}" >> /etc/adm-lite/core/PDirect.log
        
        echo -e "${GREEN}âœ“ PROXY WEBSOCKET ACTIVO EN PUERTO: $porta_socket${NC}"
        ui_pause
    }

    desactivar_ws() {
        ui_header "DESACTIVAR PROXY WEBSOCKET"
        log_file="/etc/adm-lite/core/PDirect.log"
        if [[ ! -s "$log_file" ]]; then
            echo -e "${RED}âŒ No hay puertos WebSocket registrados activos.${NC}"
            ui_pause
            return 1
        fi
        
        echo -e "${WHITE}Puertos WebSocket Activos:${NC}"
        ui_subhr
        cat "$log_file"
        ui_subhr
        
        read -p "Digite el puerto a desactivar: " portselect
        screen -S pydic-${portselect} -p 0 -X quit >/dev/null 2>&1
        rm -f /etc/adm-lite/core/PDirect-${portselect}.py
        sed -i "/^${portselect}$/d" "$log_file"
        
        echo -e "${GREEN}âœ“ Proxy WebSocket en puerto $portselect detenido.${NC}"
        ui_pause
    }

    while true; do
        ui_header "WEBSOCKET STATUS EDITABLE"
        echo -e "  ${CYAN}[1]>${WHITE} ACTIVAR NUEVO PROXY WEBSOCKET${NC}"
        echo -e "  ${CYAN}[2]>${WHITE} DETENER UN PROXY WEBSOCKET${NC}"
        ui_hr
        echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
        ui_hr
        ui_prompt "Selecciona: "
        read -r opt
        case $opt in
            1) activar_ws ;;
            2) desactivar_ws ;;
            0) break ;;
        esac
    done
}

# --- 13) PROXY OPENVPN ---
proxy_openvpn() {
    activar_popen() {
        ui_header "ACTIVAR PROXY OPENVPN (PYTHON)"
        while true; do
            read -p "Digite el Puerto para el Proxy OpenVPN: " -e -i "8081" porta_socket
            if ! mportas | grep -q -w "$porta_socket"; then
                break
            else
                echo -e "${RED}âŒ Puerto ya en uso. Elige otro.${NC}"
            fi
        done
        
        read -p "Introduzca el texto de estado: " -e -i "By SCRIPT | LATAM" texto_soket
        
        ufw allow ${porta_socket}/tcp >/dev/null 2>&1
        
        # Iniciar backend
        screen -dmS popenvpn-${porta_socket} python /etc/adm-lite/core/POpen.py "$porta_socket" "$texto_soket" 2>/dev/null || screen -dmS popenvpn-${porta_socket} python3 /etc/adm-lite/core/POpen.py "$porta_socket" "$texto_soket" 2>/dev/null
        
        echo "${porta_socket}" >> /etc/adm-lite/core/POpen.log
        
        ui_hr
        echo -e "${GREEN}âœ“ PROXY OPENVPN ACTIVO EN PUERTO: $porta_socket${NC}"
        ui_pause
    }

    desactivar_popen() {
        ui_header "DESACTIVAR PROXY OPENVPN"
        # Detener screens
        killall -9 POpen.py >/dev/null 2>&1
        for pid in $(ps aux | grep 'POpen.py' | grep -v grep | awk '{print $2}'); do
            kill -9 "$pid" 2>/dev/null
        done
        screen -wipe >/dev/null 2>&1
        rm -f /etc/adm-lite/core/POpen.log
        
        echo -e "${GREEN}âœ“ Todos los Proxies OpenVPN detenidos.${NC}"
        ui_pause
    }

    while true; do
        ui_header "PROXY OPENVPN (PYTHON)"
        echo -e "  ${CYAN}[1]>${WHITE} ACTIVAR PROXY OPENVPN${NC}"
        echo -e "  ${CYAN}[2]>${WHITE} DETENER TODOS LOS PROXIES OPENVPN${NC}"
        ui_hr
        echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
        ui_hr
        ui_prompt "Selecciona: "
        read -r opt
        case $opt in
            1) activar_popen ;;
            2) desactivar_popen ;;
            0) break ;;
        esac
    done
}

# --- 14) PROXY PUBLICO ---
proxy_publico() {
    activar_ppub() {
        ui_header "ACTIVAR PROXY PÃšBLICO (PYTHON)"
        while true; do
            read -p "Digite el Puerto para el Proxy PÃºblico: " -e -i "8082" porta_socket
            if ! mportas | grep -q -w "$porta_socket"; then
                break
            else
                echo -e "${RED}âŒ Puerto ya en uso. Elige otro.${NC}"
            fi
        done
        
        read -p "Introduzca el texto de estado: " -e -i "By SCRIPT | LATAM" texto_soket
        
        ufw allow ${porta_socket}/tcp >/dev/null 2>&1
        
        # Iniciar backend
        screen -dmS ppublico-${porta_socket} python /etc/adm-lite/core/PPub.py "$porta_socket" "$texto_soket" 2>/dev/null || screen -dmS ppublico-${porta_socket} python3 /etc/adm-lite/core/PPub.py "$porta_socket" "$texto_soket" 2>/dev/null
        
        echo "${porta_socket}" >> /etc/adm-lite/core/PPub.log
        
        ui_hr
        echo -e "${GREEN}âœ“ PROXY PÃšBLICO ACTIVO EN PUERTO: $porta_socket${NC}"
        ui_pause
    }

    desactivar_ppub() {
        ui_header "DESACTIVAR PROXY PÃšBLICO"
        killall -9 PPub.py >/dev/null 2>&1
        for pid in $(ps aux | grep 'PPub.py' | grep -v grep | awk '{print $2}'); do
            kill -9 "$pid" 2>/dev/null
        done
        screen -wipe >/dev/null 2>&1
        rm -f /etc/adm-lite/core/PPub.log
        
        echo -e "${GREEN}âœ“ Todos los Proxies PÃºblicos detenidos.${NC}"
        ui_pause
    }

    while true; do
        ui_header "PROXY PUBLICO (PYTHON)"
        echo -e "  ${CYAN}[1]>${WHITE} ACTIVAR PROXY PÃšBLICO${NC}"
        echo -e "  ${CYAN}[2]>${WHITE} DETENER TODOS LOS PROXIES PÃšBLICOS${NC}"
        ui_hr
        echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
        ui_hr
        ui_prompt "Selecciona: "
        read -r opt
        case $opt in
            1) activar_ppub ;;
            2) desactivar_ppub ;;
            0) break ;;
        esac
    done
}

# --- 15) PROXY PRIVADO ---
proxy_privado() {
    activar_ppriv() {
        ui_header "ACTIVAR PROXY PRIVADO (PYTHON)"
        while true; do
            read -p "Digite el Puerto para el Proxy Privado: " -e -i "8083" porta_socket
            if ! mportas | grep -q -w "$porta_socket"; then
                break
            else
                echo -e "${RED}âŒ Puerto ya en uso. Elige otro.${NC}"
            fi
        done
        
        read -p "Introduzca el texto de estado: " -e -i "By SCRIPT | LATAM" texto_soket
        
        local_ip=$(get_public_ip)
        ufw allow ${porta_socket}/tcp >/dev/null 2>&1
        
        # Iniciar backend (PPriv usa python3)
        screen -dmS pprivado-${porta_socket} python3 /etc/adm-lite/core/PPriv.py "$porta_socket" "$texto_soket" "$local_ip"
        
        echo "${porta_socket}" >> /etc/adm-lite/core/PPriv.log
        
        ui_hr
        echo -e "${GREEN}âœ“ PROXY PRIVADO ACTIVO EN PUERTO: $porta_socket${NC}"
        ui_pause
    }

    desactivar_ppriv() {
        ui_header "DESACTIVAR PROXY PRIVADO"
        killall -9 PPriv.py >/dev/null 2>&1
        for pid in $(ps aux | grep 'PPriv.py' | grep -v grep | awk '{print $2}'); do
            kill -9 "$pid" 2>/dev/null
        done
        screen -wipe >/dev/null 2>&1
        rm -f /etc/adm-lite/core/PPriv.log
        
        echo -e "${GREEN}âœ“ Todos los Proxies Privados detenidos.${NC}"
        ui_pause
    }

    while true; do
        ui_header "PROXY PRIVADO (PYTHON)"
        echo -e "  ${CYAN}[1]>${WHITE} ACTIVAR PROXY PRIVADO${NC}"
        echo -e "  ${CYAN}[2]>${WHITE} DETENER TODOS LOS PROXIES PRIVADOS${NC}"
        ui_hr
        echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
        ui_hr
        ui_prompt "Selecciona: "
        read -r opt
        case $opt in
            1) activar_ppriv ;;
            2) desactivar_ppriv ;;
            0) break ;;
        esac
    done
}

# --- 9) GETTUNEL ---
get_tunnel() {
    activar_get() {
        ui_header "ACTIVAR PROXY GETTUNEL"
        while true; do
            read -p "Digite el Puerto para GETTUNEL: " -e -i "8085" porta_socket
            if ! mportas | grep -q -w "$porta_socket"; then
                break
            else
                echo -e "${RED}âŒ Puerto ya en uso. Elige otro.${NC}"
            fi
        done
        
        read -p "Digite la contraseÃ±a del proxy: " -e -i "SCRIP-LATAM" passg
        echo "$passg" > /etc/adm-lite/core/pwd.pwd
        
        ufw allow ${porta_socket}/tcp >/dev/null 2>&1
        
        # Iniciar backend
        screen -dmS getpy python /etc/adm-lite/core/PGet.py -b "0.0.0.0:$porta_socket" -p "/etc/adm-lite/core/pwd.pwd" 2>/dev/null || screen -dmS getpy python3 /etc/adm-lite/core/PGet.py -b "0.0.0.0:$porta_socket" -p "/etc/adm-lite/core/pwd.pwd" 2>/dev/null
        
        ui_hr
        echo -e "${GREEN}âœ“ GETTUNEL ACTIVO EN PUERTO: $porta_socket${NC}"
        ui_pause
    }

    desactivar_get() {
        ui_header "DESACTIVAR PROXY GETTUNEL"
        killall -9 PGet.py >/dev/null 2>&1
        for pid in $(ps aux | grep 'PGet.py' | grep -v grep | awk '{print $2}'); do
            kill -9 "$pid" 2>/dev/null
        done
        screen -wipe >/dev/null 2>&1
        rm -f /etc/adm-lite/core/pwd.pwd
        
        echo -e "${GREEN}âœ“ GETTUNEL detenido con Ã©xito.${NC}"
        ui_pause
    }

    while true; do
        ui_header "GETTUNEL PROXY"
        echo -e "  ${CYAN}[1]>${WHITE} ACTIVAR GETTUNEL${NC}"
        echo -e "  ${CYAN}[2]>${WHITE} DETENER GETTUNEL${NC}"
        ui_hr
        echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
        ui_hr
        ui_prompt "Selecciona: "
        read -r opt
        case $opt in
            1) activar_get ;;
            2) desactivar_get ;;
            0) break ;;
        esac
    done
}

# --- 10) TCP-OVER ---
tcp_over() {
    activar_tcp() {
        ui_header "ACTIVAR PROXY TCP-OVER"
        while true; do
            read -p "Digite el Puerto para TCP-OVER: " -e -i "8888" porta_socket
            if ! mportas | grep -q -w "$porta_socket"; then
                break
            else
                echo -e "${RED}âŒ Puerto ya en uso. Elige otro.${NC}"
            fi
        done
        
        local default_status="SCRIP-LATAM"
        if [ -f /etc/adm-lite/core/small_banner.txt ]; then
            default_status=$(cat /etc/adm-lite/core/small_banner.txt | tr -d '\r\n')
        fi
        read -p "Digite banner del proxy: " -e -i "$default_status" passg
        echo "$passg" > /etc/adm-lite/core/small_banner.txt
        
        # Comprobar e instalar sckt/scktcheck binaries
        if [[ ! -f /usr/sbin/sckt || ! -f /bin/scktcheck ]]; then
            echo -e "${YELLOW}[+] Descargando binarios de TCP-OVER...${NC}"
            rm -rf /tmp/socks_over 2>/dev/null
            mkdir -p /tmp/socks_over
            wget -qO /tmp/socks_over/backsocz.zip "https://raw.githubusercontent.com/NetVPS/LATAM_Oficial/main/Ejecutables/backsocz.zip"
            cd /tmp/socks_over || exit
            unzip -o backsocz.zip >/dev/null 2>&1
            
            # Copiar configs de ssh
            cp -f backsocz/ssh /etc/ssh/sshd_config >/dev/null 2>&1
            service ssh restart >/dev/null 2>&1
            
            py_ver=$(python3 --version | awk '{print $2}' | cut -d'.' -f1,2)
            if [[ -f "backsocz/sckt${py_ver}" ]]; then
                cp -f "backsocz/sckt${py_ver}" /usr/sbin/sckt
            else
                # Fallback al binario de python mÃ¡s alto si no coincide exactamente
                cp -f backsocz/sckt3.8 /usr/sbin/sckt 2>/dev/null || cp -f backsocz/sckt3.6 /usr/sbin/sckt 2>/dev/null
            fi
            cp -f backsocz/scktcheck /bin/scktcheck
            
            chmod +x /bin/scktcheck
            chmod +x /usr/sbin/sckt
            cd ~ || exit
            rm -rf /tmp/socks_over
        fi
        
        ufw allow ${porta_socket}/tcp >/dev/null 2>&1
        screen -dmS sokz scktcheck "$porta_socket" "$passg"
        
        ui_hr
        echo -e "${GREEN}âœ“ PROXY TCP-OVER ACTIVO EN PUERTO: $porta_socket${NC}"
        ui_pause
    }

    desactivar_tcp() {
        ui_header "DESACTIVAR PROXY TCP-OVER"
        killall -9 scktcheck sckt >/dev/null 2>&1
        for pid in $(ps aux | grep -E 'scktcheck|sckt' | grep -v grep | awk '{print $2}'); do
            kill -9 "$pid" 2>/dev/null
        done
        screen -wipe >/dev/null 2>&1
        
        echo -e "${GREEN}âœ“ TCP-OVER detenido con Ã©xito.${NC}"
        ui_pause
    }

    while true; do
        ui_header "TCP-OVER PROXY"
        echo -e "  ${CYAN}[1]>${WHITE} ACTIVAR TCP-OVER${NC}"
        echo -e "  ${CYAN}[2]>${WHITE} DETENER TCP-OVER${NC}"
        ui_hr
        echo -e "  ${WHITE}[0] VOLVER AL MENÃš ANTERIOR${NC}"
        ui_hr
        ui_prompt "Selecciona: "
        read -r opt
        case $opt in
            1) activar_tcp ;;
            2) desactivar_tcp ;;
            0) break ;;
        esac
    done
}

# --- MAIN ---
mode=$1
case $mode in
    10) get_tunnel ;;
    11) tcp_over ;;
    13) ws_editable ;;
    14) proxy_openvpn ;;
    15) proxy_publico ;;
    16) proxy_privado ;;
    *) echo -e "${RED}Modo no soportado${NC}" ;;
esac
