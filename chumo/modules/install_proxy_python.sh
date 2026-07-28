#!/bin/bash
# ==============================================================================
#  GESTOR DE PROXIES PYTHON 3 (OPCIÓN 7) - UBUNTU 20 / 22 / 24 / 26 COMPATIBLE
# ==============================================================================

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

CORE_DIR="/etc/adm-lite"
mkdir -p "$CORE_DIR"

ui_hr() { echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"; }

# Obtener puertos escuchando
mportas() {
    lsof -V -i tcp -P -n 2>/dev/null | grep "LISTEN" | awk '{print $9}' | awk -F ":" '{print $2}' | sort -u
}

# 1. Proxy Python Directo
activar_pdirect() {
    clear
    ui_hr
    echo -e "${YELLOW}       🐍 PROXY PYTHON DIRECTO (PDirect.py)${NC}"
    ui_hr

    read -p " Puerto de escucha para el Proxy Python [8080]: " LISTEN_PORT
    [ -z "$LISTEN_PORT" ] && LISTEN_PORT=8080

    if mportas | grep -q -w "$LISTEN_PORT"; then
        echo -e "${RED}[!] El puerto $LISTEN_PORT ya está en uso por otro servicio.${NC}"
        read -p "Presione Enter para continuar..."
        return
    fi

    read -p " Puerto SSH/Destino a redirigir [22]: " TARGET_PORT
    [ -z "$TARGET_PORT" ] && TARGET_PORT=22

    read -p " Código de Respuesta HTTP (200, 101, 404) [200]: " RESP_CODE
    [ -z "$RESP_CODE" ] && RESP_CODE=200

    read -p " Texto de Respuesta HTTP [Connection established]: " RESP_TXT
    [ -z "$RESP_TXT" ] && RESP_TXT="Connection established"

    echo -e "\n${YELLOW}[+] Iniciando Proxy Python 3 en puerto $LISTEN_PORT -> $TARGET_PORT...${NC}"

    # Detener previo si existía en ese puerto
    pkill -f "PDirect.py -p $LISTEN_PORT" 2>/dev/null

    nohup python3 "$CORE_DIR/PDirect.py" -p "$LISTEN_PORT" -l "$TARGET_PORT" -r "$RESP_CODE" -t "$RESP_TXT" >/dev/null 2>&1 &

    echo -e "${GREEN} ✅ Proxy Python Directo iniciado exitosamente en el puerto $LISTEN_PORT.${NC}"
    read -p "Presione Enter para continuar..."
}

# 2. Proxy Python GET / Payloads
activar_pget() {
    clear
    ui_hr
    echo -e "${YELLOW}       🐍 PROXY PYTHON GET (PGet.py)${NC}"
    ui_hr

    read -p " Puerto de escucha para Proxy GET [8799]: " LISTEN_PORT
    [ -z "$LISTEN_PORT" ] && LISTEN_PORT=8799

    if mportas | grep -q -w "$LISTEN_PORT"; then
        echo -e "${RED}[!] El puerto $LISTEN_PORT ya está en uso.${NC}"
        read -p "Presione Enter para continuar..."
        return
    fi

    read -p " Puerto SSH/Destino a redirigir [22]: " TARGET_PORT
    [ -z "$TARGET_PORT" ] && TARGET_PORT=22

    echo -e "\n${YELLOW}[+] Iniciando Proxy Python GET en puerto $LISTEN_PORT...${NC}"
    pkill -f "PGet.py -p $LISTEN_PORT" 2>/dev/null

    nohup python3 "$CORE_DIR/PGet.py" -p "$LISTEN_PORT" -l "$TARGET_PORT" >/dev/null 2>&1 &

    echo -e "${GREEN} ✅ Proxy Python GET iniciado en el puerto $LISTEN_PORT.${NC}"
    read -p "Presione Enter para continuar..."
}

# 3. Proxy Python WebSocket Custom Header
activar_pwebsocket() {
    clear
    ui_hr
    echo -e "${YELLOW}       🐍 PROXY PYTHON WEBSOCKET (CUSTOM HEADER)${NC}"
    ui_hr

    read -p " Puerto de escucha [80]: " LISTEN_PORT
    [ -z "$LISTEN_PORT" ] && LISTEN_PORT=80

    read -p " Puerto SSH/Destino [22]: " TARGET_PORT
    [ -z "$TARGET_PORT" ] && TARGET_PORT=22

    read -p " Encabezado de Estado (ej: 101 Switching Protocols): " -e -i "101 Switching Protocols" STATUS_HEADER

    SCRIPT_PATH="$CORE_DIR/PWS-${LISTEN_PORT}.py"

    cat << EOF > "$SCRIPT_PATH"
# -*- coding: utf-8 -*-
import socket, threading, select, sys, time

LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = $LISTEN_PORT
BUFLEN = 16384
TIMEOUT = 60
DEFAULT_HOST = '127.0.0.1:$TARGET_PORT'
RESPONSE_WS = b'HTTP/1.1 $STATUS_HEADER\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n'

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
            self.soc.bind((self.host, self.port))
            self.soc.listen(128)
            self.running = True
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    threading.Thread(target=self.handle_client, args=(c,)).start()
                except:
                    continue
        finally:
            self.running = False
            self.soc.close()

    def handle_client(self, client):
        try:
            req = client.recv(BUFLEN)
            client.sendall(RESPONSE_WS)
            target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target.connect(('127.0.0.1', $TARGET_PORT))
            
            sockets = [client, target]
            while True:
                r, _, e = select.select(sockets, [], sockets, TIMEOUT)
                if e or not r: break
                for s in r:
                    data = s.recv(BUFLEN)
                    if not data: break
                    out = target if s is client else client
                    out.sendall(data)
        except:
            pass
        finally:
            client.close()

if __name__ == '__main__':
    Server(LISTENING_ADDR, LISTENING_PORT).start()
EOF

    pkill -f "PWS-${LISTEN_PORT}.py" 2>/dev/null
    nohup python3 "$SCRIPT_PATH" >/dev/null 2>&1 &

    echo -e "${GREEN} ✅ Proxy WebSocket iniciado en el puerto $LISTEN_PORT -> SSH $TARGET_PORT.${NC}"
    read -p "Presione Enter para continuar..."
}

# 4. Ver Proxies Activos
ver_proxies() {
    clear
    ui_hr
    echo -e "${YELLOW}       📊 PROXIES PYTHON ACTIVOS EN EL SISTEMA${NC}"
    ui_hr
    PROXIES=$(ps aux | grep "python3" | grep -v "grep")
    if [ -z "$PROXIES" ]; then
        echo -e "${RED} No hay ningún Proxy Python ejecutándose en este momento.${NC}"
    else
        echo -e "${WHITE}$PROXIES${NC}"
    fi
    ui_hr
    read -p "Presione Enter para continuar..."
}

# 5. Detener Proxies
detener_proxies() {
    clear
    ui_hr
    echo -e "${YELLOW}       🛑 DETENER PROXIES PYTHON${NC}"
    ui_hr
    read -p " ¿Deseas detener TODOS los Proxies Python activos? [s/n]: " op
    if [[ "$op" == "s" || "$op" == "S" ]]; then
        pkill -f "PDirect.py" 2>/dev/null
        pkill -f "PGet.py" 2>/dev/null
        pkill -f "PWS-" 2>/dev/null
        echo -e "${GREEN} [+] Todos los Proxies Python han sido detenidos.${NC}"
    fi
    read -p "Presione Enter para continuar..."
}

# Menú Interactivo
menu_proxies() {
    while true; do
        clear
        ui_hr
        echo -e "${YELLOW}           🐍 GESTOR DE PROXIES PYTHON 3${NC}"
        ui_hr
        echo -e "${WHITE} [1]${CYAN} ➮ Activar Proxy Python Directo (PDirect)${NC}"
        echo -e "${WHITE} [2]${CYAN} ➮ Activar Proxy Python GET (PGet)${NC}"
        echo -e "${WHITE} [3]${CYAN} ➮ Activar Proxy WebSocket (Custom Header)${NC}"
        echo -e "${WHITE} [4]${CYAN} ➮ Ver Proxies Python Activos${NC}"
        echo -e "${WHITE} [5]${CYAN} ➮ Detener Proxies Python${NC}"
        echo -e "${WHITE} [0]${RED} ➮ [ REGRESAR ]${NC}"
        ui_hr
        read -p " Seleccione una opción [0-5]: " opcion

        case $opcion in
            1) activar_pdirect ;;
            2) activar_pget ;;
            3) activar_pwebsocket ;;
            4) ver_proxies ;;
            5) detener_proxies ;;
            0) break ;;
        esac
    done
}

menu_proxies
