#!/bin/bash
#---------------------------------------------------------
# SOCK PYTHON AUTO CONFIG 80 + 443
# Autor: @ChumoGH
#---------------------------------------------------------

[[ -e /bin/ejecutar/msg ]] && source /bin/ejecutar/msg || source <(curl -sSL https://raw.githubusercontent.com/ChumoGH/ADMcgh/main/Plugins/system/styles.cpp)

ADM_inst="/etc/adm-lite" && [[ ! -d ${ADM_inst} ]] && exit
HOME_DIR=$HOME
PY2_FILE="$HOME_DIR/PDirect80.py"
PY3_FILE="$HOME_DIR/P3Direct80.py"

# Detectar sistema y versión
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
    os_version=$(echo "$VERSION_ID" | cut -d'.' -f1)
else
    echo "Sistema no soportado." && exit 1
fi

# Detectar arquitectura
arch=$(uname -m)
[[ $arch == "x86_64" ]] && arch="amd64"
[[ $arch == "aarch64" ]] && arch="arm64"

msg -bar3
print_center "SISTEMA DETECTADO: ${release^^} ${os_version} ARCH: $arch"
msg -bar3

# Funciones de instalación de Python
install_py2() {
    apt-get -qq install python2 python-is-python2 -y &>/dev/null
    touch /etc/fixpython
}

install_py3() {
    apt-get -qq install python3 python3-pip -y &>/dev/null
}

# Descargar scripts según versión
download_py() {
    local pyver=$1
    local file=$2
    local url=$3
    [[ ! -f "$file" ]] && wget -q -O "$file" "$url"
}

function fix_ssl() {
	helice() {
		inst_ssl >/dev/null 2>&1 &
		tput civis
		while [ -d /proc/$! ]; do
			for i in / - \\ \|; do
				sleep .1
				echo -ne "\e[1D$i"
			done
		done
		tput cnorm
	}
	echo -ne "\033[1;37m INSTALANDO  \033[1;32mSTUNNEL (\033[1;37mS\033[1;32mS\033[1;32mL\033[1;33m)\033[1;31m. \033[1;33m"
	helice
	echo -e "\e[1DOk"
}

# Instalar SSL (Stunnel)
inst_ssl() {
IFS=$'\n' read -r -d '' country region state <<< $(curl -sSL ipinfo.io | grep -E "country|region|city" | awk '{print $2}' | sed -e 's/[^a-zA-Z0-9 -]//g')
    pkill -f stunnel4
	killall stunnel4 &>/dev/null 
	killall stunnel &>/dev/null
    apt purge stunnel4 -y &>/dev/null
    apt install stunnel4 -y &>/dev/null

    mkdir -p /etc/stunnel
	openssl genrsa -out /etc/stunnel/key.pem 2048 
	(echo "${state}" ; echo "${region}" ; echo "${country}" ; echo "$(cat < /bin/ejecutar/IPcgh):81" ; echo "ADMcgh Corp" ; echo "EC Department" ; echo "ChumoGH .Ing")|openssl req -new -x509 -key /etc/stunnel/key.pem -out /etc/stunnel/cert.pem -days 1095 > /dev/null 2>&1
    cat /etc/stunnel/key.pem /etc/stunnel/cert.pem > /etc/stunnel/stunnel.pem
    echo -e "cert = /etc/stunnel/stunnel.pem\nclient = no\nsocket = a:SO_REUSEADDR=1\nsocket = l:TCP_NODELAY=1\nsocket = r:TCP_NODELAY=1\n\n[stunnel]\naccept = 443\nconnect = 127.0.0.1:80" > /etc/stunnel/stunnel.conf
    sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
    systemctl restart stunnel4
}

# Reactivador automático
reactivador_sock(){
    local porta=$1
    local pybin=$2
    local file=$3
	msg -bar3
    [[ $(ps x | grep "ws$porta $pybin" | grep -v grep) ]] && {
        print_center "REACTIVADOR DE SOCK Python ${porta} ENCENDIDO"
		msg -bar3
        if [[ $(grep -wc "ws$porta" /bin/autoboot) = '0' ]]; then
            echo -e "netstat -tlpn | grep -w $porta > /dev/null || { screen -r -S 'ws$porta' -X quit; screen -dmS ws$porta $pybin $file $porta & >> /root/proxy.log ; }" >> /bin/autoboot
        else
            sed -i "/ws$porta/d" /bin/autoboot
            echo -e "netstat -tlpn | grep -w $porta > /dev/null || { screen -r -S 'ws$porta' -X quit; screen -dmS ws$porta $pybin $file $porta & >> /root/proxy.log ; }" >> /bin/autoboot
        fi
    }
}

# Menú principal
menu_intro() {
    clear
    tittle "SOCK PYTHON AUTOCONFIG 80 + 443"
    echo -e "\033[1;32m  Visita https://t.me/ChumoGH_ADM para detalles"
    msg -bar3
	echo -e "\033[1;32m    SSL + ( Payload / Directo )  | by: @ChumoGH "
	msg -bar3 #echo -e "\033[1;31m———————————————————————————————————————————————————\033[1;37m"
	echo -e "\033[1;36m        SCRIPT REESTRUCTURA y AUTOCONFIGURACION "
	msg -bar3 #echo -e "\033[1;31m———————————————————————————————————————————————————\033[1;37m"
	echo -e "\033[1;37m      Requiere tener el puerto libre 443 y el 80"
	msg -bar3
    echo -e "\033[0;35m [\033[0;36m1\033[0;35m]\033[0;33m${flech} ${cor[3]}Activar AUTOCONFIG (Python + SSL)"
    echo -e "\033[0;35m [\033[0;36m2\033[0;35m]\033[0;33m${flech} ${cor[3]}Desactivar (Payload+SSL) | \033[0;35m [\033[0;36m0\033[0;35m]\033[0;31m ${flech} $(msg -bra "\033[1;41m[ REGRESAR ]\e[0m")"
    msg -bar3
    read -p "Seleccione una opción [0-2]: " opcion
    case $opcion in
        1)
            clear
            tittle "INSTALANDO STUNNEL (SSL) + PYTHON SOCKS 80"
            fix_ssl
            # Descargar scripts
            download_py 2 "$PY2_FILE" "https://www.dropbox.com/s/4z2aj25m2avmttk/PDirect.py"
            download_py 3 "$PY3_FILE" "https://www.dropbox.com/scl/fi/2it20m8s0jopcxgvc96dq/P3Direct.py?rlkey=4blmmbifv0y40q63owe6x76uy"

            # Preguntar versión de Python
			msg -bar3
            echo "Seleccione versión de Python para ejecutar:"
			msg -bar3
            echo -e "\033[0;35m [\033[0;36m1\033[0;35m]\033[0;33m${flech} ${cor[3]}Python2"
            echo -e "\033[0;35m [\033[0;36m2\033[0;35m]\033[0;33m${flech} ${cor[3]}Python3 (Deb11+ / Ubu22+)"
            msg -bar3
			read -p "Opción [1-2]: " py_opt
            [[ $py_opt == "1" ]] && pybin="python" && pyfile="$PY2_FILE" || pybin="python3" && pyfile="$PY3_FILE"

            # Levantar screen
            screen -dmS "ws80" $pybin $pyfile 80 &> /root/proxy.log
            screen -dmS "ws443" stunnel4 &> /root/proxy.log

            # Reactivador automático
            [[ ! -f /bin/autoboot ]] && touch /bin/autoboot
            reactivador_sock 80 $pybin $pyfile

            # Configurar cron
            crontab -l > /root/cron 2>/dev/null
            [[ -z $(grep 'autoboot' /root/cron) ]] && echo "@reboot /bin/autoboot" >> /root/cron
            crontab /root/cron
            systemctl restart cron
            print_center "INSTALACIÓN COMPLETADA"
			return
            ;;
        2)
            print_center "DETENIENDO SERVICIOS Y REMOVIENDO AUTOCONFIG"
            pkill -f PDirect80.py
            pkill -f P3Direct80.py
            pkill -f stunnel4
            sed -i '/PDirect80.py/d;/P3Direct80.py/d;/ws80/d;/ws443/d' /bin/autoboot
            screen -wipe &>/dev/null
            print_center "AUTOCONFIG DESACTIVADO"
            ;;
        0) return ;;
        *) echo "Opción inválida"; sleep 2; menu_intro ;;
    esac
}

menu_intro
