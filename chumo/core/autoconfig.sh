#!/bin/bash
# AUTOCONFIG PYTHON + SSL (CORREGIDO PARA PYTHON 3 Y UBUNTU 22/24/26)

HOME_DIR="/etc/adm-lite"
PY3_FILE="$HOME_DIR/PDirect.py"

source /bin/ejecutar/msg 2>/dev/null || source /etc/adm-lite/msg 2>/dev/null

fix_ssl() {
    echo -e "\033[1;37m INSTALANDO STUNNEL (SSL) EN PUERTO 443 -> 80...\033[0m"
    pkill -f stunnel4 2>/dev/null
    pkill -f stunnel 2>/dev/null
    apt-get install stunnel4 -y &>/dev/null

    mkdir -p /etc/stunnel
    openssl req -new -x509 -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem -days 3650 -nodes -subj "/C=MX/ST=CDMX/L=CDMX/O=Chumo/OU=VPS/CN=chumo" >/dev/null 2>&1

    cat << EOF > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel4.pid
cert = /etc/stunnel/stunnel.pem
client = no

[ssl_python]
accept = 443
connect = 127.0.0.1:80
EOF

    sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4 2>/dev/null
    systemctl restart stunnel4 2>/dev/null || systemctl restart stunnel 2>/dev/null
}

menu_intro() {
    clear
    echo -e "\033[1;33m===================================================\033[0m"
    echo -e "\033[1;32m      SOCK PYTHON + SSL (AUTOCONFIG 80 + 443)     \033[0m"
    echo -e "\033[1;33m===================================================\033[0m"
    echo -e "\033[1;37m [1] Activar AUTOCONFIG (Python 3 + SSL Stunnel4)\033[0m"
    echo -e "\033[1;37m [2] Desactivar (Python + SSL)\033[0m"
    echo -e "\033[1;37m [0] REGRESAR\033[0m"
    echo -e "\033[1;33m===================================================\033[0m"
    read -p "Seleccione una opción [0-2]: " opcion

    case $opcion in
        1)
            clear
            echo -e "\033[1;34m[+] Configurando Proxy Python 3 en Puerto 80...\033[0m"
            pkill -f PDirect.py 2>/dev/null
            
            # Asegurar PDirect.py
            if [ ! -f "$PY3_FILE" ]; then
                cp /tmp/chumo/chumo/core/PDirect.py "$PY3_FILE" 2>/dev/null
            fi

            # Iniciar proxy python 3 en puerto 80 -> SSH 22
            nohup python3 "$PY3_FILE" -p 80 -l 22 >/dev/null 2>&1 &

            # Configurar SSL
            fix_ssl

            echo -e "\n\033[1;32m===================================================\033[0m"
            echo -e "\033[1;32m ✅ SERVICIOS ACTIVADOS CORRECTAMENTE:\033[0m"
            echo -e " 🔹 Proxy Python 3 WebSocket: Puerto \033[1;33m80\033[0m"
            echo -e " 🔹 SSL/TLS (Stunnel4): Puerto \033[1;33m443\033[0m"
            echo -e " 🔹 Destino SSH: Puerto \033[1;33m22\033[0m"
            echo -e "\033[1;33m===================================================\033[0m"
            read -p "Presione Enter para continuar..."
            ;;
        2)
            echo -e "\033[1;31m[+] Deteniendo Proxy Python y SSL...\033[0m"
            pkill -f PDirect.py 2>/dev/null
            pkill -f stunnel4 2>/dev/null
            systemctl stop stunnel4 2>/dev/null
            echo -e "\033[1;32m[+] Servicios detenidos.\033[0m"
            read -p "Presione Enter para continuar..."
            ;;
        0)
            return
            ;;
    esac
}

menu_intro
